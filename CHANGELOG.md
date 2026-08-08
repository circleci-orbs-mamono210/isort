# Changelog

All notable changes to this project will be documented in this file.

The format is based on [Keep a Changelog](https://keepachangelog.com/en/1.1.0/),
and this project adheres to [Semantic Versioning](https://semver.org/spec/v2.0.0.html).

## [Unreleased]

## [0.0.2] - 2026-08-09

### Changed

* Reduced the public parameters of `isort/execute` to the CI-oriented set: `atomic`, `check-only`, `diff`, `extra-args`, `output-file`, `profile`, `settings-path`, `skip-gitignore`, `targets` and `tee`.
* Moved less common isort CLI options such as formatting, skip, module-classification and parallel-execution controls to `extra-args` or project configuration files.
* Simplified `src/scripts/execute.sh` by removing argument-building logic for the deleted Orb parameters.
* Simplified integration-test defaults so direct script tests only provide the remaining `PARAM_*` values.
* Updated the profile example to demonstrate passing less common isort options through `extra-args`.
* Updated the report example to pin isort without installing unused color support.
* Updated README documentation and examples for the reduced public API.

### Added

* Added integration coverage for `settings-path` and `skip-gitignore` using the reduced public API.
* Added integration coverage for the `packages` parameter of `isort/install`.
* Added integration coverage showing that removed options such as `--filter-files`, `--skip`, `--color` and `--jobs` remain usable through `extra-args`.

### Preserved

* `check-only` continues to default to `true` so CI does not silently rewrite the checkout.
* Missing and empty targets continue to fail before isort is executed.
* `--show-config`, `--show-files` and `--interactive` continue to be rejected through `extra-args` so a CI gating step cannot silently become a no-op.
* `output-file` continues to capture both standard output and standard error, and `tee` continues to control whether the report is also written to the CircleCI log.

## [0.0.1] - 2026-08-08

Initial release of the isort CircleCI Orb.

### Added

* Added the `isort/install` command for installing isort with `python -m pip`.
* Added the `isort/execute` command for running isort against Python source files.
* Added the configurable `isort/default` Python executor.
* Added `extras` support so isort can be installed with pip extras such as `colors`.
* Added `packages` support for installing additional pip packages alongside isort.
* Added `check-only`, which defaults to true so a CI job reports unsorted imports instead of rewriting the checkout.
* Added `diff` for printing the change isort would have made.
* Added `atomic` for refusing output that no longer parses as Python.
* Added `profile` support, including the `black` profile, together with the wrapping parameters that override it.
* Added configuration file controls with `settings-path`, `config-root` and `resolve-all-configs`.
* Added skip controls with `skipped-paths`, `extend-skipped-paths`, `skipped-globs`, `extend-skipped-globs`, `skip-gitignore` and `filter-files`.
* Added module classification controls with `src-paths`, `known-first-party`, `known-third-party`, `known-local-folder` and `python-version`.
* Added formatting controls with `line-length`, `multi-line`, `force-single-line-imports`, `force-sort-within-sections`, `float-to-top`, `trailing-comma`, `use-parentheses` and `order-by-type`.
* Added reporting controls with `color`, `quiet` and `verbose`.
* Added `supported-extensions` and `follow-links` for controlling the recursive search.
* Added a configurable file count with `jobs`.
* Added `output-file` and `tee` support for saving the isort output as a CircleCI artifact.
* Added `extra-args` for isort command-line options that are not exposed directly by the Orb.
* Added examples for checking, installation, profiles and artifact reporting.
* Added integration tests covering commands, parameters, installation, write mode and executor resource classes.
* Added Orb linting, packing, review and ShellCheck to the development pipeline.
* Added production publishing from Semantic Versioning tags.

### Changed

* `targets`, `packages` and `extra-args` are parsed as whitespace-separated Bash arrays without pathname expansion.
* Skip values, source paths and known-module parameters are passed to isort as repeated flags, because isort accumulates repeated flags and does not split these values on commas.
* The version reporting step uses `isort --version-number`, which prints the bare version without isort's ASCII art banner.
* Documented that isort returns exit code 1 for unsorted imports and for its own failures alike, which is why the Orb offers no `exit-zero` style parameter.
* Documented that `store_artifacts` uploads a report even when the isort step has already failed.

### Fixed

* Prevented a target path that does not exist from passing silently, which isort reports as a broken path while still exiting 0 when another path was processed.
* Prevented an empty `targets` from producing a step that checks nothing.
* Prevented `--show-config`, `--show-files` and `--interactive` from being passed through `extra-args`, because each makes isort return before it checks anything and turns a gating step into one that can never fail.
* Prevented `color` from producing isort's colorama error by failing early with a message that names the `extras` parameter.
* Prevented a repeated `output-file` step from leaving an earlier report in place.
* Captured standard error as well as standard output in `output-file`, because isort prints the diff to one and the error lines to the other.

[Unreleased]: https://github.com/circleci-orbs-mamono210/isort/compare/v0.0.2...HEAD
[0.0.2]: https://github.com/circleci-orbs-mamono210/isort/compare/v0.0.1...v0.0.2
[0.0.1]: https://github.com/circleci-orbs-mamono210/isort/tree/v0.0.1
