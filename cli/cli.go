package main

import (
	"context"
	"fmt"
	"strings"
	"time"

	tea "github.com/charmbracelet/bubbletea"
	"github.com/charmbracelet/lipgloss"
	"github.com/rs/zerolog"
)

type CLIModel struct {
	tree  *Tree
	width int
	ctx   context.Context
	log   zerolog.Logger
}

type contextMsg struct{}

func waitForContext(ctx context.Context) tea.Cmd {
	return func() tea.Msg {
		return contextMsg(<-ctx.Done())
	}
}

type refreshMsg time.Time

func refresh() tea.Cmd {
	return func() tea.Msg {
		return refreshMsg(<-time.After(33 * time.Millisecond))
	}
}

func (m *CLIModel) Init() tea.Cmd {
	return tea.Batch(refresh(), waitForContext(m.ctx))
}

func (m *CLIModel) Update(recv tea.Msg) (tea.Model, tea.Cmd) {
	switch msg := recv.(type) {
	case tea.KeyMsg:
		switch msg.String() {
		case "q", "esc", "ctrl+c":
			return m, tea.Quit
		}
	case contextMsg:
		return m, tea.Quit
	case refreshMsg:
		return m, refresh()
	case tea.WindowSizeMsg:
		m.width = msg.Width
	}

	return m, nil
}

var (
	green = lipgloss.Color("#a8cc8c")
	blue  = lipgloss.Color("#73bef3")
	red   = lipgloss.Color("#e88388")
	teal  = lipgloss.Color("#73bef3")
)

func (m *CLIModel) View() string {
	taskNameLen := 0
	tasks := map[string]*Task{}
	for _, taskName := range m.tree.taskNames {
		vert, err := m.tree.dag.GetVertex(taskName)
		if err != nil {
			// TODO: proper error handling
			m.log.Fatal().Err(err).Str("task", taskName).Msg("missing vertex")
		}
		tasks[taskName] = vert.Value.(*Task)
		if len(taskName) > taskNameLen {
			taskNameLen = len(taskName)
		}
	}

	styleLine := lipgloss.NewStyle().Width(m.width).MaxWidth(m.width)
	styleDuration := lipgloss.NewStyle().Margin(0, 0, 0, 2)

	lines := []string{}
	for _, taskName := range m.tree.taskNames {
		task := tasks[taskName]
		if task.stage == "" {
			continue
		}

		var startTime, endTime time.Time
		if !task.runStart.IsZero() {
			startTime, endTime = task.runStart, task.runEnd
		} else if !task.buildStart.IsZero() {
			startTime, endTime = task.buildStart, task.buildEnd
		} else if !task.evalStart.IsZero() {
			startTime, endTime = task.evalStart, task.evalEnd
		} else {
			startTime, endTime = time.Now(), time.Now()
		}
		if endTime.IsZero() {
			endTime = time.Now()
		}

		duration := endTime.Sub(startTime)

		var line, durationOut string
		var color lipgloss.Color
		switch task.stage {
		case "wait":
			color = blue
			line = fmt.Sprintf("[%s] %s", "+", taskName)
			durationOut = fmt.Sprintf("%3.1fs", duration.Seconds())
		case "eval", "build", "run":
			color = teal
			line = fmt.Sprintf("[%s] %s", "+", taskName)
			durationOut = fmt.Sprintf("%3.1fs", duration.Seconds())
		case "error":
			color = red
			line = fmt.Sprintf("[%s] %s", "✗", taskName)
			durationOut = duration.String()
		case "cancel":
			color = teal
			line = fmt.Sprintf("[%s] %s", "✗", taskName)
			durationOut = "0.0s"
		case "done":
			color = green
			line = fmt.Sprintf("[%s] %s", "✔", taskName)
			durationOut = duration.String()
		}

		timestamp := styleDuration.Render(durationOut)
		width := min(m.width-lipgloss.Width(timestamp), taskNameLen+5)
		styleLeft := lipgloss.NewStyle().Width(width)

		lines = append(lines, styleLine.Foreground(color).Render(
			lipgloss.JoinHorizontal(
				lipgloss.Top,
				styleLeft.Render(line),
				timestamp,
			),
		))

		if task.cliLines != nil {
			switch task.stage {
			case "error", "run":
				logLength := 10
				all := strings.Split(task.cliLines.String(), "\n")
				if task.stage == "error" {
					logLength = len(all)
				}

				n := len(all) - min(len(all), logLength)
				for _, line := range all[n:] {
					l := strings.TrimSpace(line)
					if l != "" {
						lines = append(lines, styleLine.Foreground(lipgloss.Color("#b9c0cb")).Render(l))
					}
				}
			}
		}

		if task.stage == "error" {
			lines = append(lines, styleLine.Render(task.err.Error()))
		}
	}

	out := lipgloss.JoinVertical(0, lines...)
	return lipgloss.NewStyle().Height(lipgloss.Height(out) + 1).Render(out)
}
