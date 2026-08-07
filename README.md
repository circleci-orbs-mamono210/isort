# Isort Orb

[![CircleCI Build Status](https://circleci.com/gh/circleci-orbs-mamono210/isort.svg?style=shield)](https://circleci.com/gh/circleci-orbs-mamono210/isort)
[![CircleCI Orb Version](https://badges.circleci.com/orbs/orbss/isort.svg)](https://circleci.com/orbs/registry/orb/orbss/isort)
[![GitHub License](https://img.shields.io/badge/license-MIT-lightgrey.svg)](https://github.com/circleci-orbs-mamono210/isort/blob/main/LICENSE)

A CircleCI Orb for running [isort](https://pycqa.github.io/isort/), the Python import sorting tool.

This Orb provides:

- A command for installing isort, its extras and additional packages with `python -m pip`
- A command for executing isort
- A configurable Python executor
- Check mode by default, so a job reports unsorted imports instead of rewriting the checkout
- Profile support, including `black`, and the wrapping parameters that override it
- Skip lists, skip globs and module classification controls
- Report capture to a file for storage as a build artifact
- Support for `pyproject.toml`, `.isort.cfg`, `setup.cfg`, `tox.ini` and other isort configuration files

## Orb Registry

The published Orb, parameter reference and generated examples are available in the CircleCI Orb Registry:

<https://circleci.com/developer/orbs/orb/orbss/isort>

## Quick Start

The default executor uses a CircleCI Python convenience image. isort is not preinstalled, so run `isort/install` before `isort/execute`.

```yaml
version: 2.1

orbs:
  isort: orbss/isort@0.0.1

jobs:
  execute-isort:
    executor: isort/default
    steps:
      - checkout
      - isort/install
      - isort/execute:
          diff: true

workflows:
  isort:
    jobs:
      - execute-isort
```

By default the Orb checks the current working directory recursively and the job fails when any file's imports would change. `diff: true` prints the change isort would have made, which usually makes a failure actionable without opening the file.

Before running the check, `isort/execute` prints the installed version using `isort --version-number`.

## Check Mode and Write Mode

isort rewrites files by default. This Orb passes `--check-only` instead, because a CI job that quietly reformats the checkout produces a green pipeline and no committed change.

Set `check-only: false` for a job that is meant to sort the imports, typically before committing the result or before running the tests against it:

```yaml
- isort/execute:
    check-only: false
    targets: src
```

`diff: true` prints the change instead of applying it, so it takes precedence over `check-only: false`.

`atomic: true` is worth adding in write mode. It refuses to save output that no longer parses as Python. In check mode it is what distinguishes a file with a syntax error from a file whose imports are merely out of order, since a plain run reports both the same way.

## Using an Existing Executor

The commands can be used with an existing Docker executor. Run `isort/install` when the selected image does not already provide isort.

`isort/install` invokes pip through `python -m pip`, so packages are installed into the Python environment associated with the `python` command in the executor.

```yaml
version: 2.1

orbs:
  isort: orbss/isort@0.0.1

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

workflows:
  isort:
    jobs:
      - execute-isort
```

Pinning the isort version is strongly recommended. isort decides how imports are wrapped, so a new release can change the expected output and turn a green pipeline red without any change to the repository.

## Configuration Files

isort reads `.isort.cfg`, `pyproject.toml`, `setup.cfg`, `tox.ini` and `.editorconfig` automatically, starting from the location of the file being sorted and walking upwards.

```toml
[tool.isort]
profile = "black"
line_length = 100
known_first_party = ["myproject"]
```

The Orb only passes a flag when the parameter differs from isort's own default, so settings in the configuration file are preserved unless the Orb parameter explicitly overrides them. `check-only` is the one deliberate exception, since check mode is the point of running isort in CI.

Use `settings-path` to point at a specific file, or at the directory discovery should start from:

```yaml
- isort/execute:
    settings-path: pyproject.toml
```

A `settings-path` that does not exist makes isort fail with an unhandled traceback rather than a readable message, so a typo here is loud but ugly.

For a monorepo whose packages carry their own settings, `resolve-all-configs: true` sorts each file against the closest configuration file below `config-root`.

## Profiles

`profile` selects a base configuration. The profiles isort ships with are `black`, `django`, `pycharm`, `google`, `open_stack`, `plone`, `attrs`, `hug`, `wemake` and `appnexus`.

```yaml
- isort/execute:
    diff: true
    line-length: "100"
    profile: black
```

Parameters set alongside the profile override the values it provides, so the line length above wins over the 88 that the black profile sets.

If the project is formatted with black, the profile is not optional. isort and black disagree about how to wrap a long import, and without the profile the two tools will keep undoing each other's work.

## Checking Selected Paths

Use `targets` to select files or directories.

```yaml
- isort/execute:
    targets: src tests scripts
```

`targets` is parsed as a whitespace-separated list. Each resulting item is passed to isort as a separate argument.

The Orb does not ask Bash to perform pathname expansion while parsing this parameter, and isort does not expand globs in file arguments either. Every value therefore has to be a real path. Because the parameter is whitespace-separated, paths containing whitespace are not supported.

The Orb verifies that each target exists before running isort. This is not a convenience: isort prints `Broken N paths` for a path it cannot find, but still exits 0 as long as at least one other path was processed. Without the check, a typo in `targets` would quietly reduce a job to checking less than it appears to.

Use `supported-extensions` to change which extensions are visited during a recursive search:

```yaml
- isort/execute:
    supported-extensions: py pyi
```

## Skipping Paths

isort's skip options take **whitespace-separated values that the Orb passes as repeated flags**, because isort accumulates repeated flags and does not split these values on commas. `--skip build,dist` would look for a single directory literally named `build,dist`.

`extend-skipped-paths` adds to isort's built-in skip list, which already covers `.git`, `.tox`, `.venv`, `build`, `dist`, `node_modules` and similar directories.

```yaml
- isort/execute:
    extend-skipped-paths: migrations vendor
```

`skipped-paths` replaces the built-in list entirely, so use it only when that is intended. `skipped-globs` and `extend-skipped-globs` are the glob equivalents.

One behaviour is worth knowing before relying on a skip: **skip settings do not apply to files named directly on the command line.** They only apply to files isort discovers while walking a directory. Since `targets` defaults to `.`, skips normally work as expected, but a job that lists individual files needs `filter-files: true`:

```yaml
- isort/execute:
    filter-files: true
    skipped-paths: generated_pb2.py
    targets: src/generated_pb2.py src/app.py
```

`skip-gitignore: true` additionally skips everything listed in `.gitignore`. It shells out to git, so git has to be available in the executor.

## Module Classification

isort groups imports into sections, and a module it cannot place lands in the wrong one. `src-paths` is usually the fix, since modules found under a source path are treated as first party:

```yaml
- isort/execute:
    src-paths: src
```

`known-first-party`, `known-third-party` and `known-local-folder` classify individual modules explicitly. All four parameters are whitespace-separated and passed as repeated flags.

`python-version` decides which standard library isort recognises. The default is the union of all Python 3 versions, which is the safe choice for a library. Set it when the project targets one version and a module has moved in or out of the standard library.

## Saving the Report as an Artifact

Use `output-file` to write the report to a file. The parent directory is created automatically.

```yaml
version: 2.1

orbs:
  isort: orbss/isort@0.0.1

jobs:
  execute-isort:
    executor: isort/default
    steps:
      - checkout
      - isort/install:
          extras: colors

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

Two details are worth knowing about `output-file`:

- isort has no option for writing a report to a file, so the Orb redirects the output itself. It captures **both** streams, because isort prints the diff to standard output and the `Imports are incorrectly sorted` lines to standard error. The `tee` parameter, which defaults to `true`, keeps the report in the job log as well. Set it to `false` when the log should stay quiet.
- The file is truncated first, so a repeated step produces a self-contained artifact rather than leaving an earlier report in place.

Note that the isort step above fails when it finds unsorted imports, and the artifact is still uploaded: CircleCI runs `store_artifacts` regardless of whether an earlier step failed. This Orb therefore has no `exit-zero` style parameter, and the section below explains why it could not have one that behaves safely.

## Exit Codes

isort returns the following exit codes when used by this Orb:

| Code | Meaning                                                                    |
| ---- | -------------------------------------------------------------------------- |
| 0    | Nothing would change                                                       |
| 1    | Imports would change, or isort failed                                      |

That is the whole table, and it is the reason this Orb does not offer a parameter that turns a failure into a pass. isort uses exit code 1 for unsorted imports, for a missing configuration file, for a `--color` run without colorama, and for a run where every path was broken. A parameter that ignored it would ignore all of those equally, and a job that cannot fail is worse than no job.

Where isort's own reporting is ambiguous, the Orb fails the step before isort runs instead:

- A target path that does not exist fails the step, rather than being reported as a broken path in a run that exits 0.
- An empty `targets` fails the step.
- `--show-config`, `--show-files` and `--interactive` are rejected in `extra-args`, because each makes isort return before it checks anything, so a step carrying one could never fail.
- `color: true` without colorama installed fails with a message naming the `extras` parameter.

## Colour

`color: true` passes `--color`, which the CircleCI log renders even though it is not a TTY.

isort does not bundle colorama, and it treats a missing colorama as an error rather than falling back to plain output. Install it through the extras:

```yaml
- isort/install:
    extras: colors
- isort/execute:
    color: true
    diff: true
```

## Additional Options

Options this Orb does not expose can be passed with `extra-args`:

```yaml
- isort/execute:
    extra-args: --case-sensitive --reverse-relative
```

Multiple arguments can be supplied as a whitespace-separated string. The Orb splits `extra-args` on whitespace and passes each item to isort as a separate argument.

Bash pathname expansion is not performed during this parsing. Values containing `*`, `?` or `[]` are therefore not expanded according to files in the CircleCI checkout.

`extra-args` is not evaluated as a shell command line. Shell quoting syntax inside the parameter is not reinterpreted, so an argument that needs embedded whitespace should use a dedicated Orb parameter where one is available.

Use long option names. isort's short flags have moved between major versions: `-d` means `--stdout` today, while it meant `--diff` in isort 4.

## Commands

### `isort/install`

Installs isort, its extras and any additional packages using `python -m pip`.

Using `python -m pip` ensures that packages are installed into the Python environment associated with the executor's `python` command instead of relying on whichever standalone `pip` executable appears first in `PATH`.

| Parameter  | Type   | Default | Description                                                        |
| ---------- | ------ | ------- | ------------------------------------------------------------------ |
| `extras`   | string | `""`    | Comma-separated pip extras to install with isort, such as `colors` |
| `packages` | string | `""`    | Whitespace-separated pip packages to install alongside isort       |
| `version`  | string | `""`    | isort version to install; empty installs the latest release        |

### `isort/execute`

Runs isort against the selected source files or directories.

Before the command runs, the Orb reports the installed version with `isort --version-number`.

| Parameter                    | Type    | Default | Description                                                                     |
| ---------------------------- | ------- | ------- | ------------------------------------------------------------------------------- |
| `atomic`                     | boolean | `false` | Refuse output that no longer parses as Python                                   |
| `check-only`                 | boolean | `true`  | Report files that would change instead of rewriting them                        |
| `color`                      | boolean | `false` | Colour the output; requires colorama                                            |
| `config-root`                | string  | `""`    | Directory searched for per-directory configuration files                        |
| `diff`                       | boolean | `false` | Print a unified diff of the changes isort would make                            |
| `extend-skipped-globs`       | string  | `""`    | Whitespace-separated skip globs, added to the configured list                   |
| `extend-skipped-paths`       | string  | `""`    | Whitespace-separated skip values, added to the built-in list                    |
| `extra-args`                 | string  | `""`    | Whitespace-separated additional isort arguments                                 |
| `filter-files`               | boolean | `false` | Apply the skip settings to explicitly named files as well                       |
| `float-to-top`               | boolean | `false` | Move every non-indented import to the top of the file                           |
| `follow-links`               | boolean | `true`  | Follow symlinks during a recursive search                                       |
| `force-single-line-imports`  | boolean | `false` | Put every `from` import on its own line                                         |
| `force-sort-within-sections` | boolean | `false` | Sort by module name rather than by import style within a section                |
| `ignore-whitespace`          | boolean | `false` | Ignore whitespace differences while checking                                    |
| `jobs`                       | string  | `""`    | Number of files processed in parallel                                           |
| `known-first-party`          | string  | `""`    | Whitespace-separated modules classified as first party                          |
| `known-local-folder`         | string  | `""`    | Whitespace-separated modules classified as a local folder                       |
| `known-third-party`          | string  | `""`    | Whitespace-separated modules classified as third party                          |
| `line-length`                | string  | `""`    | Maximum length of an import line before it is wrapped                           |
| `multi-line`                 | string  | `""`    | Wrapping mode, by name or by number                                             |
| `order-by-type`              | boolean | `true`  | Order imports by the case of the name                                           |
| `output-file`                | string  | `""`    | Path to write the report to                                                     |
| `profile`                    | string  | `""`    | Base configuration profile, such as `black`                                     |
| `python-version`             | string  | `""`    | Python version whose standard library isort should recognise                    |
| `quiet`                      | boolean | `false` | Print errors only                                                               |
| `resolve-all-configs`        | boolean | `false` | Sort each file against the closest configuration file                           |
| `settings-path`              | string  | `""`    | Configuration file, or the directory discovery starts from                      |
| `skip-gitignore`             | boolean | `false` | Skip the files listed in `.gitignore`; needs git                                |
| `skipped-globs`              | string  | `""`    | Whitespace-separated skip globs, replaces the configured list                   |
| `skipped-paths`              | string  | `""`    | Whitespace-separated skip values, replaces the built-in list                    |
| `src-paths`                  | string  | `""`    | Whitespace-separated source paths treated as first party                        |
| `supported-extensions`       | string  | `""`    | Whitespace-separated file extensions isort may run against                      |
| `targets`                    | string  | `.`     | Whitespace-separated files or directories; every value has to be a real path    |
| `tee`                        | boolean | `true`  | With `output-file`, also print the report to the job log                        |
| `trailing-comma`             | boolean | `false` | Add a trailing comma to wrapped imports that use parentheses                    |
| `use-parentheses`            | boolean | `false` | Continue over-long lines with parentheses instead of backslashes                |
| `verbose`                    | boolean | `false` | Print more information about what isort is doing                                |

## Executor

### `isort/default`

A configurable CircleCI Python executor for running isort.

isort is not preinstalled. Run `isort/install` before `isort/execute`.

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

isort processes files sequentially unless `jobs` is set. A negative value uses the number of processors, which can exceed the CPU quota of a `small` resource class.

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
- Production publishing from semantic version tags

The Orb slug has to exist in the registry before the first publish:

```console
circleci orb create orbss/isort --no-prompt
```

Production releases use Semantic Versioning tags:

```console
v0.0.1
```

The `v0.0.1` tag publishes Orb version `0.0.1`.

Versions below 1.0.0 do not promise a stable public API. Once 1.0.0 is released, backward-compatible fixes will be released as patch versions, backward-compatible features as minor versions, and incompatible API changes as major versions.

## License

This project is released under the [MIT License](https://github.com/circleci-orbs-mamono210/isort/blob/main/LICENSE).
