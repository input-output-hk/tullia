package main

import (
	"fmt"
	"os"
	"os/exec"

	arg "github.com/alexflint/go-arg"
	tea "github.com/charmbracelet/bubbletea"
	"github.com/input-output-hk/tullia/dag"
)

type Config struct {
	Flake   string `arg:"--flake"`
	System  string `arg:"--system"`
	Task    string `arg:"positional"`
	Mode    string `arg:"--mode"`
	Runtime string `arg:"--runtime"`
}

func (c Config) FlakeAttr() string {
	return fmt.Sprintf("%s#dag.%s", c.Flake, c.System)
}

func main() {
	config := Config{Flake: ".", Task: "", System: currentSystem(), Mode: "cli", Runtime: "nsjail"}
	arg.MustParse(&config)

	if sv, err := supervisor(config); err != nil {
		panic(err)
	} else if err := sv.start(); err != nil {
		panic(err)
	}
	os.Exit(0)

	dag, err := dag.New(config.FlakeAttr())
	if err != nil {
		fmt.Println(err.Error())
		os.Exit(1)
	}

	if err := dag.Prepare(config.Task); err != nil {
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

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
