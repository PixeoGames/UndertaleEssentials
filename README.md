# Undertale Framerate Mod

> [!CAUTION]
> ## Early test version: use at your own risk
>
> This mod is in **active, early-stage development**. It includes testing and debugging features,
> and it has had very little testing in most of the game. While using it, any of these can happen:
>
> - **bugs and glitches**: scenes that look or behave wrong, missed inputs, sound problems
> - **crashes** and **soft-locks** (getting stuck with no way forward)
> - **save file loss or corruption**
>
> **Back up your saves before playing**: copy the folder `%LOCALAPPDATA%\UNDERTALE` somewhere
> safe, and back it up again before big moments in the game. The mod shares its saves with the
> normal game.
>
> If something breaks, please [open an issue](../../issues) and say where you were in the game and
> what your frame rate setting was. The mod is provided as is, with no warranty (see the
> [license](LICENSE)).

Play Undertale at 60, 120, 144 fps or more, at the game's normal speed.

## What you need

- Windows 10 or 11
- Undertale from Steam, fully updated (v1.08). Other versions aren't supported yet: the installer
  checks and stops without changing anything.

## Install

1. Download `UndertaleFramerateMod-0.1-test.zip` from [Releases](../../releases) and extract it.
2. Double-click `Install.bat`. It finds Undertale by itself; press Enter.
3. Play with the new **Undertale (Framerate Mod)** shortcut on your desktop (Steam must be running).

Starting Undertale from Steam still plays the normal game, and `Uninstall.bat` removes everything the
installer added. The mod uses your normal save file, so back up `%LOCALAPPDATA%\UNDERTALE` first.

## In game

- **F1**: the mod's settings (the game pauses while they're open): frame rate cap (30 to 360),
  Unlimited, VSync, Smooth Motion, FPS counter and controls.
- **F9**: show or hide the FPS counter.
- Extra keys: **W A S D** to move, **J / K / L** for confirm / cancel / menu. You can rebind them, and
  the normal keys still work.

## How it works

Undertale was made with GameMaker, where the game's logic and its frame rate are the same thing: it
runs 30 steps a second, and running it faster speeds the whole game up. The mod separates the two.

- **The logic still runs 30 times a second.** Movement, attacks, timers and text all advance on these
  "ticks", exactly as in the original.
- **Extra frames are drawn between ticks.** On each one, characters, bullets, your SOUL and the camera
  are placed part of the way between their last two positions, based on the real time since the last
  tick. The frame rate cap only limits how often frames are drawn, so the game keeps its normal speed
  at any cap. If your PC can't keep up, it just draws fewer in-between frames.
- **Extra frames don't change the game.** Undertale runs a lot of its logic inside its drawing code.
  During an extra frame the mod records every change that code makes and undoes it afterwards, and
  holds back sounds and other side effects, so only one draw per tick counts.
- **Undertale's files aren't shipped.** The installer checks your `data.win` and builds the modded
  `data_framerate.win` from it with a patch. Your original files stay as they were, apart from one
  setting in `options.ini` (GameMaker's "alternate sync method", which would lock the frame rate to
  your monitor's refresh rate). Uninstalling puts it back.

- **It also fixes a sound bug in the original game.** On Windows 10 (since 2020) and 11, music
  played at high pitch cuts in and out, most noticeably the rising sound just before Asriel's fight
  on the True Pacifist route. The mod asks Windows for precise timing the way most games do, which
  keeps the music stream fed. The full write-up, with recordings, is in
  [docs/timer-resolution-bug.md](docs/timer-resolution-bug.md).

More detail is in the [developer notes](mod/README.md).

## Known limits

- Some effects and text boxes drawn by special code still move in 30 fps steps.
- The picture appears about one frame later than in the original.
- Caps that aren't a multiple of 30 (like 144) run at normal speed, but the in-between frames are
  spaced a little less evenly.
- A frame rate cap keeps one CPU core busy, because GameMaker can't wait precisely on Windows and the
  mod has to check the clock instead. Unlimited, or VSync with a cap at or above your monitor's
  refresh rate, uses much less.
- Most testing so far has been in the early game. Bugs in later scenes are possible.

## Building from source

Needs Python 3, Undertale v1.08 from Steam, and the command-line build of
[UndertaleModTool](https://github.com/UnderminersTeam/UndertaleModTool) (v0.9.2.0) extracted to
`tools/utmt_cli`. Then:

```
python mod/tools/build.py --game "<Undertale folder>"
python mod/tools/package.py --game "<Undertale folder>"
```

The [developer notes](mod/README.md) cover the details.

## License and disclaimer

Undertale Framerate Mod, copyright (C) 2026 Pixeo.

The mod's code is under the [GNU General Public License v3.0](LICENSE) or any later version. In
short: you can use, change and share it, including your own versions of the mod, as long as they
keep the credit and license notices, say what you changed, and stay open source under the same
license (with their full source available). The license text is what counts; this summary isn't
part of it.

Undertale belongs to Toby Fox; this is a fan-made mod, not affiliated with him, and you need your
own copy of the game. This repository contains only the mod's own code, with no game files or
decompiled game code.
