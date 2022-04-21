package main

import "github.com/charmbracelet/bubbles/key"

type KeyMap struct {
	Up          key.Binding
	Down        key.Binding
	Enter       key.Binding
	Quit        key.Binding
	Help        key.Binding
	LogOnly     key.Binding
	LogPageUp   key.Binding
	LogPageDown key.Binding
	ActionRetry key.Binding
	ActionKill  key.Binding
}

var Keys = KeyMap{
	Up: key.NewBinding(
		key.WithKeys("up", "k"),
		key.WithHelp("↑/k", "up"),
	),
	Down: key.NewBinding(
		key.WithKeys("down", "j"),
		key.WithHelp("↓/j", "down"),
	),
	Enter: key.NewBinding(
		key.WithKeys("enter"),
		key.WithHelp("enter", "select item"),
	),
	Quit: key.NewBinding(
		key.WithKeys("ctrl+c", "q"),
		key.WithHelp("^C/q", "quit"),
	),
	Help: key.NewBinding(
		key.WithKeys("?"),
		key.WithHelp("?", "help"),
	),
	LogOnly: key.NewBinding(
		key.WithKeys("O"),
		key.WithHelp("O", "show only logs"),
	),
	LogPageUp: key.NewBinding(
		key.WithKeys("pgup"),
		key.WithHelp("pgup", "Page up in the log"),
	),
	LogPageDown: key.NewBinding(
		key.WithKeys("pgdown"),
		key.WithHelp("pgdown", "Page down in the log"),
	),
	ActionRetry: key.NewBinding(
		key.WithKeys("R"),
		key.WithHelp("R", "Retry action"),
	),
	ActionKill: key.NewBinding(
		key.WithKeys("K"),
		key.WithHelp("K", "Kill action"),
	),
}

func (k KeyMap) ShortHelp() []key.Binding {
	return []key.Binding{k.Quit, k.Help, k.Up, k.Down, k.LogOnly, k.ActionKill, k.ActionRetry}
}

func (k KeyMap) FullHelp() [][]key.Binding {
	return [][]key.Binding{
		{k.Quit, k.Help},
		{k.Up, k.Down, k.Enter},
	}
}
