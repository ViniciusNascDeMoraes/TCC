# AGENTS.md

## Project Shape

- The repo holds two independent versions of the same 2D game ("Vacina"), one per folder:
  - `java/`: the original Java AWT/Swing game. Entry point `Main.Game.main(String[])`; `Main.Game` owns the window, loop, rendering, input, and global game state.
  - `zig/`: a faithful port to pure Zig 0.16 with no dependencies (own X11/Win32 window, PulseAudio/waveOut audio, PNG/WAV/font decoders and software rendering). Entry point `zig/src/main.zig`; `zig/src/game.zig` mirrors `Main.Game`.
- Keep gameplay identical between the two. When changing rules, timings, texts, or maps in one, port the change to the other.
- Both versions are in Portuguese and English. Every on-screen text is a `{ português, english }` pair next to where it is drawn (Java: `String[]` indexed by `Game.idioma`; Zig: `Tr` picked by `Game.tr` with `Game.lang`); add or change both languages together. The main menu option "Idioma: Português" / "Language: English" toggles the language; the game always starts in Portuguese.
- Screens with text drawn in the image have an English copy named `<Name>_en.png` in both `java/res/` and `zig/res/` (`GameOver.png` is shared). They were made by erasing the Portuguese lines with the background color (9, 156, 147) and drawing the English in URW Bookman Light with a 0.5 px stroke (close to Bookman Old Style Regular), at the same size, baseline and center.
- No Maven, Gradle, wrapper scripts, CI workflows, lint, or codegen config exist. The Zig project has unit tests for its pure logic.
- Java IntelliJ metadata: `.idea/` stays at the repo root and points to `java/TCC.iml`, which marks `java/src/` and `java/res/` as source roots, outputs to `java/bin/`, and targets JDK 25.
- Do not assume Eclipse files exist; there is no `.classpath` or `.project` in the current repo.

## Java: Build And Run

