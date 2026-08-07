#!/bin/bash
set -eo pipefail

ISORT_ARGS=()
EXTRA_ARGS=()
TARGETS=()
STATUS=0

is_true() {
  case "${1,,}" in
    true | 1 | yes | on)
      return 0
      ;;
    *)
      return 1
      ;;
  esac
}

# Append one flag per whitespace separated value. isort accumulates repeated
# flags for these options and does NOT split on commas, so a value such as
# 'build,dist' would be read as a single directory name rather than two.
append_repeated() {
  local flag="$1"
  local value="$2"
  local items=()
  local item

  if [ -z "${value}" ]; then
    return 0
  fi

  read -r -a items <<< "${value}"

  for item in "${items[@]}"; do
    ISORT_ARGS+=("${flag}" "${item}")
  done
}

# Split extra-args and targets on shell whitespace without evaluating shell
# syntax or performing pathname expansion.
if [ -n "${PARAM_EXTRA_ARGS}" ]; then
  read -r -a EXTRA_ARGS <<< "${PARAM_EXTRA_ARGS}"
fi

read -r -a TARGETS <<< "${PARAM_TARGETS}"

# '--show-config', '--show-files' and '--interactive' make isort return
# before it sorts or checks anything, so a step carrying one of them exits 0
# no matter how the imports are ordered. Refuse them instead of turning a
# gating step into one that can never fail.
for arg in "${EXTRA_ARGS[@]}"; do
  case "${arg}" in
    --show-config | --show-files | --interactive)
      echo \
        "'${arg}' makes isort return before checking anything, so the step could never fail." \
        >&2
      exit 1
      ;;
  esac
done

if [ "${#TARGETS[@]}" -eq 0 ]; then
  echo "'targets' is empty, so there is nothing for isort to check." >&2
  exit 1
fi

# isort prints 'Broken N paths' for a target that does not exist, but exits 0
# regardless as long as at least one other target was processed. A typo in
# 'targets' would therefore turn into a passing job that checked less than
# intended. Verify the paths up front instead.
for target in "${TARGETS[@]}"; do
  if [ ! -e "${target}" ]; then
    echo "Target path does not exist: ${target}" >&2
    exit 1
  fi
done

# isort exits with an error when '--color' is passed without colorama, which
# is not installed by the isort package on its own.
if is_true "${PARAM_COLOR}"; then
  if ! python -c 'import colorama' > /dev/null 2>&1; then
    echo \
      "'color' needs the colorama package. Install it with 'extras: colors' on the install command." \
      >&2
    exit 1
  fi

  ISORT_ARGS+=('--color')
fi

if is_true "${PARAM_CHECK_ONLY}"; then
  ISORT_ARGS+=('--check-only')
fi

if is_true "${PARAM_DIFF}"; then
  ISORT_ARGS+=('--diff')
fi

if is_true "${PARAM_ATOMIC}"; then
  ISORT_ARGS+=('--atomic')
fi

if is_true "${PARAM_IGNORE_WHITESPACE}"; then
  ISORT_ARGS+=('--ignore-whitespace')
fi

if [ -n "${PARAM_SETTINGS_PATH}" ]; then
  ISORT_ARGS+=('--settings-path' "${PARAM_SETTINGS_PATH}")
fi

if [ -n "${PARAM_CONFIG_ROOT}" ]; then
  ISORT_ARGS+=('--config-root' "${PARAM_CONFIG_ROOT}")
fi

if is_true "${PARAM_RESOLVE_ALL_CONFIGS}"; then
  ISORT_ARGS+=('--resolve-all-configs')
fi

if [ -n "${PARAM_PROFILE}" ]; then
  ISORT_ARGS+=('--profile' "${PARAM_PROFILE}")
fi

if is_true "${PARAM_FILTER_FILES}"; then
  ISORT_ARGS+=('--filter-files')
fi

