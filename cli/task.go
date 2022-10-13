package main

import (
	"bytes"
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"os/signal"
	"sync"
	"syscall"
	"time"

	"github.com/goombaio/dag"
	"github.com/pkg/errors"
	"github.com/rs/zerolog"
)

type Task struct {
	config        Config
	name          string
	stage         string
	successors    []*dag.Vertex
	predecessors  []*dag.Vertex
	dependencies  *sync.WaitGroup
	once          *sync.Once
	storePath     string
	cmd           *exec.Cmd
	err           error
	dependencyErr error
	log           zerolog.Logger
	cliLines      *bytes.Buffer
	buildStart    time.Time
	buildEnd      time.Time
	runStart      time.Time
	runEnd        time.Time
}

func newTask(log zerolog.Logger, config Config, taskName string) *Task {
	return &Task{
		log:          log.With().Str("name", taskName).Logger(),
		name:         taskName,
		successors:   []*dag.Vertex{},
		predecessors: []*dag.Vertex{},
		dependencies: &sync.WaitGroup{},
		once:         &sync.Once{},
		config:       config,
	}
}

func (t *Task) prepare(prepareWG, startWG *sync.WaitGroup) error {
	t.once.Do(func() {
		startWG.Add(1)
		go func() {
			defer startWG.Done()
			prepareWG.Wait()
			t.stage = "wait"

			if t.config.Run.runSpec == nil {
				if t.fail(t.build()) {
					return
				}
			} else {
				t.storePath = t.config.Run.runSpec.Bin[t.name]
			}

			t.dependencies.Wait()
			if t.dependencyFailed() {
				return
			}
			if t.fail(t.err) {
				return
			}
			if t.fail(t.run()) {
				return
			}
			t.notifySuccessors(nil)
		}()

		for _, predecessor := range t.predecessors {
			if t.fail(predecessor.Value.(*Task).prepare(prepareWG, startWG)) {
				return
			}
		}
	})

	return nil
}

func (t *Task) preExec(stage string) {
	t.stage = stage

	switch stage {
	case "build":
		t.buildStart = time.Now()
	case "run":
		t.runStart = time.Now()
	}

	switch t.config.Run.Mode {
	case "json":
		t.preExecJSON()
	case "cli":
		t.preExecCLI()
	case "verbose":
		t.preExecVerbose()
	case "passthrough":
		t.preExecPassthrough()
	default:
		t.config.log.Fatal().Str("mode", t.config.Run.Mode).Msg("unknown mode")
	}
}

func (t *Task) preExecVerbose() {
	t.log.Debug().Stringer("cmd", t.cmd).Msg("start")
	log := t.log.
		Output(zerolog.ConsoleWriter{Out: os.Stderr}).
		With().
		Str("level", zerolog.LevelInfoValue).
		Timestamp()
	if t.cmd.Stdout == nil {
		t.cmd.Stdout = log.Str("std", "out").Logger()
	}
	if t.cmd.Stderr == nil {
		t.cmd.Stderr = log.Str("std", "err").Logger()
	}
}

func (t *Task) preExecCLI() {
	t.cliLines = &bytes.Buffer{}
	if t.cmd.Stdout == nil {
		t.cmd.Stdout = t.cliLines
	}
	if t.cmd.Stderr == nil {
		t.cmd.Stderr = t.cliLines
	}
}

func (t *Task) preExecPassthrough() {
	if t.cmd.Stdout == nil {
		t.cmd.Stdout = os.Stdout
	}
	if t.cmd.Stderr == nil {
		t.cmd.Stderr = os.Stderr
	}
	t.cmd.Stdin = os.Stdin
	t.cmd.Env = os.Environ()
}

func (t *Task) preExecJSON() {
	t.log.Debug().Stringer("cmd", t.cmd).Msg("start")
	log := t.log.With().Str("level", zerolog.LevelDebugValue)
	if t.cmd.Stdout == nil {
		t.cmd.Stdout = log.Str("std", "out").Logger()
	}
	if t.cmd.Stderr == nil {
		t.cmd.Stderr = log.Str("std", "err").Logger()
	}
}

