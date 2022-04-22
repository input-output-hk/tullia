package dag

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"strings"
	"sync"
	"time"

	gdag "github.com/goombaio/dag"
	"github.com/pkg/errors"
)

type Progress struct {
	Msg     string
	Cmd     *exec.Cmd
	Err     error
	Elapsed time.Duration
}

type DAG struct {
	taskNames []string
	dag       *gdag.DAG
	tasks     []*Task
	prepare   *sync.WaitGroup
	start     *sync.WaitGroup
}

func New(flake string) (*DAG, error) {
	cmd := exec.Command("nix", "eval", "--json", flake)
	outPipe, err := cmd.StdoutPipe()
	if err != nil {
		return nil, errors.WithMessage(err, "Failed to create pipe for stdout")
	}
	cmd.Stderr = os.Stderr

	dagSource := map[string][]string{}

	go func() {
		if err := json.NewDecoder(outPipe).Decode(&dagSource); err != nil {
			panic(err)
		} else if err := outPipe.Close(); err != nil {
			panic(err)
		}
	}()

	if err := cmd.Run(); err != nil {
		return nil, errors.WithMessagef(err, "Failed to run %q", cmd)
	}

	dag := &DAG{
		dag:     gdag.NewDAG(),
		tasks:   []*Task{},
		prepare: &sync.WaitGroup{},
		start:   &sync.WaitGroup{},
	}
	dag.prepare.Add(1)

	for taskName := range dagSource {
		dag.taskNames = append(dag.taskNames, taskName)
		a := NewTask(taskName)
		if err := dag.dag.AddVertex(gdag.NewVertex(taskName, a)); err != nil {
			return nil, errors.WithMessagef(err, "Failed to add vertex %q -> %q", taskName, a)
		}
	}

	for taskName, afters := range dagSource {
		for _, after := range afters {
			if a, err := dag.dag.GetVertex(after); err != nil {
				return nil, errors.WithMessagef(err, "Failed to get vertex %q", after)
			} else if k, err := dag.dag.GetVertex(taskName); err != nil {
				return nil, errors.WithMessagef(err, "Failed to get vertex %q", taskName)
			} else if err := dag.dag.AddEdge(a, k); err != nil {
				return nil, errors.WithMessagef(err, "Failed to add edge %q -> %q", after, taskName)
			}
		}
	}

	for taskName := range dagSource {
		if v, err := dag.dag.GetVertex(taskName); err != nil {
			return nil, errors.WithMessagef(err, "Failed to get vertex %q", taskName)
		} else {
			v.Value.(*Task).dependencies.Add(len(v.Parents.Values()))
		}
	}

	return dag, nil
}

func (d *DAG) Tasks() []*Task {
	return d.tasks
}

func (d *DAG) Start() {
	d.prepare.Done()
	d.start.Wait()
}

func (d *DAG) Prepare(taskName string) error {
	root, err := d.dag.GetVertex(taskName)
	if err != nil {
		if err.Error() == "vertex  not found in the graph" {
			return fmt.Errorf("Available tasks: %s\n", strings.Join(d.taskNames, " "))
		}
		return errors.WithMessagef(err, "Failed to get vertex %q", taskName)
	}

	if err := d.prepareInner(root); err != nil {
		return errors.WithMessagef(err, "Failed to run %q", taskName)
	}
	return nil
}

func (d *DAG) prepareInner(vert *gdag.Vertex) error {
	successors, err := d.dag.Successors(vert)
	if err != nil {
		return errors.WithMessagef(err, "Failed to get successors of task %q", vert.ID)
	}

	predecessors, err := d.dag.Predecessors(vert)
	if err != nil {
		return errors.WithMessagef(err, "Failed to get predecessors of task %q", vert.ID)
	}

	a := vert.Value.(*Task)

	fail := func(err error) bool {
		if err == nil {
			return false
		}
		a.stage = "error"
		a.err = err
		for _, successor := range successors {
			stask := successor.Value.(*Task)
			stask.err = errors.WithMessagef(err, "%q failed", a.name)
			stask.dependencies.Done()
		}
		d.start.Done()
		return true
	}

	a.once.Do(func() {
		d.tasks = append(d.tasks, a)
		d.start.Add(1)

		go func() {
			d.prepare.Wait()

			if fail(a.eval()) {
				return
			}

			if fail(a.build()) {
				return
			}

			a.dependencies.Wait()
			if fail(a.err) {
				return
			}

			if fail(a.run()) {
				return
			}

			for _, successor := range successors {
				successor.Value.(*Task).dependencies.Done()
			}
			d.start.Done()
		}()

		for _, predecessor := range predecessors {
			if fail(d.prepareInner(predecessor)) {
				return
			}
		}
	})

	return nil
}
