package main

import (
	"encoding/json"
	"fmt"
	"os"

	arg "github.com/alexflint/go-arg"
)

var buildVersion = "dev"
var buildCommit = "dirty"

type RunSpec struct {
	Dag map[string][]string `json:"dag"`
	Bin map[string]string   `json:"bin"`
}

type Config struct {
	DagFlake  string `arg:"--dag-flake"`
	Mode      string `arg:"--mode"`
	Runtime   string `arg:"--runtime"`
	TaskFlake string `arg:"--task-flake"`
	Task      string `arg:"positional"`

	RunSpec string `arg:"--run-spec"`
	runSpec *RunSpec
}

func Version() string {
	return fmt.Sprintf("%s (%s)", buildVersion, buildCommit)
}

func (Config) Version() string {
	return fmt.Sprintf("cicero %s", Version())
}

func main() {
	config := Config{
		DagFlake:  ".#dag",
		Mode:      "cli",
		Runtime:   "nsjail",
		Task:      "",
		TaskFlake: ".#task",
	}
	arg.MustParse(&config)

	if len(config.RunSpec) > 0 {
		rs := &RunSpec{}
		if err := json.Unmarshal([]byte(config.RunSpec), rs); err != nil {
			fmt.Println(err.Error())
			os.Exit(1)
		}
		config.runSpec = rs
	}

	if sv, err := supervisor(config); err != nil {
		panic(err)
	} else if err := sv.start(); err != nil {
		panic(err)
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
