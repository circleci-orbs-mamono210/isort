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

# Split extra-args and targets on shell whitespace without evaluating shell
# syntax or performing pathname expansion.
if [ -n "${PARAM_EXTRA_ARGS}" ]; then
  read -r -a EXTRA_ARGS <<< "${PARAM_EXTRA_ARGS}"
fi

read -r -a TARGETS <<< "${PARAM_TARGETS}"

# These options make isort return before it sorts or checks anything. Refuse
# them so a CI gating step cannot silently become a no-op.
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

# isort can report a broken path while still exiting 0 when another target was
# processed. Verify every target before running it.
for target in "${TARGETS[@]}"; do
  if [ ! -e "${target}" ]; then
    echo "Target path does not exist: ${target}" >&2
    exit 1
  fi
done

if is_true "${PARAM_CHECK_ONLY}"; then
  ISORT_ARGS+=('--check-only')
fi

if is_true "${PARAM_DIFF}"; then
  ISORT_ARGS+=('--diff')
fi

if is_true "${PARAM_ATOMIC}"; then
  ISORT_ARGS+=('--atomic')
fi

if [ -n "${PARAM_PROFILE}" ]; then
  ISORT_ARGS+=('--profile' "${PARAM_PROFILE}")
fi

if [ -n "${PARAM_SETTINGS_PATH}" ]; then
  ISORT_ARGS+=('--settings-path' "${PARAM_SETTINGS_PATH}")
fi

if is_true "${PARAM_SKIP_GITIGNORE}"; then
  ISORT_ARGS+=('--skip-gitignore')
fi

if [ "${#EXTRA_ARGS[@]}" -gt 0 ]; then
  ISORT_ARGS+=("${EXTRA_ARGS[@]}")
fi

if [ -n "${PARAM_OUTPUT_FILE}" ]; then
  mkdir -p "$(dirname "${PARAM_OUTPUT_FILE}")"
  : > "${PARAM_OUTPUT_FILE}"
fi

printf 'Command:'
printf ' %q' isort "${ISORT_ARGS[@]}" "${TARGETS[@]}"
printf '\n'

set +e

if [ -n "${PARAM_OUTPUT_FILE}" ]; then
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
