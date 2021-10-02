#!/bin/sh

# Exit on error
set -e

IMG_DIR="${1:-${HOME}/.factorio/script-output/research-timelapse}"
IMG_DIR="${IMG_DIR%%/}"

OUTPUT_DIR="research-timelapse-img"
mkdir -p "${OUTPUT_DIR}/technology"
mkdir -p "${OUTPUT_DIR}/progress-bar"

crop_technologies() {
  for f in "${IMG_DIR}/technology"/*.png; do
    fn=$(basename "$f")
    output_file="${OUTPUT_DIR}/technology/${fn%.png}.png"
    echo "$output_file"
    magick "$f" -crop 480x84+3344+16 "${output_file}"
  done
}

crop_progress() {
  for f in "${IMG_DIR}/progress-bar"/progress-???.png; do
    fn=$(basename "$f")
    output_file="${OUTPUT_DIR}/progress-bar/${fn%.png}.png"
    echo "$output_file"
    magick "$f" -crop 388x23+3421+69 "${output_file}"
  done
}

make_none_technology() {
  f="${IMG_DIR}/progress-bar/progress-000.png"
  fn=$(basename "$f")
  output_file="${OUTPUT_DIR}/technology/none.png"
  echo "$output_file"
  magick \( "$f" -crop 480x84+3344+16 \) \
         -fill '#313031' \
         -draw 'rectangle 7,7,76,77' \
         -draw 'rectangle 76,7,473,52' \
         "${output_file}"
}

crop_technologies
crop_progress
make_none_technology
