#!/bin/bash
set -eo pipefail

# '--version' prints an ASCII art banner around the number, which is noise in
# a job log. '--version-number' prints the bare version instead.
isort --version-number