- Work from `java/`: `cd java`.
- Compile when a JDK is on `PATH`: `javac -cp "src;res" -d bin src\Main\Game.java` (on Linux/macOS use `:` instead of `;` and `/` instead of `\`: `javac -cp "src:res" -d bin src/Main/Game.java`).
- Run: `java -cp "bin;res" Main.Game`.
- Java sources are UTF-8 (`javac`'s default since JDK 18). Keep them UTF-8: the Portuguese accents were lost once when Latin-1 files were reformatted as UTF-8.
- The `java/` working directory matters because images/levels use classpath resources like `/Spritesheet.png`, while audio uses filesystem paths like `res/Menu.wav`.
- `java/bin/` and `java/doc/` are generated artifacts ignored by `.gitignore`; avoid hand-editing them and regenerate outputs intentionally when needed.

## Zig: Build And Run

- Requires Zig 0.16.x (`minimum_zig_version` in `zig/build.zig.zon`). The code uses the Zig 0.16 `std.Io` APIs (`std.process.Init`, `std.Io.Dir`, `std.Io.Timestamp`); Zig 0.17 is untested.
- Work from `zig/`: `zig build run`, `zig build test` (pure logic tests, no window or audio device), `zig build -Doptimize=ReleaseFast`. Nothing is downloaded: `build.zig.zon` has no dependencies.
- Cross-compile for Windows from any OS: `zig build -Dtarget=x86_64-windows`. Optimized Windows builds use the GUI subsystem (no console window); Debug builds keep the console for the FPS log. With Wine installed, `zig build test -Dtarget=x86_64-windows -fwine` runs the tests for the Windows target.
- Supported OSes: Linux and Windows only (macOS was supported while the port used raylib). On other OSes the game does not compile, but `zig build test` still builds the pure tests.
- Linux builds are static executables with no libraries: the game talks to the X server (or XWayland) over its Unix socket (`DISPLAY`, cookie from `XAUTHORITY`/`~/.Xauthority`; needs a 24-bit TrueColor screen; frames go through PutImage, no MIT-SHM) and to PulseAudio or `pipewire-pulse` over its native socket. No `-dev` packages are needed.
- Linux audio limits: no direct ALSA fallback (ALSA-only systems are silent), and `PULSE_SERVER` accepts only Unix sockets (TCP entries are warned about and skipped). The audio thread retries the connection every 2 s, so sound comes back after the server restarts.
- Windows builds call only system DLLs (`kernel32`, `user32`, `gdi32`, `winmm`), declared with `extern` in `platform/win32.zig` and `audio/winmm.zig`.
- Headless check on Linux: `xvfb-run -a -s "-screen 0 1280x1024x24" zig build run`.
- Assets are embedded into the executable through `zig/res/assets.zig` (`@embedFile`), so the binary runs from any directory. `zig/res/` holds copies of only the assets the game uses.
- `zig/.zig-cache/`, `zig/zig-out/`, and `zig/zig-pkg/` (Zig 0.16 package cache) are ignored by `.gitignore`.
- Module map:
  - Game (mirrors the Java classes): `game.zig` (Game), `menu.zig` (Menu), `world.zig` (World/restartGame), `entities.zig` (Player, Enemy/Enemy02/Enemy03 as one `Enemy` with a `kind`), `rules.zig` (Tile classes, map colors, `place_free`, `Rectangle.intersects`), `camera.zig`, `sound.zig`, `spritesheet.zig`, `text.zig` (fonts), `gfx.zig` (colors/images).
  - Drawing and assets: `canvas.zig` (software framebuffer, `Color` is 0xAARRGGBB), `png.zig`, `wav.zig`, `mixer.zig`, `ttf.zig` + `cff.zig` (TrueType/CFF outlines), `raster.zig` (antialiased glyph rasterizer), `glyphs.zig` (glyph cache and Java-like text layout), `bitmap_font.zig` (embedded font8x8 fallback).
  - OS layer: `platform.zig` (`Window`, `Key`, `KeyQueue`) with `platform/x11.zig` + `platform/x11_proto.zig` (Linux) and `platform/win32.zig` (Windows); `audio.zig` with `audio/pulse.zig` + `audio/pulse_proto.zig` (Linux) and `audio/winmm.zig` (Windows); `linux_sys.zig` (raw socket syscalls).
- `src/tests.zig` is the single test root (`zig build test`); add new pure modules there. It also compiles (but never runs) the window and audio backends of the target OS.
- Keep OS calls (`platform/x11.zig`, `platform/win32.zig`, `audio/*.zig` backends, `linux_sys.zig`) out of the pure modules (`rules`, `camera`, `canvas`, `png`, `wav`, `mixer`, `raster`, `ttf`, `cff`, `glyphs`, `bitmap_font`, `*_proto`) so `zig build test` runs without a window or audio device.
- Text uses "Bookman Old Style" Bold (`BOOKOSB.TTF`, not redistributable) when present in `%WINDIR%\Fonts`, `%LOCALAPPDATA%\Microsoft\Windows\Fonts`, `$XDG_DATA_HOME/fonts` (or `~/.local/share/fonts`) or `~/.fonts`, then the free URW Bookman Demi clone (Linux, `fonts-urw-base35`), then Arial/DejaVu Sans/Liberation Sans Bold (Java's "Dialog" fallback), then the embedded public-domain font8x8. A font with an unsupported feature (e.g. CFF `seac`, TrueType point-matched composites) is skipped as a whole.

## Gameplay Data

- Both versions load `level1.png`, `level2.png`, and `level3.png` as pixel maps; exact ARGB colors create tiles, player starts, and enemy spawns.
- The level PNGs exist twice (`java/res/` and `zig/res/`). Editing a map changes gameplay layout, collision, and spawn points; update both copies.
- New map colors must be added in `java/src/World/World.java` and in `rules.classifyPixel` in `zig/src/rules.zig`.
- `Game.LEVEL` (Zig: `Game.level`) selects the level-specific map rules and player sprites; `World.restartGame` rebuilds the entity lists and reloads the level map.

## Manual Verification

- There are no automated gameplay tests; verify by launching either game and exercising it manually (on Linux, `xdotool` can drive the Zig game under Xvfb).
- Controls: `W`/`S` navigate menus, `Enter` selects (on the language option it toggles Portuguese/English), `Esc` pauses/unpauses or returns from credits, `Enter`/`Esc` on the end screen returns to the main menu, and in-game movement is `WASD`.
- Under Xvfb without a window manager, do not move the focus of the Java window with `xdotool windowfocus`: AWT receives keys through its own focus proxy window, which already has the focus. The Zig window needs `windowfocus`.

## Git Workflow

- If the user says `enter in the git workflow`, review the diff line by line, group changes by logical feature, and plan atomic commits (one logical change, max about 200 lines, independently reversible).
- Commit format: `<gitmoji> <scope>: <message>` or `<gitmoji> <message>`.
- Keep subjects under 60 characters and in imperative mood.
- Emoji priority: 💥 breaking, ✨ feature, 🐛 fix, ♻️ refactor.
