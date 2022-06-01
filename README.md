# Tullia

The standard library and CLI for
[Cicero](https://github.com/input-output-hk/cicero) tasks and actions.

## Goals

* Enforce identical environments across dev, CI, and prod.
* Speed up the development cycle
* Spark the joy of using Nix

## About

We use Tullia as a handy tool for running code in isolation. It consumes task
definitions written in Nix, and runs the task and its dependencies.

The goal for this project is to enforce identical environments during
development, CI, and when deployed.

The task and its dependencies run in `nsjail` by default. There is also
`podman` support available, but it's not as mature yet.

This allows better isolation and control than a pure nix shell and behaves
similiar to sandboxes of Nix derivations.

That means that the task will only be able to see files in the current working
directory, and may only use explicitly declared dependencies. It's also
possible to disable networking, restrict resources like CPU and RAM, amongst
other things.

This can also be helpful when working on a derivation that takes a lot of time
to build, by invoking a compiler but retaining caches between runs.

## CLI

### Installation

    nix profile install github:input-output-hk/tullia

### Usage

    ❯ tullia list
    ┌ tullia run
    ├─┬ build
    │ └── bump
    ├─┬ bump
    │ └── lint
    ├─┬ lint
    │ └── tidy
    └── tidy

    ❯ tullia run build
    [✔] done   build       38.055659394s
    [✔] done   bump        36.479661466s
    [✔] done   lint        10.892518424s
    [✔] done   tidy        5.069157358s

### Mode

Tullia can be invoked with the `--mode` flag to change its output and some
runtime behaviour.

#### CLI

With `cli`, the output is rendered in a pretty fashion, keeping track of
the time each task execution takes and showing logs only in case of errors.

#### Verbose

Passing `verbose` shows the inner workings of task execution.

#### JSON

Setting the mode to `json` is similar to `verbose`, but instead of
human-readable logs it outputs JSONL which is better suited for further
digesting the logs.

#### Passthrough

The `passthrough` mode is mostly useful for recursive invocations of Tullia. In
this mode Tullia will not output anything itself, but instead pass on
`std{in,out,err}` to the tasks it invokes and give control over the tty to
them. This should only be required in rare cases.
