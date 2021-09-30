#!/bin/sh

# Exit on error
set -e

IMG_DIR="${1%%/}"
ROCKET_FRAME_OFFSET="$2"

print_usage() {
  echo "Usage: $0 <TIMELAPSE DIR> <ROCKET FRAME OFFSET>"
  echo
  echo "Assemble *-base.png and *-rocket.png files (one segment of each) in <TIMELAPSE_DIR> into a video file."
  exit 1
}

if [[ -z "${IMG_DIR}" ]]; then
  print_usage
fi
if [[ -z "${ROCKET_FRAME_OFFSET}" ]]; then
  print_usage
fi

BASE_FRAME_RATE=30
BASE_IMG_PATTERN="%08d-base.png"
ROCKET_FRAME_RATE=60
ROCKET_IMG_PATTERN="%08d-rocket.png"

ffmpeg \
  -f image2 -framerate "${BASE_FRAME_RATE}" -i "${IMG_DIR}/${BASE_IMG_PATTERN}" \
  -f image2 -framerate "${ROCKET_FRAME_RATE}" -start_number "${ROCKET_FRAME_OFFSET}" -i "${IMG_DIR}/${ROCKET_IMG_PATTERN}" \
  -filter_complex "[0:v] [1:v] concat=n=2 [out]" \
  -map '[out]' -c:v libx265 "${IMG_DIR}/timelapse-rocket.mkv"
