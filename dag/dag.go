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
	TaskNames    []string
	DAG          *gdag.DAG
	Tasks        []*Task
	PrepareGroup *sync.WaitGroup
	StartGroup   *sync.WaitGroup
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
		DAG:          gdag.NewDAG(),
		Tasks:        []*Task{},
		PrepareGroup: &sync.WaitGroup{},
		StartGroup:   &sync.WaitGroup{},
	}

	for taskName := range dagSource {
		dag.TaskNames = append(dag.TaskNames, taskName)
		a := NewTask(taskName)
		if err := dag.DAG.AddVertex(gdag.NewVertex(taskName, a)); err != nil {
			return nil, errors.WithMessagef(err, "Failed to add vertex %q", taskName)
		}
	}

	for taskName, afters := range dagSource {
		for _, after := range afters {
			if a, err := dag.DAG.GetVertex(after); err != nil {
				return nil, errors.WithMessagef(err, "Failed to get vertex %q", after)
			} else if k, err := dag.DAG.GetVertex(taskName); err != nil {
				return nil, errors.WithMessagef(err, "Failed to get vertex %q", taskName)
			} else if err := dag.DAG.AddEdge(a, k); err != nil {
				return nil, errors.WithMessagef(err, "Failed to add edge %q -> %q", after, taskName)
			}
		}
	}

	for taskName := range dagSource {
		if v, err := dag.DAG.GetVertex(taskName); err != nil {
			return nil, errors.WithMessagef(err, "Failed to get vertex %q", taskName)
		} else {
			t := v.Value.(*Task)
			successors, err := dag.DAG.Successors(v)
			if err != nil {
				return dag, errors.WithMessagef(err, "Failed to get successors of task %q", v.ID)
			}
			t.successors = successors

			predecessors, err := dag.DAG.Predecessors(v)
			if err != nil {
				return dag, errors.WithMessagef(err, "Failed to get predecessors of task %q", v.ID)
			}
			t.predecessors = predecessors

			t.dependencies.Add(len(v.Parents.Values()))
		}
	}

	return dag, nil
}

func (d *DAG) Start() {
	d.PrepareGroup.Done()
	d.StartGroup.Wait()
}

func (d *DAG) Prepare(taskName string) error {
	d.PrepareGroup.Add(1)
	root, err := d.DAG.GetVertex(taskName)
	if err != nil {
		if err.Error() == fmt.Sprintf("vertex %s not found in the graph", taskName) {
			return fmt.Errorf("Available tasks: %s\n", strings.Join(d.TaskNames, " "))
		}
		return errors.WithMessagef(err, "Failed to get vertex %q", taskName)
	}

	if err := d.prepareInner(root); err != nil {
		return errors.WithMessagef(err, "Failed to run %q", taskName)
	}
	return nil
}

func (d *DAG) prepareInner(vert *gdag.Vertex) error {
	a := vert.Value.(*Task)

	fail := func(err error) bool {
		if err == nil {
			return false
		}
		a.stage = "error"
		a.err = err
		for _, successor := range a.successors {
			stask := successor.Value.(*Task)
			stask.err = errors.WithMessagef(err, "%q failed", a.name)
			stask.dependencies.Done()
		}
		d.StartGroup.Done()
		return true
	}

	a.once.Do(func() {
		d.Tasks = append(d.Tasks, a)
		d.StartGroup.Add(1)

		go func() {
			d.PrepareGroup.Wait()

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

			for _, successor := range a.successors {
				successor.Value.(*Task).dependencies.Done()
			}
			d.StartGroup.Done()
		}()

		for _, predecessor := range a.predecessors {
			if fail(d.prepareInner(predecessor)) {
				return
			}
		}
	})

	return nil
}
