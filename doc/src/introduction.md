# Introduction

The Tullia project provides a CLI and various library functions for writing and
executing tasks in a multitude of languages.

Tasks are executed in a DAG, so they can depend on each other. Cyclic
dependencies are not allowed.

Each task is executed in a sandbox. This means that it will not inherit any
environment variables, it cannot access the rest of your files, and you may
limit resource usage or disable networking.

It supports task execution using `nsjail`, `podman`, and `nomad`. We plan to
add more runtimes in the future to support MacOS and Windows as well.

A simple task may look like this:

```nix
{
  hello.command.text = "echo Hello";
}
```

The default `command.type` is `shell`, which is executed with `bash`.
