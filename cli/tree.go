package main

import (
	"encoding/json"
	"fmt"
	"os"
	"os/exec"
	"sort"
	"strings"
	"sync"

	"github.com/goombaio/dag"
	"github.com/pkg/errors"
	"github.com/rs/zerolog"
)

type Tree struct {
	dagResult map[string][]string
	dag       *dag.DAG
	taskNames []string
	prepareWG *sync.WaitGroup
	startWG   *sync.WaitGroup
	log       zerolog.Logger
	config    Config
}

func newTree(log zerolog.Logger, config Config) (*Tree, error) {
	tree := &Tree{
		log:     log,
		startWG: &sync.WaitGroup{},
		dag:     dag.NewDAG(),
		config:  config,
	}
	if err := tree.eval(); err != nil {
		return tree, err
	} else if err := tree.addVertices(); err != nil {
		return tree, err
	} else if err := tree.addEdges(); err != nil {
		return tree, err
	} else if err := tree.populateRelations(); err != nil {
		return tree, err
	}
	return tree, nil
}

func (t *Tree) start() error {
	if t.prepareWG == nil {
		t.config.log.Fatal().Msg("start was called before prepare")
	}
	t.prepareWG.Done()
	t.startWG.Wait()

	for _, vert := range t.dag.SinkVertices() {
		if task, ok := vert.Value.(*Task); !ok {
			return fmt.Errorf("converting vertex of %q to task", vert.ID)
		} else if task.err != nil {
			return errors.WithMessagef(task.err, "running %s", vert.ID)
		}
	}

	return nil
}

func parseDag(dagFlake string) (map[string][]string, error) {
	cmd := exec.Command("nix", "eval", "--json", dagFlake)
	cmd.Stderr = os.Stderr

	dagResult := map[string][]string{}
	if output, err := cmd.Output(); err != nil {
		return nil, errors.WithMessage(err, "running eval")
	} else if err := json.Unmarshal(output, &dagResult); err != nil {
		fmt.Println(string(output))
		return nil, errors.WithMessage(err, "parsing eval result")
	}

	return dagResult, nil
}

func (t *Tree) eval() error {
	if t.config.Run.runSpec == nil {
		if t.config.Run.Mode == "passthrough" {
			t.dagResult = map[string][]string{t.config.Run.Task: {}}
		} else {
			dagResult, err := parseDag(t.config.Run.DagFlake)
			if err != nil {
				return err
			}
			t.dagResult = dagResult
		}
	} else {
		t.dagResult = t.config.Run.runSpec.Dag
	}

	return nil
}

func (t *Tree) addVertices() error {
	for taskName := range t.dagResult {
		t.taskNames = append(t.taskNames, taskName)
		task := newTask(t.log, t.config, taskName)
		if err := t.dag.AddVertex(dag.NewVertex(taskName, task)); err != nil {
			return errors.WithMessagef(err, "Failed to add vertex %q", taskName)
		}
	}

	sort.Strings(t.taskNames)

	return nil
}

func (t *Tree) addEdges() error {
	for taskName, afters := range t.dagResult {
		for _, after := range afters {
			if vert, err := t.dag.GetVertex(after); err != nil {
				return errors.WithMessagef(err, "Failed to get vertex %q", after)
			} else if k, err := t.dag.GetVertex(taskName); err != nil {
				return errors.WithMessagef(err, "Failed to get vertex %q", taskName)
			} else if err := t.dag.AddEdge(vert, k); err != nil {
				return errors.WithMessagef(err, "Failed to add edge %q -> %q", after, taskName)
			}
		}
	}

	return nil
}

func (t *Tree) populateRelations() error {
	for taskName := range t.dagResult {
		if vert, err := t.dag.GetVertex(taskName); err != nil {
			return errors.WithMessagef(err, "Failed to get vertex %q", taskName)
		} else {
			task := vert.Value.(*Task)
			successors, err := t.dag.Successors(vert)
			if err != nil {
				return errors.WithMessagef(err, "Failed to get successors of task %q", vert.ID)
			}
			task.successors = successors

			predecessors, err := t.dag.Predecessors(vert)
			if err != nil {
				return errors.WithMessagef(err, "Failed to get predecessors of task %q", vert.ID)
			}
			task.predecessors = predecessors

			task.dependencies.Add(len(vert.Parents.Values()))
		}
	}

	return nil
}

func (t *Tree) prepare(taskName string) error {
	t.prepareWG = &sync.WaitGroup{}
	t.prepareWG.Add(1)

	root, err := t.dag.GetVertex(taskName)
	if err != nil {
		if err.Error() == fmt.Sprintf("vertex %s not found in the graph", taskName) {
			return fmt.Errorf("Available tasks: %s\n", strings.Join(t.taskNames, " "))
		}
		return errors.WithMessagef(err, "failed to get vertex %q", taskName)
	}

	return errors.WithMessagef(
		root.Value.(*Task).prepare(t.prepareWG, t.startWG),
		"failed to prepare %q", taskName)
}