func (t *Task) exec(stage string, f func()) error {
	t.cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
	err := t.cmd.Start()
	if err == nil {
		var pgid int
		pgid, err = syscall.Getpgid(t.cmd.Process.Pid)

		if err == nil {
			c := make(chan os.Signal)
			go func() {
				<-c
				_ = syscall.Kill(-pgid, 15)
			}()
			signal.Notify(c, os.Kill, os.Interrupt)

			// TODO: Measure resources here in cli mode
			err = t.cmd.Wait()
		}
	}

	switch t.stage {
	case "build":
		t.buildEnd = time.Now()
	case "run":
		t.runEnd = time.Now()
	}

	switch t.config.Run.Mode {
	case "json":
		return t.postExecJSON(stage, f, err)
	case "cli", "verbose", "passthrough":
		return t.postExecCommon(stage, f, err)
	default:
		return fmt.Errorf("unknown mode %q", t.config.Run.Mode)
	}
}

func (t *Task) postExecJSON(stage string, f func(), err error) error {
	if err != nil {
		t.log.Debug().Caller().Int("exit_status", t.cmd.ProcessState.ExitCode()).Msg("exited")
		return errors.WithMessagef(err, "Failed to run %s", t.cmd)
	} else {
		t.log.Debug().Caller().Int("exit_status", t.cmd.ProcessState.ExitCode()).Msg("exited")
		t.stage = stage
		f()
		return nil
	}
}

func (t *Task) postExecCommon(stage string, f func(), err error) error {
	if err != nil {
		switch t.cmd.ProcessState.ExitCode() {
		case 137:
			return errors.WithMessagef(err, "Failed to run %s\nThis usually means it ran out of memory", t.cmd)
		default:
			return errors.WithMessagef(err, "Failed to run %s", t.cmd)
		}
	} else {
		t.stage = stage
		f()
		return nil
	}
}

func (t *Task) dependencyFailed() bool {
	if t.dependencyErr == nil {
		return false
	}
	t.stage = "cancel"
	t.notifySuccessors(errors.WithMessagef(t.dependencyErr, "%q failed", t.name))
	return true
}

func (t *Task) fail(err error) bool {
	if err == nil {
		return false
	}
	t.stage = "error"
	t.err = err
	t.notifySuccessors(errors.WithMessagef(err, "%q failed", t.name))
	return true
}

func (t *Task) build() error {
	t.cmd = exec.Command("nix", "build", "--json", "--no-link")

	stderr := &bytes.Buffer{}
	t.cmd.Stdout = stderr

	t.preExec("build")

	// XXX Unfortunately, until https://github.com/NixOS/nix/pull/6333 is merged,
	// we cannot build this with only one nix command due to escaping issues.
	// The `nix build` command takes an "installable" argument,
	// which we would like to contain the attribute path to our task's runtime.
	// However the installable is not interpreted as actual nix code
	// but rather as URL component (after parsing percent-encoding).
	// So if the task name contains `.` or `"` (and possibly other) characters
	// we are not able to quote them and nix complains about a missing attribute.

	var nameNixStr string
	{
		cmd := exec.Command("nix", "eval", "--impure", "--expr", `__getEnv "s"`)
		cmd.Env = append(os.Environ(), "s="+t.name)
		if out, err := cmd.Output(); err != nil {
			return err
		} else {
			nameNixStr = string(out)
		}
	}

	if drv, err := exec.Command(
		"nix", "eval", "--raw", t.config.Run.TaskFlake,
		"--apply", "f: f."+nameNixStr+"."+t.config.Run.Runtime+".run.drvPath",
	).Output(); err != nil {
		return err
	} else {
		t.cmd.Args = append(t.cmd.Args, string(drv))
	}

	return t.exec("wait", func() {
		res := []nixBuildResult{}
		if err := json.Unmarshal(stderr.Bytes(), &res); err != nil {
			t.log.Err(err).Str("stderr", stderr.String()).Msg("waiting for result")
		}

		t.storePath = fmt.Sprintf(
			"%s/bin/%s-%s",
			res[0].Outputs.Out,
			t.name,
			t.config.Run.Runtime,
		)
	})
}

type nixBuildResult struct {
	DrvPath string               `json:"drvPath"`
	Outputs nixBuildResultOutput `json:"outputs"`
}

type nixBuildResultOutput struct {
	Out string `json:"out"`
}

func (t *Task) run() error {
	t.cmd = exec.Command(t.storePath)
	t.preExec("run")
	return t.exec("done", func() {})
}

func (t *Task) notifySuccessors(err error) {
	for _, successor := range t.successors {
		s := successor.Value.(*Task)
		if err != nil {
			s.dependencyErr = err
		}
		s.dependencies.Done()
	}
}