append_repeated '--skip' "${PARAM_SKIPPED_PATHS}"
append_repeated '--extend-skip' "${PARAM_EXTEND_SKIPPED_PATHS}"
append_repeated '--skip-glob' "${PARAM_SKIPPED_GLOBS}"
append_repeated '--extend-skip-glob' "${PARAM_EXTEND_SKIPPED_GLOBS}"
append_repeated '--extension' "${PARAM_SUPPORTED_EXTENSIONS}"

if is_true "${PARAM_SKIP_GITIGNORE}"; then
  ISORT_ARGS+=('--skip-gitignore')
fi

if ! is_true "${PARAM_FOLLOW_LINKS}"; then
  ISORT_ARGS+=('--dont-follow-links')
fi

append_repeated '--src-path' "${PARAM_SRC_PATHS}"
append_repeated '--project' "${PARAM_KNOWN_FIRST_PARTY}"
append_repeated '--thirdparty' "${PARAM_KNOWN_THIRD_PARTY}"
append_repeated '--known-local-folder' "${PARAM_KNOWN_LOCAL_FOLDER}"

if [ -n "${PARAM_PYTHON_VERSION}" ]; then
  ISORT_ARGS+=('--py' "${PARAM_PYTHON_VERSION}")
fi

if [ -n "${PARAM_LINE_LENGTH}" ]; then
  ISORT_ARGS+=('--line-length' "${PARAM_LINE_LENGTH}")
fi

if [ -n "${PARAM_MULTI_LINE}" ]; then
  ISORT_ARGS+=('--multi-line' "${PARAM_MULTI_LINE}")
fi

if is_true "${PARAM_FORCE_SINGLE_LINE_IMPORTS}"; then
  ISORT_ARGS+=('--force-single-line-imports')
fi

if is_true "${PARAM_FORCE_SORT_WITHIN_SECTIONS}"; then
  ISORT_ARGS+=('--force-sort-within-sections')
fi

if is_true "${PARAM_FLOAT_TO_TOP}"; then
  ISORT_ARGS+=('--float-to-top')
fi

if is_true "${PARAM_TRAILING_COMMA}"; then
  ISORT_ARGS+=('--trailing-comma')
fi

if is_true "${PARAM_USE_PARENTHESES}"; then
  ISORT_ARGS+=('--use-parentheses')
fi

if ! is_true "${PARAM_ORDER_BY_TYPE}"; then
  ISORT_ARGS+=('--dont-order-by-type')
fi

if [ -n "${PARAM_JOBS}" ]; then
  ISORT_ARGS+=('--jobs' "${PARAM_JOBS}")
fi

if is_true "${PARAM_QUIET}"; then
  ISORT_ARGS+=('--quiet')
fi

if is_true "${PARAM_VERBOSE}"; then
  ISORT_ARGS+=('--verbose')
fi

if [ "${#EXTRA_ARGS[@]}" -gt 0 ]; then
  ISORT_ARGS+=("${EXTRA_ARGS[@]}")
fi

# isort appends nothing to a report of its own, but a re-run of the same step
# would otherwise leave the previous report in place when the second run
# writes less output. Truncate it so each step produces a self contained
# artifact.
if [ -n "${PARAM_OUTPUT_FILE}" ]; then
  mkdir -p "$(dirname "${PARAM_OUTPUT_FILE}")"
  : > "${PARAM_OUTPUT_FILE}"
fi

printf 'Command:'
printf ' %q' isort "${ISORT_ARGS[@]}" "${TARGETS[@]}"
printf '\n'

set +e

if [ -n "${PARAM_OUTPUT_FILE}" ]; then
  # isort prints the diff to standard output and the 'Imports are incorrectly
  # sorted' lines to standard error, so both streams are captured. pipefail
  # keeps isort's status rather than tee's.
  if is_true "${PARAM_TEE}"; then
    isort "${ISORT_ARGS[@]}" "${TARGETS[@]}" 2>&1 | tee "${PARAM_OUTPUT_FILE}"
  else
    isort "${ISORT_ARGS[@]}" "${TARGETS[@]}" > "${PARAM_OUTPUT_FILE}" 2>&1
  fi
else
  isort "${ISORT_ARGS[@]}" "${TARGETS[@]}"
fi

STATUS=$?
set -e

exit "${STATUS}"
