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
ROCKET_FRAME_OFFSET=$(basename $(find "${IMG_DIR}" -type f -name "${ROCKET_IMG_GLOB}" | head -n 1) | cut -d '-' -f 1)

print_usage() {
  echo "Usage: $0 <TIMELAPSE DIR> [OUTPUT_DIR]"
  echo
  echo "Assemble *-base.png and *-rocket.png files (one segment of each) in <TIMELAPSE_DIR> into a video file."
  echo
  echo "OUTPUT_DIR defaults to the current directory."
  exit 1
}

if [[ -z "${IMG_DIR}" ]]; then
  print_usage
fi
if [[ -z "${ROCKET_FRAME_OFFSET}" ]]; then
  echo "Failed to compute index of first rocket frame."
  exit 1
fi

ffmpeg \
  -f image2 -framerate "${BASE_FRAME_RATE}" -i "${IMG_DIR}/${BASE_IMG_PATTERN}" \
  -f image2 -framerate "${ROCKET_FRAME_RATE}" -start_number "${ROCKET_FRAME_OFFSET}" -i "${IMG_DIR}/${ROCKET_IMG_PATTERN}" \
  -filter_complex "[0:v] [1:v] concat=n=2 [out]" \
  -map '[out]' -c:v libx265 "${OUTPUT_DIR}/timelapse-rocket.mkv"
