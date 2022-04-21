package main

import (
	"time"

	"github.com/charmbracelet/bubbles/help"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/input-output-hk/cicero-lib/dag"
	"github.com/muesli/termenv"
)

func NewModel(config Config, dag *dag.DAG) *Model {
	return &Model{
		config: config,
		dag:    dag,
		help:   help.New(),
		keys:   Keys,
		scroll: -2,
		width:  10,
		height: 10,
	}
}

func (m *Model) Init() tea.Cmd {
	termenv.SetWindowTitle("Tullia")
	go m.dag.Start()
	return m.ticker()
}

type Model struct {
	config        Config
	width, height int
	lastMsg       tea.Msg
	lastErr       error
	dbg           interface{}
	keys          KeyMap
	dag           *dag.DAG
	help          help.Model
	logOnly       bool
	cursor        int
	scroll        Scroll
}

type Scroll int

type TickMsg time.Time

// TODO: stop if everything is done/error
func (m *Model) ticker() tea.Cmd {
	return tea.Tick(time.Millisecond*100, func(t time.Time) tea.Msg {
		return TickMsg(t)
	})
}
