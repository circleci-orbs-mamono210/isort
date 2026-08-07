#!/bin/bash
set -eo pipefail

PACKAGES=()
EXTRA_PACKAGES=()
REQUIREMENT='isort'

# pip extras belong inside the brackets of the requirement itself, so they
# have to be applied before the version specifier is appended.
if [ -n "${PARAM_EXTRAS}" ]; then
  REQUIREMENT="isort[${PARAM_EXTRAS}]"
fi

if [ -n "${PARAM_VERSION}" ]; then
  REQUIREMENT="${REQUIREMENT}==${PARAM_VERSION}"
fi

PACKAGES+=("${REQUIREMENT}")

# Split packages on shell whitespace without evaluating shell syntax or
# performing pathname expansion. Each item becomes a separate pip
# requirement, so a package may carry its own version specifier.
if [ -n "${PARAM_PACKAGES}" ]; then
  read -r -a EXTRA_PACKAGES <<< "${PARAM_PACKAGES}"
  PACKAGES+=("${EXTRA_PACKAGES[@]}")
fi

printf 'Installing:'
printf ' %q' "${PACKAGES[@]}"
printf '\n'

python -m pip install --upgrade "${PACKAGES[@]}"
