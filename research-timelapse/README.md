# Research timelapse recorder

Generate research progress images, and then compile them into a timelapse video.

NOTE: This is currently hard-coded for Factorio running in 3840x2160 (4k) resolution,
and will probably not work correctly for other resolutions.

NOTE: The research timelapse does NOT take into account the increased frame rate
while the replay recorder is zoomed in on a rocket silo.


## Dependencies

- [FFmpeg][ffmpeg]
- [ImageMagick][magick]
- [Python 3][python]


## Setup

These steps only need to be performed once, unless you install mods that add or modify technologies.

 1. Copy (or symlink) the [`scenario`](./scenario) directory into your Factorio scenarios folder:

    ```
    $ cp -a scenario ~/.factorio/scenarios/research-timelapse-resource-gen
    $ # OR
    $ ln -s $(pwd)/scenario ~/.factorio/scenarios/research-timelapse-resource-gen
    ```

 2. Start Factorio and start a new game of the `research-timelapse-resource-gen` scenario.
    The scenario will run for about 2 minutes and then automatically finish.
    The last screenshot (`progress-1000.png`) doesn't always reliably capture a frame
    without the orange highlight, so you might need to run it multiple times until you get one.

 3. Run the [`crop-technology-screenshots.sh`](./crop-technology-screenshots.sh) script:

    ```
    $ ./crop-technology-screenshots.sh
    ```

    You will now have a `research-timelapse-img/` directory containing components for the research timelapse.

## Usage

 1. Run the [`make-technology-timelapse.py`](./make-technology-timelapse.py) script:

    ```
    $ python make-technology-timelapse.py ~/.factorio/script-output/replay-timelapse/research-progress.csv
    ```

    This will write timelapse frames to `../output/research-frames/*.png` and then compile them
    into a video written to `../output/research-timelapse.mkv`.


[ffmpeg]: https://www.ffmpeg.org/
[magick]: https://imagemagick.org/
[python]: https://www.python.org/
