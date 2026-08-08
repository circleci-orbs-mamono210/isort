# Isort Orb

[![CircleCI Build Status](https://circleci.com/gh/circleci-orbs-mamono210/isort.svg?style=shield)](https://circleci.com/gh/circleci-orbs-mamono210/isort)
[![CircleCI Orb Version](https://badges.circleci.com/orbs/orbss/isort.svg)](https://circleci.com/orbs/registry/orb/orbss/isort)
[![GitHub License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://github.com/circleci-orbs-mamono210/isort/blob/main/LICENSE)

A CircleCI Orb for running [isort](https://pycqa.github.io/isort/), the Python import sorting tool.

This Orb provides:

- `isort/install` for installing isort with `python -m pip`
- `isort/execute` for checking or rewriting imports
- A configurable CircleCI Python executor
- Check mode by default so CI does not silently rewrite the checkout
- Direct parameters for the CI-oriented options used most often
- `extra-args` for less common isort CLI options
- Report capture to a file for storage as a CircleCI artifact

## Orb Registry

The published Orb, parameter reference and generated examples are available in the CircleCI Orb Registry:

<https://circleci.com/developer/orbs/orb/orbss/isort>

## Quick Start

```yaml
version: 2.1

orbs:
  isort: orbss/isort@0.0.2

jobs:
  execute-isort:
    executor: isort/default
    steps:
      - checkout
      - isort/install:
          version: "8.0.1"
      - isort/execute:
          diff: true

workflows:
  isort:
    jobs:
      - execute-isort
```

By default, `isort/execute` checks the current working directory recursively and fails when imports would change. `diff: true` prints the change isort would make.

Before running the check, the Orb prints the installed isort version using `isort --version-number`.

## Public API Policy

Starting with version `0.0.2`, `isort/execute` intentionally exposes only a small set of CI-oriented parameters.

Formatting details, skip rules, module classification, parallel execution and other less common isort options are not duplicated as Orb parameters. Configure them in `pyproject.toml` or another isort configuration file when they are part of the project, or pass them through `extra-args` when they are specific to a CircleCI job.

This keeps the Orb API small and reduces the amount of isort CLI behavior that the Orb has to mirror.

## Check Mode and Write Mode

isort rewrites files by default. This Orb uses `--check-only` by default because a CI job should normally report a formatting problem instead of silently modifying the checkout.

```yaml
- isort/execute:
    diff: true
    targets: src tests
```

Set `check-only: false` when the job is explicitly intended to rewrite imports:

```yaml
- isort/execute:
    check-only: false
    targets: src
```

`diff: true` prints a diff instead of applying changes.

`atomic: true` passes `--atomic`, which refuses to save output that no longer parses as Python.

## Configuration Files

For project-wide isort configuration, prefer `pyproject.toml`, `.isort.cfg`, `setup.cfg`, `tox.ini` or another configuration file supported by isort.

Example `pyproject.toml`:

```toml
[tool.isort]
profile = "black"
line_length = 100
known_first_party = ["myproject"]
extend_skip = ["migrations", "vendor"]
```

The corresponding CircleCI step can stay small:

```yaml
- isort/execute:
    diff: true
    targets: src tests
```

Use `settings-path` when the configuration file or discovery root needs to be selected explicitly:

```yaml
- isort/execute:
    settings-path: pyproject.toml
    targets: src tests
```

## Profiles

`profile` remains a first-class Orb parameter because it is commonly selected directly by CI jobs.

```yaml
- isort/execute:
    diff: true
    profile: black
    targets: src tests
```

For options that refine the profile, use the project configuration file or `extra-args`:

```yaml
- isort/execute:
    diff: true
    extra-args: --line-length 100
    profile: black
    targets: src
```

## Additional isort Options

Use `extra-args` for isort options that are not exposed as Orb parameters.

```yaml
- isort/execute:
    extra-args: >-
      --extend-skip migrations
      --extend-skip vendor
      --project myproject
      --line-length 100
    profile: black
    targets: src
```

`extra-args` is split on shell whitespace and each resulting value is passed to isort as a separate argument.

It is not evaluated as a shell command line. Shell quoting syntax is not reinterpreted and pathname expansion is not performed. An option value that itself contains whitespace is therefore not supported through `extra-args`.

The Orb rejects the following values in `extra-args`:

- `--show-config`
- `--show-files`
- `--interactive`

Those options make isort return before performing the normal check, which could turn a CI gating step into a step that always succeeds.

Use long option names. Short isort flags have changed meaning between major versions.

## Targets

`targets` selects the files or directories to process.

```yaml
- isort/execute:
    targets: src tests scripts
```

The parameter is whitespace-separated. Each item is passed to isort as a separate path.

Shell pathname expansion is not performed, and paths containing whitespace are not supported.

The Orb verifies every target before invoking isort. This prevents a missing path from being reported by isort while the overall command still succeeds because another valid target was processed.

An empty `targets` value fails the step.

## Gitignore

Set `skip-gitignore: true` to pass `--skip-gitignore`.

```yaml
- isort/execute:
    skip-gitignore: true
    targets: .
```

isort uses git for this behavior, so git must be available in the executor.

For other skip behavior, use the project configuration file or `extra-args`.

Example for explicitly named files:

```yaml
- isort/execute:
    extra-args: >-
      --filter-files
      --skip generated_pb2.py
    targets: src/generated_pb2.py src/app.py
```

## Saving the Report as an Artifact

Use `output-file` to capture both standard output and standard error.

```yaml
version: 2.1

orbs:
  isort: orbss/isort@0.0.2

jobs:
  execute-isort:
    executor: isort/default
    steps:
      - checkout
      - isort/install:
          version: "8.0.1"
      - isort/execute:
          diff: true
          output-file: reports/isort.txt
          targets: src tests
      - store_artifacts:
          path: reports

workflows:
  isort:
    jobs:
      - execute-isort
```

`tee` defaults to `true`, so the captured report is also printed to the CircleCI log.

```yaml
- isort/execute:
    diff: true
    output-file: reports/isort.txt
    targets: src tests
    tee: false
```

The report file is truncated before each run so an earlier report cannot remain in place.

The isort step still fails when imports are unsorted. CircleCI can upload the report with `store_artifacts` after that failed step, so the Orb does not provide an `exit-zero` parameter.

## Using an Existing Executor

The commands can be used with an existing executor.

```yaml
version: 2.1

orbs:
  isort: orbss/isort@0.0.2

jobs:
  execute-isort:
    docker:
      - image: cimg/python:3.13
    steps:
      - checkout
      - isort/install:
          version: "8.0.1"
      - isort/execute:
          diff: true
          targets: src tests
```

`isort/install` invokes pip through `python -m pip`, so the package is installed into the Python environment associated with the executor's `python` command.

Pinning the isort version is recommended because a new isort release can change formatting behavior without any change to the repository being checked.

## Installing Extras and Additional Packages

`isort/install` can install pip extras and additional packages alongside isort.

```yaml
- isort/install:
    extras: colors
    packages: packaging
    version: "8.0.1"
```

The `packages` value is whitespace-separated. Each value is passed to pip as a separate requirement.

## Commands

### `isort/install`

| Parameter  | Type   | Default | Description                                                  |
| ---------- | ------ | ------- | ------------------------------------------------------------ |
| `extras`   | string | `""`    | Comma-separated pip extras to install with isort             |
| `packages` | string | `""`    | Whitespace-separated additional pip package requirements     |
| `version`  | string | `""`    | isort version to install; empty installs the latest release  |

### `isort/execute`

| Parameter       | Type    | Default | Description                                                      |
| --------------- | ------- | ------- | ---------------------------------------------------------------- |
| `atomic`        | boolean | `false` | Pass `--atomic`                                                   |
| `check-only`    | boolean | `true`  | Report changes instead of rewriting files                        |
| `diff`          | boolean | `false` | Print a unified diff                                              |
| `extra-args`    | string  | `""`    | Additional whitespace-separated isort CLI arguments              |
| `output-file`   | string  | `""`    | Capture stdout and stderr to this file                            |
| `profile`       | string  | `""`    | Base configuration profile such as `black`                       |
| `settings-path` | string  | `""`    | Configuration file or configuration discovery root               |
| `skip-gitignore`| boolean | `false` | Skip files listed in `.gitignore`                                |
| `targets`       | string  | `.`     | Whitespace-separated source files or directories                 |
| `tee`           | boolean | `true`  | With `output-file`, also print the report to the CircleCI log    |

## Executor

### `isort/default`

The default executor uses a CircleCI Python convenience image. isort is not preinstalled, so run `isort/install` before `isort/execute`.

| Parameter        | Type   | Default            | Description                       |
| ---------------- | ------ | ------------------ | --------------------------------- |
| `image`          | string | `cimg/python:3.14` | Docker image used by the executor |
| `resource_class` | enum   | `small`            | CircleCI resource class           |

Supported resource classes are `small`, `medium`, `medium+` and `large`.

```yaml
executor:
  name: isort/default
  image: cimg/python:3.13
  resource_class: medium
```

Parallel processing can be requested through `extra-args`:

```yaml
- isort/execute:
    extra-args: --jobs 2
    targets: src tests
```

## Changelog

Release history and notable changes are recorded in [CHANGELOG.md](https://github.com/circleci-orbs-mamono210/isort/blob/main/CHANGELOG.md).

## Development

The Orb source is stored under `src/` in unpacked Orb format.

The CircleCI pipeline performs:

- Orb linting
- Orb packing
- Orb review
- ShellCheck
- Integration tests
- Production publishing from Semantic Versioning tags

Production releases use Semantic Versioning tags:

```console
v0.0.2
```

The `v0.0.2` tag publishes Orb version `0.0.2`.

Versions below 1.0.0 do not promise a stable public API. Once 1.0.0 is released, backward-compatible fixes will be patch releases, backward-compatible features minor releases, and incompatible API changes major releases.

## License

This project is released under the [MIT License](https://github.com/circleci-orbs-mamono210/isort/blob/main/LICENSE).
