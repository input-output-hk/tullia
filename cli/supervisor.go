package main

import (
	"context"
	"fmt"
	"os"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/rs/zerolog"
)

type Supervisor struct {
	tree      *Tree
	TaskNames []string
	config    Config
}

func supervisor(config Config) (*Supervisor, error) {
	log := zerolog.
		New(zerolog.NewConsoleWriter()).
		With().
		Timestamp().
		Logger()

	if tree, err := newTree(log, config); err != nil {
		return nil, err
	} else {
		return &Supervisor{tree: tree, config: config}, nil
	}
}

func (s *Supervisor) start() error {
	switch s.config.Mode {
	case "json":
		return nil
	case "cli":
		return s.startCLI()
	case "verbose":
		return s.startVerbose()
	case "passthrough":
		return s.startVerbose()
	default:
		return fmt.Errorf("Unknown mode: %q", s.config.Mode)
		// return s.tree.start()
	}
}

func (s *Supervisor) startCLI() error {
	if err := s.tree.prepare(s.config.Task); err != nil {
		return err
	}

	ctx, cancel := context.WithCancel(context.Background())

	go func() {
		s.tree.start()
		cancel()
	}()

	if err := tea.NewProgram(&CLIModel{tree: s.tree, ctx: ctx}).Start(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}

	return nil
}

func (s *Supervisor) startVerbose() error {
	if err := s.tree.prepare(s.config.Task); err != nil {
		return err
	}

	s.tree.start()

	return nil
}
