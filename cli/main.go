package main

import (
	"fmt"
	"os"
	"os/exec"

	arg "github.com/alexflint/go-arg"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/input-output-hk/cicero-lib/dag"
)

type Config struct {
	Flake  string `arg:"-f,--flake"`
	System string `arg:"--system"`
	Action string `arg:"positional"`
}

func (c Config) FlakeAttr() string {
	return fmt.Sprintf("%s#dag.%s", c.Flake, c.System)
}

func main() {
	config := Config{Flake: ".", Action: "", System: currentSystem()}
	arg.MustParse(&config)

	dag, err := dag.New(config.FlakeAttr())
	if err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}

	if err := dag.Prepare(config.Action); err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}

	if err := tea.NewProgram(NewModel(config, dag)).Start(); err != nil {
		fmt.Println(err)
		os.Exit(1)
	}
}

func currentSystem() string {
	cmd := exec.Command("nix", "eval", "--impure", "--raw", "--expr", "builtins.currentSystem")
	out, err := cmd.CombinedOutput()
	if err != nil {
		fmt.Println(string(out))
		fmt.Println(err)
		os.Exit(1)
	}
	return string(out)
}
