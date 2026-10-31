# Undertale Essentials (developer notes)

Plays Undertale (v1.08, Windows) at 60, 120, up to 360 frames per second (or unlimited) without
speeding the game up. Game logic still runs at the original 30 ticks per second. The extra frames
show movement part-way between ticks, so walking, the camera, your SOUL and most bullets move smoothly.

Players: see `installer/READ ME.txt` (shipped at the top of the tester package). The installer
builds `data_framerate.win` in the Undertale folder and puts an "Undertale Essentials" shortcut
on the desktop.

## Playing a local build

- After building (below), start `UNDERTALE.exe -game data_framerate.win` from the game folder. The
  original `data.win` is never changed.
- Saves are shared with the normal game (same save folder).
- **Steam:** the runner needs either Steam to launch it (launch option `-game data_framerate.win`) or
  `steam_appid.txt` (`391540`) next to `UNDERTALE.exe`. Without either, it asks Steam to relaunch the
  game and then crashes.

### Settings

**F1** opens the settings menu in game (the game pauses while it's open): frame rate cap (30 to 360),
unlimited, vsync, smooth motion, FPS counter, and the extra keys (default **W A S D** for the arrows,
**J K L** for Z X C; the original keys always work). **F9** toggles the FPS counter.

Menu settings are saved to `fl_settings.ini` in the save folder (`%LOCALAPPDATA%\UNDERTALE`).
An optional `UndertaleFramerate.ini` in the game folder is read first (same keys as the menu:
`fps`, `unlimited`, `vsync`, `interpolate`, `overlay`, `altkeys`, plus the testing keys below), so
the menu's saved settings win. `-fps N` on the command line overrides both.

If the computer can't hold the chosen frame rate, the mod draws fewer in-between frames and the game
keeps its normal speed. Below 30 fps it slows down the way the original does.

**Frame rate cap:** GameMaker's own frame limiter sleeps, and on Windows a sleep is only precise
with 1 ms timer resolution. With the timer fix below (or under Wine) it is, so the runner holds the
cap (`room_speed` = the cap): at 75, 144 and 240 it measures 75, 144 and 237 to 240 fps, using 0.2
to 0.5 of a CPU core. Without it the runner sleeps in 15.6 ms steps (a cap like 75 or 144 would come
out at 64), so it runs unlimited and the mod holds the cap at the end of each frame instead
(`__fl_limit`). GML can't sleep, so that waits by checking the clock and keeps one CPU core busy.

**Frame rate above the monitor's refresh rate:** Undertale's `options.ini` has
`AlternateSyncMethod=1`, a GameMaker option that times every frame to the monitor's refresh whatever
the vsync setting is. It caps the mod at the refresh rate (windowed and fullscreen) and makes caps
below it uneven. The installer sets it to 0 (backup in `options.ini.framerate_mod_backup`, which
uninstalling puts back). The build also clears the game's own "vsync on" flag; the mod turns vsync
on from the player's setting.

**Timer resolution (also fixes a bug in the original game):** the runner never asks Windows for
1 ms timer resolution, and since Windows 10 version 2004 (2020) other programs can't do it for it,
so every `Sleep(16)` in the runner lasts up to 31 ms. One of those paces the thread that streams
music from the `.ogg` files. When a game sound plays music at 2 to 3 times its pitch, the stream
runs dry and cuts out: the rising sound before Asriel's fight (True Pacifist) does this in the
unmodded game too (32 dropouts in 16 s in a recording, none with the fix). At startup the mod
calls `timeBeginPeriod(1)` (`__fl_timerfix`). GameMaker 1.4 calls every DLL function found by its
plain name as cdecl, which crashes on stdcall Windows functions with arguments, so it reads
`timeGetTime`'s address from UNDERTALE.exe's import table (the exe has no ASLR), finds
`timeBeginPeriod` in the same DLL's export table, and starts it on a thread with the C runtime's
`_beginthread`. It only runs on the Steam v1.08 exe (checked by its build timestamp), skips
Wine/Proton, and gives up without changing anything if something doesn't match. `timerfix=0` in
`UndertaleFramerate.ini` turns it off. Full write-up: [docs/timer-resolution-bug.md](../docs/timer-resolution-bug.md).

## How it works

The runner runs at the chosen frame rate (or as fast as it can, with Unlimited). Timing always uses
the real time between frames: the cap only limits how often frames are drawn, so the game keeps its
real speed at any cap, including ones that aren't a multiple of 30. Each frame is one of these:

- **Tick frame:** game logic runs (Step, Alarm, Collision and Keyboard events), exactly as at 30 fps.
- **In-between frame:** a check prepended to every logic event (`if (global.__fl_skip) exit;`) skips it.
  The engine's own per-step work (animation frames, built-in motion, path movement, alarm countdowns) is
  held, so it also advances only on ticks.

Undertale does a lot of game logic inside its Draw events, and Draw has to run every frame to show
anything. So each tick is drawn **for real exactly once**, on the frame just before the next tick. Every
other frame is a **throwaway** frame:

1. Instances, the camera, rotation, fades and scaling are placed part-way between the previous tick and
   the current one. Big jumps (teleports) and shakes are shown as they are, as in the original: a
   shake is a move that turns back on the previous tick's by more than 90 degrees, at least a pixel
   each way, and it shows that tick and the next two without smoothing. Shown part-way, random
   shakes would turn into a smooth sway.
2. The game's draw code runs as usual and produces the picture.
3. Everything it changed is rolled back. Before every write to a non-local variable, the build inserts a
   *barrier* that logs the old value. Side-effecting built-ins (sounds, room changes, file writes,
   instance destroy, ds_map edits, surfaces...) go through wrappers that suppress, track or log them.
   Instances created during the frame are removed afterwards.

Key presses that land on in-between frames are carried over to the next frames that run game code, so
none are lost. `room_speed` changes the game makes (slow-motion scenes) change the logic rate, not the
frame rate. While the F1 menu is open, every frame is a throwaway frame of the current tick and the
game's key-press events are blocked (`if (global.__fl_menu) exit;`).

GameMaker 1.4 can't read back the current font or text alignment, so the game's `draw_set_font` /
`draw_set_halign` / `draw_set_valign` calls go through wrappers that remember them; the mod's own
drawing (counter, hints, menu) uses its own font and restores the game's afterwards.

Tested from the intro through the start of the Ruins, including Flowey's and Toriel's scenes, a Froggit
battle (menus, ACT, FIGHT, attacks, victory, game over) and saving and loading. Across these runs the
rollback self-check found no leftover state. At a 60 fps cap the modded intro takes 75.85 s against
75.93 s for the original, and with 75 and 144 fps caps the game averages 29.98 ticks per second.

### Known limits

- Things drawn at positions that aren't an instance's x/y or the camera (some custom effects, text
  boxes while the camera moves) still move in 30 fps steps.
- The real picture of each tick appears one frame later than in the original (about 17 ms at 60 fps).
- Frame rates that aren't a multiple of 30 (e.g. 144) work, but in-between frames are less evenly spaced.
- Undertale is long. Later areas haven't been played through with the mod. The approach is generic,
  but a bug in a specific scene is possible. `validate=1` logs any state the mod failed to restore.

## Building

Needs Python 3, the original Steam v1.08 `data.win`, and UndertaleModTool's command-line build
(v0.9.2.0, from its GitHub releases) extracted to `tools/utmt_cli` next to this `mod` folder.

```
python mod/tools/build.py --game "<folder with data.win>"
python mod/tools/package.py --game "<folder with data.win>"
```

`build.py` decompiles `data.win` (cached in `work/`), transforms the code and writes
`data_framerate.win` (`--out FILE` writes elsewhere; `--test-save NAME` gives a test build its own
save folder). `package.py` makes the tester package in `dist/` and a .zip of it: `Install.bat`,
`Uninstall.bat` and `READ ME.txt` at the top, and the installer script, patch and this source in `files/`.

| Path | What |
|------|------|
| `mod/tools/build.py` | Build driver |
| `mod/tools/transform.py` | Inserts barriers and wrapper calls into the decompiled code |
| `mod/tools/funcs.py` | Which built-in functions are safe and which get wrappers |
| `mod/tools/wrappers.py` | Generates the wrapper scripts |
| `mod/tools/gmlparse.py` | Small GML parser |
| `mod/tools/make_patch.py` | Makes the binary patch (original data.win to modded) |
| `mod/tools/package.py` | Builds the tester package |
| `mod/gml/runtime.gml` | The runtime: frame scheduling, interpolation, rollback, input, settings menu |
| `mod/csx/build.csx` | UndertaleModTool script: imports code, adds the gates and controller objects |
| `mod/installer/` | Installer script, .bat wrappers and the player READ ME |
| `mod/gen/` | Generated code from the last build (contains decompiled game code: not shipped) |

### Testing aids (`UndertaleFramerate.ini` in the game folder)

- `validate=N`: on every Nth throwaway frame, snapshot every instance variable and global before the
  frame and compare after rollback. Differences go to `fl_validate.txt` in the save folder.
- `trace=obj_name`: log that object's shown and real position, animation and path state every frame
  to `fl_trace.txt`. `trace2=obj_name` with `tracevar=name` adds one variable of a second object.
- `testbattle=N`: F11 starts battle group N from the overworld (4 = Froggit).
- `perf=1`: frame timings to `fl_perf.txt` in the save folder: a line per second (frame rate,
  ticks, slowest frame, longest gap between ticks, time spent in game code and in rollback) and a
  line for every frame over 25 ms. `watch=obj_name.var` adds one variable to each line (for example
  `watch=obj_friendscene.con` for the scene step of the True Pacifist ending).
- `testsound=1`: F7 plays the rising sound from the True Pacifist ending (F7 again stops it).
- `cmdhook=1`: a test script can drive the game without the keyboard. It writes command lines to
  `fl_cmd.txt` in the save folder (read and deleted about ten times a second) and reads replies
  from `fl_cmd_out.txt`: `tap`/`hold`/`release KEY` (held keys go through a `keyboard_check`
  wrapper, since GameMaker's `keyboard_key_press` doesn't change what `keyboard_check` reports),
  `sound [NAME]`, `stop`, `gain X`, `report` (frame rate, ticks, room, timer fix status), `quit`,
  `cap N|unlimited` and `capmode runner|spin|auto` (who holds the frame rate cap), and
  `movetest glide|jitter` with `movereport` (how in-between frames show a moving test instance:
  gliding should show part-way, jittering at its real position).
