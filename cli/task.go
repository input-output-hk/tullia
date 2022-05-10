package main

import (
	"bytes"
	"fmt"
	"os"
	"os/exec"
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
	evalStart     time.Time
	evalEnd       time.Time
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
				if t.fail(t.eval()) {
					return
				}
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
	case "eval":
		t.evalStart = time.Now()
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
	t.cmd.Stdout = log.Str("std", "out").Logger()
	t.cmd.Stderr = log.Str("std", "err").Logger()
}

func (t *Task) preExecCLI() {
	t.cliLines = &bytes.Buffer{}
	t.cmd.Stdout = t.cliLines
	t.cmd.Stderr = t.cliLines
}

func (t *Task) preExecPassthrough() {
	t.cmd.Stdout = os.Stdout
	t.cmd.Stderr = os.Stderr
	t.cmd.Stdin = os.Stdin
	t.cmd.Env = os.Environ()
}

func (t *Task) preExecJSON() {
	t.log.Debug().Stringer("cmd", t.cmd).Msg("start")
	log := t.log.With().Str("level", zerolog.LevelDebugValue)
	t.cmd.Stdout = log.Str("std", "out").Logger()
	t.cmd.Stderr = log.Str("std", "err").Logger()
}

func (t *Task) exec(stage string, f func()) error {
	err := t.cmd.Run()

	switch t.stage {
	case "eval":
		t.evalEnd = time.Now()
	case "build":
		t.buildEnd = time.Now()
	case "run":
		t.runEnd = time.Now()
	}

	switch t.config.Run.Mode {
	case "json":
		return t.execJSON(stage, f, err)
	case "cli":
		return t.execCommon(stage, f, err)
	case "verbose":
		return t.execCommon(stage, f, err)
	case "passthrough":
		return t.execCommon(stage, f, err)
	default:
		return fmt.Errorf("unknown mode %q", t.config.Run.Mode)
	}
}

func (t *Task) execJSON(stage string, f func(), err error) error {
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

func (t *Task) execCommon(stage string, f func(), err error) error {
	if err != nil {
		return errors.WithMessagef(err, "Failed to run %s", t.cmd)
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

func (t *Task) eval() error {
	t.cmd = exec.Command("nix", "eval", "--raw",
		t.config.Run.TaskFlake+"."+t.name+"."+t.config.Run.Runtime+".run.outPath")
	t.preExec("eval")
	buf := &bytes.Buffer{}
	t.cmd.Stdout = buf
	return t.exec("wait", func() {
		t.storePath = buf.String() + "/bin/" + t.name + "-" + t.config.Run.Runtime
	})
}

func (t *Task) build() error {
	t.cmd = exec.Command("nix", "build", "--no-link",
		t.config.Run.TaskFlake+"."+t.name+"."+t.config.Run.Runtime+".run")
	t.preExec("build")
	return t.exec("wait", func() {})
}

func (t *Task) run() error {
	t.cmd = exec.Command(t.storePath)
	t.preExec("run")
	t.cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}
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
