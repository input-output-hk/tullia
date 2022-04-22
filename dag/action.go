package dag

import (
	"bufio"
	"fmt"
	"io"
	"os"
	"os/exec"
	"regexp"
	"sort"
	"strings"
	"sync"
	"syscall"
	"time"

	"github.com/c2h5oh/datasize"
	"github.com/charmbracelet/lipgloss"
	"github.com/pkg/errors"
)

type LineType string

const (
	LineTypeStderr = "stderr"
	LineTypeStdout = "stdout"
)

type Line struct {
	Type LineType
	Text string
	Time time.Time
}

// TODO: make this threadsafe
type Task struct {
	name         string
	storePath    string
	dependencies *sync.WaitGroup
	started      time.Time
	finished     *time.Time
	once         *sync.Once
	stdoutRd     *io.PipeReader
	stdoutWr     *io.PipeWriter
	stderrRd     *io.PipeReader
	stderrWr     *io.PipeWriter
	log          []Line
	cmd          *exec.Cmd
	err          error
	stage        string
	mut          *sync.Mutex
}

func NewTask(name string) *Task {
	stdoutRd, stdoutWr := io.Pipe()
	stderrRd, stderrWr := io.Pipe()
	a := &Task{
		name:         name,
		dependencies: &sync.WaitGroup{},
		once:         &sync.Once{},
		stdoutRd:     stdoutRd,
		stdoutWr:     stdoutWr,
		stderrRd:     stderrRd,
		stderrWr:     stderrWr,
		log:          []Line{},
		stage:        "wait",
		mut:          &sync.Mutex{},
	}

	go a.startPipe(LineTypeStdout, stdoutRd)
	go a.startPipe(LineTypeStderr, stderrRd)

	return a
}

var (
	stageWaitStyle  = lipgloss.NewStyle().Foreground(lipgloss.Color("#f0f"))
	stageEvalStyle  = lipgloss.NewStyle().Foreground(lipgloss.Color("#af0"))
	stageBuildStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("#ff0"))
	stageDoneStyle  = lipgloss.NewStyle().Foreground(lipgloss.Color("#0f0"))
	stageRunStyle   = lipgloss.NewStyle().Foreground(lipgloss.Color("#0ff"))
	stageErrorStyle = lipgloss.NewStyle().Foreground(lipgloss.Color("#f00"))
)

func (a *Task) Name() string {
	return a.name
}

func (a *Task) Stage() string {
	return a.stage
}

func (a *Task) Error() error {
	return a.err
}

func (a *Task) Elapsed() time.Duration {
	if a.started.IsZero() {
		return 0
	}
	if a.finished != nil {
		return a.finished.Sub(a.started)
	} else {
		return time.Since(a.started)
	}
}

func (a *Task) RSS() string {
	if a.ProcessState() != nil {
		if usage, ok := a.ProcessState().SysUsage().(*syscall.Rusage); ok {
			return (datasize.ByteSize(usage.Maxrss) * datasize.KB).HumanReadable()
		}
	}
	return ""
}

func (a *Task) String() string {
	var stage string
	switch a.stage {
	case "wait":
		stage = stageWaitStyle.Render(a.stage)
	case "eval":
		stage = stageEvalStyle.Render(a.stage)
	case "build":
		stage = stageBuildStyle.Render(a.stage)
	case "done":
		stage = stageDoneStyle.Render(a.stage)
	case "run":
		stage = stageRunStyle.Render(a.stage)
	case "error":
		stage = stageErrorStyle.Render(a.stage)
	default:
		stage = a.stage
	}

	if a.err != nil {
		stage = stageErrorStyle.Render(a.stage)
		return fmt.Sprintf("%s %s %s", a.name, stage, a.err)
	}

	if a.cmd == nil {
		return fmt.Sprintf("%s %s", a.name, stage)
	} else if a.cmd.ProcessState != nil {
		usage, ok := a.cmd.ProcessState.SysUsage().(*syscall.Rusage)
		if ok {
			rss := (datasize.ByteSize(usage.Maxrss) * datasize.KB).HumanReadable()
			return fmt.Sprintf("%s %s (Max RSS: %s)", a.name, stage, rss)
		} else {
			return fmt.Sprintf("%s %s", a.name, stage)
		}
	} else if a.cmd.Process != nil {
		return fmt.Sprintf("%s %s (PID: %d)", a.name, stage, a.cmd.Process.Pid)
	}
	return a.name
}

func (a *Task) Log(fromLine, lines int) []Line {
	l := len(a.log)
	fromLine = clamp(fromLine, 0, l)
	lines = clamp(lines, 0, l-fromLine)
	return a.log[fromLine : fromLine+lines]
}

