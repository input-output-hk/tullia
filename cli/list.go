package main

import (
	"fmt"
	"os"
	"sort"

	"github.com/plouc/textree"
)

func (l List) start() error {
	o := textree.NewRenderOptions()
	switch l.Style {
	case "compact":
		o.Compact()
	case "rounded":
		o.Rounded()
	case "dotted":
		o.Dotted()
	case "basic":
	default:
		fmt.Fprintf(os.Stderr, "Unknown style: %q\n", l.Style)
		os.Exit(1)
	}

	dag, err := parseDag(l.DagFlake)
	if err != nil {
		return err
	}

	keys := []string{}
	for k, v := range dag {
		keys = append(keys, k)
		sort.Strings(v)
	}
	sort.Strings(keys)

	root := textree.NewNode("tullia run")

	for _, key := range keys {
		child := textree.NewNode(key)
		root.Append(child)

		for _, value := range dag[key] {
			child.Append(textree.NewNode(value))
		}
	}

	root.Render(os.Stdout, o)
	return nil
}
