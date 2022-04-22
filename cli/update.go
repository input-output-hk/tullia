package main

import (
	"errors"
	"syscall"

	"github.com/charmbracelet/bubbles/key"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/input-output-hk/cicero-lib/dag"
)

func (m *Model) Update(msgI tea.Msg) (tea.Model, tea.Cmd) {
	cmds := []tea.Cmd{}

	switch msg := msgI.(type) {
	case TickMsg:
		// m.dbg = time.Time(msg).Format(time.RFC3339)
		cmds = append(cmds, m.ticker())
	case tea.WindowSizeMsg:
		m.width = msg.Width
		m.height = msg.Height
	case tea.KeyMsg:
		switch {
		case key.Matches(msg, m.keys.Quit):
			cmds = append(cmds, tea.Quit)
		case key.Matches(msg, m.keys.Up):
			m.moveCursor(-1)
		case key.Matches(msg, m.keys.Down):
			m.moveCursor(1)
		case key.Matches(msg, m.keys.Help):
			m.help.ShowAll = !m.help.ShowAll
		case key.Matches(msg, m.keys.LogOnly):
			m.logOnly = !m.logOnly
		case key.Matches(msg, m.keys.LogPageUp):
			m.pageUp()
		case key.Matches(msg, m.keys.LogPageDown):
			m.pageDown()
		case key.Matches(msg, m.keys.TaskRetry):
			m.taskRetry()
		case key.Matches(msg, m.keys.TaskKill):
			m.taskKill()
		default:
			m.lastMsg = msgI
		}
	default:
		m.lastMsg = msgI
	}

	return m, tea.Batch(cmds...)
}

func (m *Model) taskRetry() {
	task, err := m.getCursorItem()
	if err != nil {
		return
	}
	m.lastErr = task.Retry()
}

func (m *Model) moveCursor(n int) {
	tasks := m.dag.Tasks()
	nn := m.cursor + n
	if nn >= len(tasks) {
		nn = len(tasks) - 1
	} else if nn < 0 {
		nn = 0
	}

	m.cursor = nn
}

func (m *Model) getCursorItem() (*dag.Task, error) {
	tasks := m.dag.Tasks()
	if m.cursor < 0 || m.cursor >= len(tasks) {
		return nil, errors.New("invalid cursor or empty list")
	}
	return tasks[m.cursor], nil
}

func (m *Model) pageUp() {
	switch m.scroll {
	case -1:
		return
	case -2:
		task, err := m.getCursorItem()
		if err != nil {
			m.scroll = -1
		} else {
			m.scroll = Scroll(task.Len() - (m.height + (m.height / 2)))
		}
	default:
		m.scroll -= Scroll(m.height / 2)
		if m.scroll <= 0 {
			m.scroll = -1
		}
	}
}

func (m *Model) pageDown() {
	if m.scroll == -2 {
		return
	}
	m.scroll += (Scroll(m.height) / 2)
	task, err := m.getCursorItem()
	if err != nil {
		m.scroll = -1
	} else {
		if (m.height + int(m.scroll)) >= task.Len() {
			m.scroll = -2
		}
	}
}

func (m *Model) taskKill() {
	task, err := m.getCursorItem()
	if err != nil {
		m.lastErr = err
		return
	}
	if err := task.Signal(syscall.SIGINT); err != nil {
		m.lastErr = err
	}
}
