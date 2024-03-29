package main

import (
	"encoding/json"
	"fmt"
	"os"
	"strings"

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
		bin.Str(k, v)
	}
	event.Dict("Bin", bin)
}

type Config struct {
	LogLevel string `arg:"--log-level,env:LOG_LEVEL" default:"info" help:"one of trace,debug,info,warn,error,fatal,panic"`
	Run      *Run   `arg:"subcommand:run" help:"execute the given task"`
	List     *List  `arg:"subcommand:list" help:"show a list of available tasks"`
	log      zerolog.Logger
}

type Run struct {
	Task      string `arg:"positional"`
	DagFlake  string `arg:"--dag-flake,env:DAG_FLAKE" default:".#tullia.x86_64-linux.dag"`
	Mode      string `arg:"--mode,env:MODE" default:"cli"`
	Runtime   string `arg:"--runtime,env:RUNTIME" default:"nsjail"`
	TaskFlake string `arg:"--task-flake,env:TASK_FLAKE" default:".#tullia.x86_64-linux.task"`
	RunSpec   string `arg:"--run-spec,env:RUN_SPEC" help:"used internally. Start with @ to read from a file."`
	runSpec   *RunSpec
}

func (d Run) MarshalZerologObject(event *zerolog.Event) {
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

type List struct {
	DagFlake string `arg:"--dag-flake" default:".#tullia.x86_64-linux.dag"`
	Style    string `arg:"--style" default:"compact" help:"one of compact,rounded,dotted,basic"`
}

func (d List) MarshalZerologObject(event *zerolog.Event) {
	event.Str("DagFlake", d.DagFlake)
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
	case config.List != nil:
		if err := config.List.start(); err != nil {
			log.Fatal().Err(err).Msg("starting list")
		}
	case config.Run != nil:
		if len(config.Run.RunSpec) > 0 {
			rs := &RunSpec{}

			rsStr := []byte(config.Run.RunSpec)
			if strings.HasPrefix(config.Run.RunSpec, "@") {
				if contents, err := os.ReadFile(config.Run.RunSpec[1:]); err != nil {
					log.Fatal().Err(err).Msg("reading run spec from file")
				} else {
					rsStr = contents
				}
			}

			if err := json.Unmarshal(rsStr, rs); err != nil {
				log.Fatal().Err(err).Msg("parsing run spec")
			}

			config.Run.runSpec = rs
		}

		log.Debug().Object("config", config.Run).Msg("parsed args")

		if sv, err := supervisor(config); err != nil {
			log.Fatal().Err(err).Msg("creating supervisor")
		} else if err := sv.start(); err != nil {
			log.Fatal().Err(err).Msg("starting supervisor")
		}
		log.Debug().Msg("done")
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
