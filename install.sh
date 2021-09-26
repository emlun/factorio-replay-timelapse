#!/bin/sh

# Exit on error
set -e

SAVE_FILE="${1}"

print_usage() {
  echo "Usage: $0 <SAVE.ZIP>"
  echo
  echo "Extract <SAVE.ZIP> into a new directory and install replay-timelapse in the extracted save."
  exit 1
}

if [[ -z "${SAVE_FILE}" ]]; then
  print_usage
fi


SAVE_NAME=$(basename "${1%.zip}")
SAVE_DIR=$(dirname "${SAVE_FILE}")
EXTRACT_DIRNAME="replay-timelapse"
EXTRACT_DIR="${SAVE_DIR}/${EXTRACT_DIRNAME}"
SAVE_EXTRACT_DIR="${EXTRACT_DIR}/${SAVE_NAME}"
SRC_DIR=$(dirname "$0")


mkdir -p "${EXTRACT_DIR}"
unzip -q -u -d "${EXTRACT_DIR}" "${SAVE_FILE}"
cp "${SRC_DIR}/replay-timelapse.lua" "${SAVE_EXTRACT_DIR}/"
if ! grep -q 'replay-timelapse' "${SAVE_EXTRACT_DIR}/control.lua"; then
  cat "${SRC_DIR}/control.lua" >> "${SAVE_EXTRACT_DIR}/control.lua"
fi

echo "replay-timelapse successfully installed in: ${SAVE_EXTRACT_DIR}"
