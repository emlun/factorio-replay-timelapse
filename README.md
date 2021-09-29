# Factorio replay timelapse recorder

This script can be attached to an existing replay save file to generate a timelapse by running the replay.
This does not register as installing a mod, and so does not invalidate the replay.


## Usage

To use this tool:

 1. Unpack your save file into a new directory.
    The save file already includes a prefix directory,
    so for example `MyBeautifulBase.zip` will by default unpack into a new `MyBeautifulBase/` directory.

 2. Take the [`control.lua`](./control.lua) file from this directory
    and append its contents to the `control.lua` file in the extracted save directory,
    for example `MyBeautifulBase/control.lua`.

 3. Copy the [`replay-timelapse.lua`](./replay-timelapse.lua) file into the extracted save directory.
    For example, copy it to `MyBeautifulBase/replay-timelapse.lua`.

 4. (Optional) At the top of `MyBeautifulBase/replay-timelapse.lua`,
    tweak the output paths and/or user parameters as needed.
    See the comments in the file for descriptions.

    The default settings generate screenshots at 1080p, 30 FPS and x300 speedup
    (5 in-game minutes per second of timelapse),
    saving them into `.script-output/replay-timelapse/` in the [Factorio application directory][appdir].

 5. Launch the game, load the extracted directory - for example, `MyBeautifulBase/` - as a save file,
    and run the replay to completion.
    You may play it at any speed.

On Unix-like systems, the script [`install.sh`](./install.sh) can be used to perform the first three steps.

NOTE: Make sure to prepare plenty of disk space for the screenshots.
With the default settings (1080p @ 30 FPS, x300 speed),
screenshots consume about 9 GiB per timelapse minute or about 2 GiB per in-game hour.

Once finished, you can use [FFmpeg][ffmpeg] with the `image2` demuxer to assemble the screenshots into a video file.
See the [`assemble-timelapse-video.sh`](./assemble-timelapse-video.sh) script for an example.


## Capturing research status

If the parameter `capture_gui` is set to `true`, then screenshots including GUI will also be captured.
The intended use of this is to also capture research status, but it is disabled by default
since it will consume unnecessarily much storage space without special attention.

The GUI screenshots capture whatever is visible in the game window,
so a simple way to reduce their size is to put the game into windowed mode
and make the window small enough to only fit the research status (for example).


## Camera movement strategy

Initially, the camera movement strategy is rather simple:
keep all buildings on screen and zoom out as necessary.
The camera keeps track of the largest bounding box the base has occupied so far,
and pans and zooms out to keep that whole bounding box on screen.
If the base shrinks to be significantly smaller than the bounding box,
then after a short delay the relevant dimension of the bounding box is reset
and the camera smoothly zooms back in to make the best use of screen space.

However, the camera cannot zoom out forever.
Things get too small to see, and the game doesn't allow zooming out too far either.
So when the whole base no longer fits on screen, the movement strategy changes.
Now the camera will instead try to cover everything built by the player
(but not by robots) in the last 2 timelapse seconds - both actual entities and entity ghosts.
This seems to strike a reasonable balance between keeping things big enough to see,
not moving the camera too much, and covering the most relevant area at any given time.


## Credits

This was heavily inspired by [this gist by Bilka][bilka] and the mod [Time Lapse Base Edition][tlbe].


## License

GNU General Public License, version 3 or later.


[appdir]: https://wiki.factorio.com/Application_directory
[bilka]: https://gist.github.com/Bilka2/579ec217ec38e055328e4a23f2fd71a3
[ffmpeg]: https://www.ffmpeg.org/
[tlbe]: https://github.com/veger/TLBE
