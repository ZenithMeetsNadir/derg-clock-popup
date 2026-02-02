# Derg-clock-popup

This is a fun little spontaneous project I've originally put together in the span of two days. It is intended to be a popup window that displays the current time in a fancy whip of motion, telling the time for a brief moment.

Currently, it only has this flavor: 

- A popup window taking up about a nineth of your screen, telling the time, with a sleeping derg splayed on top of it.

![showcase video](assets/showcase//derg-clock-popup-showcase.mp4)

I highly suggest you configure your wm and compositor to leave this window out of any open/close animations, shadows, blur etc. Those effects unfortunatelly get in the way of the promised clean look, which the popup window manages on its own.

## Installation

### Windows

[Grab the latest release (.zip portable version)](https://github.com/ZenithMeetsNadir/derg-clock-popup/releases) or [build from source](#build-from-source) (this one is quite tedious on Windows)

### Linux

Let's [build from source](#build-from-source), my friend

## Build from source

Tool prequisities: `zig`.

### Dependencies

#### SDL3

The best way to get started is to install SDL3 libraries system-wide, namely `SDL3`, `SDL3_ttf`, `SDL3_image`. Arch example

    sudo pacman -S sdl3 sdl3_ttf sdl3_image

In scenarios where the libraries aren't accessible via lookup in `PATH` directories, you can point the `-Dsdls_lib_path` build option to the directory containing the SDL libraries, as well as point the `-Dsdls_include_path` build option to the parent directory of the SDL include directories.

The same goes for Windows, where package managers aren't very popular. You can either add the SDL libraries directory to `PATH` to be picked up by the linker automatically or point the respective build options to the corresponding directories as described above. 

### Install prefix

On Linux, the preferred directory to install from source is to `/usr/local` for system-wide and to `$HOME/.local` for a single user. You can use the `--prefix` (`-p`) build option to specify where to install the program (the executable itself will end up at `{prefix}/bin/`).

The corresponding windows prefixes are `"C:\Program Files\derg-clock-popup"` and `%LOCALAPPDATA%\derg-clock-popup`

Replace `{}` with your specific values. `[]` is optional.

    zig build --release=safe --prefix {your_prefix} [-Dsdls_lib_path={your_sdls_lib_path}] [-Dsdls_include_path={your_sdls_include_path}]

However, most of the time, the snippet below suffices.

    zig build --release=safe --prefix /usr/local






    