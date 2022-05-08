#!/bin/sh

# Exit on error
set -e

BASE_FRAME_RATE=30
BASE_IMG_PATTERN="%08d-base.png"
ROCKET_FRAME_RATE=60
ROCKET_IMG_PATTERN="%08d-rocket.png"
ROCKET_IMG_GLOB="*-rocket.png"

IMG_DIR="${1%%/}"
OUTPUT_DIR="${2:-.}"
OUTPUT_DIR="${OUTPUT_DIR%%/}"

print_usage() {
  cat << EOF
Usage: $0 <INPUT_DIR> [OUTPUT_DIR]

Assemble screenshot files in <INPUT_DIR> into video files.

*-base.png files in INPUT_DIR will be assembled into OUTPUT_DIR/timelapse.mkv .
*-rocket.png files in INPUT_DIR will be assembled into OUTPUT_DIR/timelapse-rocket.mkv .
Frame rates can be configured individually for each video by modifying the script source.

OUTPUT_DIR defaults to the current directory.
EOF
  exit 1
}

if [[ -z "${IMG_DIR}" ]]; then
  print_usage
fi

ROCKET_FRAME_OFFSET=$(basename $(find "${IMG_DIR}" -type f -name "${ROCKET_IMG_GLOB}" | head -n 1) | cut -d '-' -f 1)

ffmpeg -f image2 \
       -framerate "${BASE_FRAME_RATE}" \
       -i "${IMG_DIR}/${BASE_IMG_PATTERN}" \
       -c:v libx265 "${OUTPUT_DIR}/timelapse.mkv"

if [[ -n "${ROCKET_FRAME_OFFSET}" ]]; then
  ffmpeg -f image2 \
    -framerate "${ROCKET_FRAME_RATE}" \
    -start_number "${ROCKET_FRAME_OFFSET}" \
    -i "${IMG_DIR}/${ROCKET_IMG_PATTERN}" \
    -c:v libx265 "${OUTPUT_DIR}/timelapse-rocket.mkv"
fi
