package dag

import (
	"encoding/json"
	"os"
	"os/exec"
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
	dag     *gdag.DAG
	actions []*Action
	prepare *sync.WaitGroup
	start   *sync.WaitGroup
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
		actions: []*Action{},
		prepare: &sync.WaitGroup{},
		start:   &sync.WaitGroup{},
	}
	dag.prepare.Add(1)

	for key := range dagSource {
		a := NewAction(key)
		if err := dag.dag.AddVertex(gdag.NewVertex(key, a)); err != nil {
			return nil, errors.WithMessagef(err, "Failed to add vertex %q -> %q", key, a)
		}
	}

	for key, afters := range dagSource {
		for _, after := range afters {
			if a, err := dag.dag.GetVertex(after); err != nil {
				return nil, errors.WithMessagef(err, "Failed to get vertex %q", after)
			} else if k, err := dag.dag.GetVertex(key); err != nil {
				return nil, errors.WithMessagef(err, "Failed to get vertex %q", key)
			} else if err := dag.dag.AddEdge(a, k); err != nil {
				return nil, errors.WithMessagef(err, "Failed to add edge %q -> %q", after, key)
			}
		}
	}

	for key := range dagSource {
		if v, err := dag.dag.GetVertex(key); err != nil {
			return nil, errors.WithMessagef(err, "Failed to get vertex %q", key)
		} else {
			v.Value.(*Action).dependencies.Add(len(v.Parents.Values()))
		}
	}

	return dag, nil
}

func (d *DAG) Actions() []*Action {
	return d.actions
}

func (d *DAG) Start() {
	d.prepare.Done()
	d.start.Wait()
}

func (d *DAG) Prepare(actionName string) error {
	root, err := d.dag.GetVertex(actionName)
	if err != nil {
		return errors.WithMessagef(err, "Failed to get vertex %q", actionName)
	}

	if err := d.prepareInner(root); err != nil {
		return errors.WithMessagef(err, "Failed to run %q", actionName)
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

	a := vert.Value.(*Action)

	fail := func(err error) bool {
		if err == nil {
			return false
		}
		a.stage = "error"
		a.err = err
		for _, successor := range successors {
			saction := successor.Value.(*Action)
			saction.err = errors.WithMessagef(err, "%q failed", a.name)
			saction.dependencies.Done()
		}
		d.start.Done()
		return true
	}

	a.once.Do(func() {
		d.actions = append(d.actions, a)
		d.start.Add(1)

		go func() {
			d.prepare.Wait()

			if fail(a.eval()) {
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
				successor.Value.(*Action).dependencies.Done()
			}
			d.start.Done()
		}()

		for _, predecessor := range predecessors {
			d.prepareInner(predecessor)
		}
	})

	return nil
}