func (a *Task) Tail(lines int) []Line {
	l := len(a.log)
	lines = clamp(lines, 0, l)
	return a.log[l-lines:]
}

func (a *Task) Head(lines int) []Line {
	l := len(a.log)
	lines = clamp(lines, 0, l)
	return a.log[0:lines]
}

func (a *Task) Len() int {
	return len(a.log)
}

func (a *Task) Pid() int {
	if a.cmd == nil || a.cmd.Process == nil {
		return 0
	}
	return a.cmd.Process.Pid
}

func (a *Task) ProcessState() *os.ProcessState {
	if a.cmd == nil {
		return nil
	}
	return a.cmd.ProcessState
}

const ansi = "[\u001b\u009b][[\\]()#;?]*(?:(?:(?:[a-zA-Z\\d]*(?:;[a-zA-Z\\d]*)*)?\u0007)|(?:(?:\\d{1,4}(?:;\\d{0,4})*)?[\\dA-PRZcf-ntqry=><~]))"

var ansiRE = regexp.MustCompile(ansi)

func stripANSI(str string) string {
	return ansiRE.ReplaceAllString(str, "")
}

func (a *Task) startPipe(kind LineType, rd io.Reader) {
	brd := bufio.NewReader(rd)
	for {
		lineText, err := brd.ReadString('\n')
		if err != nil {
			if err == io.EOF {
				return
			}
			// can't return error since we're in another goroutine
			_ = a.returnErr(err)
			return
		}

		a.mut.Lock()
		// TODO: allow ANSI once https://github.com/charmbracelet/bubbletea/pull/249 is ready
		lines := strings.Split(lineText, "\r")
		for _, l := range lines {
			line := Line{Time: time.Now(), Type: kind}
			line.Text = strings.TrimRight(stripANSI(l), " \n")
			i := sort.Search(len(a.log), func(i int) bool { return a.log[i].Time.After(line.Time) })
			if i < len(a.log) && a.log[i] == line {
			} else {
				a.log = append(a.log, line)
				copy(a.log[i+1:], a.log[i:])
				a.log[i] = line
			}
		}
		a.mut.Unlock()
	}
}

func (a *Task) run() error {
	a.started = time.Now()
	err := a.exec()
	t := time.Now()
	a.finished = &t

	if err != nil {
		return a.returnErr(err)
	}

	a.stage = "done"
	return nil
}

func (a *Task) eval() error {
	a.stage = "eval"
	eval := exec.Command("nix", "eval", "--raw", ".#task.x86_64-linux."+a.name+".run.outPath")
	eval.Stderr = a.stderrWr
	storePath, err := eval.Output()
	if err != nil {
		return errors.WithMessagef(err, "Failed to run %s", eval)
	}
	a.storePath = string(storePath)
	return nil
}

// TODO: it would be nice to condense this more and speed it up, but it avoids
// putting symlinks all over the place.
func (a *Task) build() error {
	a.stage = "build"
	build := exec.Command("nix", "build", "--no-link", ".#task.x86_64-linux."+a.name+".run")
	build.Stdout = a.stdoutWr
	build.Stderr = a.stderrWr
	if err := build.Run(); err != nil {
		return errors.WithMessagef(err, "Failed to run %s", build)
	}

	a.stage = "wait"
	return nil
}

func (a *Task) exec() error {
	a.stage = "run"
	cmd := exec.Command(string(a.storePath) + "/bin/" + a.name + "-nsjail")
	cmd.Stdout = a.stdoutWr
	cmd.Stderr = a.stderrWr
	cmd.SysProcAttr = &syscall.SysProcAttr{Setpgid: true}

	a.cmd = cmd
	return cmd.Run()
}

func (a *Task) StorePath() string { return a.storePath }

func (a *Task) Retry() error {
	if a.finished == nil {
		return a.returnErr(errors.New("Can only restart finished tasks"))
	}

	a.err = nil
	a.log = []Line{}
	if err := a.eval(); err != nil {
		return a.returnErr(err)
	}
	if err := a.build(); err != nil {
		return a.returnErr(err)
	}
	return a.returnErr(a.run())
}

func (a *Task) returnErr(err error) error {
	a.stage = "error"
	a.err = err
	return err
}

func (a *Task) Signal(signal os.Signal) error {
	if a.cmd == nil || a.cmd.Process == nil {
		return errors.New("Process is not running")
	}
	defer func() {
		time.Sleep(3 * time.Second)
		_ = syscall.Kill(-a.cmd.Process.Pid, syscall.SIGKILL)
	}()
	return syscall.Kill(-a.cmd.Process.Pid, syscall.SIGINT)
}

func clamp(v, low, high int) int {
	if high < low {
		low, high = high, low
	}
	return min(high, max(low, v))
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}

func max(a, b int) int {
	if a > b {
		return a
	}
	return b
}
