package main

import (
	"encoding/json"
	"fmt"
	"os"

	arg "github.com/alexflint/go-arg"
	"github.com/rs/zerolog"
)

var buildVersion = "dev"
var buildCommit = "dirty"

type RunSpec struct {
	Dag map[string][]string `json:"dag"`
	Bin map[string]string   `json:"bin"`
}

func (r RunSpec) MarshalZerologObject(event *zerolog.Event) {
	dag := zerolog.Dict()
	for k, v := range r.Dag {
		dag.Strs(k, v)
	}
	event.Dict("Dag", dag)

	bin := zerolog.Dict()
	for k, v := range r.Bin {
		dag.Str(k, v)
	}
	event.Dict("Bin", bin)
}

type Config struct {
	LogLevel string `arg:"--log-level" default:"trace" help:"one of trace,debug,info,warn,error,fatal,panic"`
	Do       *Do    `arg:"subcommand:do" help:"execute the given task"`
	log      zerolog.Logger
}

type Do struct {
	Task      string `arg:"positional"`
	DagFlake  string `arg:"--dag-flake" default:".#tullia.x86_64-linux.dag"`
	Mode      string `arg:"--mode" default:"cli"`
	Runtime   string `arg:"--runtime" default:"nsjail"`
	TaskFlake string `arg:"--task-flake" default:".#tullia.x86_64-linux.wrappedTask"`
	RunSpec   string `arg:"--run-spec" help:"used internally"`
	runSpec   *RunSpec
}

func (d Do) MarshalZerologObject(event *zerolog.Event) {
	event.
		Str("Task", d.Task).
		Str("DagFlake", d.DagFlake).
		Str("Mode", d.Mode).
		Str("Runtime", d.Runtime).
		Str("TaskFlake", d.TaskFlake)
	if d.runSpec != nil {
		event.Object("RunSpec", d.runSpec)
	}
}

func Version() string {
	return fmt.Sprintf("%s (%s)", buildVersion, buildCommit)
}

func (Config) Version() string {
	return fmt.Sprintf("cicero %s", Version())
}

func main() {
	log := zerolog.New(zerolog.NewConsoleWriter()).With().Timestamp().Logger()

	config := Config{log: log}

	parser, err := arg.NewParser(arg.Config{}, &config)
	if err != nil {
		log.Fatal().Err(err).Msg("initializing argument parser")
	}

	err = parser.Parse(os.Args[1:])

	switch err {
	case nil:
	case arg.ErrHelp:
		parser.WriteHelp(os.Stdout)
		os.Exit(0)
	case arg.ErrVersion:
		fmt.Fprintln(os.Stdout, Version())
		os.Exit(0)
	default:
		log.Fatal().Err(err).Msg("parsing arguments")
	}

	if logLevel, err := zerolog.ParseLevel(config.LogLevel); err != nil {
		log.Fatal().Err(err).Msg("setting log level")
	} else {
		zerolog.SetGlobalLevel(logLevel)
	}

	switch {
	case config.Do != nil:
		if len(config.Do.RunSpec) > 0 {
			rs := &RunSpec{}
			if err := json.Unmarshal([]byte(config.Do.RunSpec), rs); err != nil {
				log.Fatal().Err(err).Msg("parsing run spec")
			}
			config.Do.runSpec = rs
		}

		log.Debug().Object("config", config.Do).Msg("parsed args")

		if sv, err := supervisor(config); err != nil {
			log.Fatal().Err(err).Msg("creating supervisor")
		} else if err := sv.start(); err != nil {
			log.Fatal().Err(err).Msg("starting supervisor")
		}
	default:
		parser.WriteHelp(os.Stderr)
	}
}

func min(a, b int) int {
	if a < b {
		return a
	}
	return b
}
