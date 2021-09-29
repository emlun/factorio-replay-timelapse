#!/bin/sh

# Exit on error
set -e

IMG_DIR="${1%%/}"

print_usage() {
  echo "Usage: $0 <TIMELAPSE DIR>"
  echo
  echo "Assemble *-base.png files in <TIMELAPSE_DIR> into a video file."
  exit 1
}

if [[ -z "${IMG_DIR}" ]]; then
  print_usage
fi

FRAME_RATE=30
IMG_PATTERN="%08d-base.png"

ffmpeg -f image2 -framerate "${FRAME_RATE}" -i "${IMG_DIR}/${IMG_PATTERN}" -c:v libx265 "${IMG_DIR}/timelapse.mkv"
