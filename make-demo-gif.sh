#!/bin/sh

# Exit on error
set -e

IMG_DIR="${1:-${HOME}/.factorio/script-output/replay-timelapse}"
IMG_DIR="${IMG_DIR%%/}"

print_usage() {
  echo "Usage: $0 [TIMELAPSE DIR]"
  echo
  echo "Assemble *-base.png files in <TIMELAPSE_DIR> into a demo gif."
  echo "(This is hard-coded for a particular save file, but can be used as a template)"
  exit 1
}

if [[ -z "${IMG_DIR}" ]]; then
  print_usage
fi

FRAME_RATE=30
IMG_PATTERN="%08d-base.png"

ffmpeg \
  -f image2 -framerate "${FRAME_RATE}" -ss "00:00" -t "00:05" -i "${IMG_DIR}/${IMG_PATTERN}" \
  -f image2 -framerate "${FRAME_RATE}" -ss "01:02" -t "00:11" -i "${IMG_DIR}/${IMG_PATTERN}" \
  -f image2 -framerate "${FRAME_RATE}" -ss "02:30" -t "00:10" -i "${IMG_DIR}/${IMG_PATTERN}" \
  -filter_complex "
  [0:v] fade=in:0:05 [fade11]; [fade11] fade=out:145:05 [fade1];
  [1:v] fade=in:0:05 [fade21]; [fade21] fade=out:325:05 [fade2];
  [2:v] fade=in:0:05 [fade31]; [fade31] fade=out:295:05 [fade3];
  [fade1] [fade2] [fade3] concat=n=3 [fin]" \
  -map '[fin]' -c:v gif -r 15 -s 960x540 "demo.gif"
