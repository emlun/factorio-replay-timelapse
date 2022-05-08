#!/bin/sh

# Exit on error
set -e

FRAME_RATE=30
IMG_PATTERN="%08d-base.png"

IMG_DIR="${1%%/}"
OUTPUT_DIR="${2:-.}"
OUTPUT_DIR="${OUTPUT_DIR%%/}"

print_usage() {
  echo "Usage: $0 <TIMELAPSE DIR> [OUTPUT_DIR]"
  echo
  echo "Assemble *-base.png files in <TIMELAPSE_DIR> into a video file."
  echo
  echo "OUTPUT_DIR defaults to the current directory."
  exit 1
}

if [[ -z "${IMG_DIR}" ]]; then
  print_usage
fi

ffmpeg -f image2 -framerate "${FRAME_RATE}" -i "${IMG_DIR}/${IMG_PATTERN}" -c:v libx265 "${OUTPUT_DIR}/timelapse.mkv"
