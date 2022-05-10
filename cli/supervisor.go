package main

import (
	"context"
	"fmt"

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
	switch s.config.Run.Mode {
	case "cli":
		return s.startCLI()
	case "verbose", "passthrough":
		return s.startVerbose()
	default:
		return fmt.Errorf("Unknown mode: %q", s.config.Run.Mode)
	}
}

func (s *Supervisor) startCLI() error {
	if err := s.tree.prepare(s.config.Run.Task); err != nil {
		return err
	}

	ctx, cancel := context.WithCancel(context.Background())
	failed := make(chan error, 1)

	go func() {
		err := s.tree.start()
		cancel()
		failed <- err
	}()

	if err := tea.NewProgram(&CLIModel{tree: s.tree, ctx: ctx, log: s.config.log}).Start(); err != nil {
		s.config.log.Fatal().Err(err).Msg("starting CLI")
	}

	return <-failed
}

func (s *Supervisor) startVerbose() error {
	if err := s.tree.prepare(s.config.Run.Task); err != nil {
		return err
	}

	return s.tree.start()
}
