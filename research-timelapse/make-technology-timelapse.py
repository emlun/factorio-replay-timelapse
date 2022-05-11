#!/usr/bin/env python3

import csv
import math
import os
import shutil
import subprocess
import sys


def print_usage():
    print(f"Usage: python {sys.argv[0]} <research-progress.csv>")
    print()
    print("Make research status movie files from research-progress.csv")


FRAMES_FILE = sys.argv[1]
RESEARCH_IMG_DIR = os.path.join("research-timelapse-img", "technology")
PROGRESS_IMG_DIR = os.path.join("research-timelapse-img", "progress-bar")

if len(sys.argv) < 2 or FRAMES_FILE == "":
    print_usage()


OUTPUT_BASEDIR = os.path.join("..", "output")
OUTPUT_FRAMES_DIR = os.path.join(OUTPUT_BASEDIR, "research-frames")
OUTPUT_VIDEO_FILENAME = os.path.join(OUTPUT_BASEDIR, "research-timelapse.mkv")
OUTPUT_IMG_PATTERN = '%08d-research.png'

os.makedirs(OUTPUT_BASEDIR, exist_ok=True)
os.makedirs(OUTPUT_FRAMES_DIR, exist_ok=True)

current_research = None

with open(FRAMES_FILE, 'r') as f:
    rows = csv.DictReader(f)

    for row in rows:
        print(row)

        frame_num = int(row['frame'])
        frame_filename = os.path.join(
            OUTPUT_FRAMES_DIR,
            OUTPUT_IMG_PATTERN % (frame_num),
        )

        if row['state'] == 'current':
            current_research = row['research_name']

        if current_research is not None:
            p = math.floor(float(row['research_progress'] or '1') * 1000)
            subprocess.run([
                'magick',
                os.path.join(RESEARCH_IMG_DIR, current_research + '.png'),
                '(',
                os.path.join(PROGRESS_IMG_DIR, f"progress-{p:04d}.png"),
                '-geometry', '+77+53',
                ')',
                '-composite',
                frame_filename,
            ]).check_returncode()

        else:
            shutil.copyfile(
                os.path.join(RESEARCH_IMG_DIR, 'none.png'),
                frame_filename
            )

subprocess.run([
    'ffmpeg', '-y',
    '-f', 'image2',
    '-framerate', '30',
    '-i', os.path.join(OUTPUT_FRAMES_DIR, OUTPUT_IMG_PATTERN),
    '-c:v', 'libx265',
    OUTPUT_VIDEO_FILENAME
])
