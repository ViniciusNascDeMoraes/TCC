# AGENTS.md

## Project Shape

- The repo holds two independent versions of the same 2D game ("Vacina"), one per folder:
  - `java/`: the original Java AWT/Swing game. Entry point `Main.Game.main(String[])`; `Main.Game` owns the window, loop, rendering, input, and global game state.
  - `odin/`: a faithful port to Odin using the raylib bundled with the compiler (`vendor:raylib`) for window, input, audio, PNG decoding and glyph rasterization. Entry point `odin/vacina/main.odin`; `odin/vacina/game.odin` mirrors `Main.Game`.
- Keep gameplay identical between the two. When changing rules, timings, texts, or maps in one, port the change to the other.
- Both versions are in Portuguese and English. Every on-screen text is a `{ português, english }` pair next to where it is drawn (Java: `String[]` indexed by `Game.idioma`; Odin: `Tr` (`[2]string`) picked by `tr(g, ...)` with `g.lang`); add or change both languages together. The main menu option "Idioma: Português" / "Language: English" toggles the language; the game always starts in Portuguese.
- Screens with text drawn in the image have an English copy named `<Name>_en.png` in `java/res/` and `odin/res/` (`GameOver.png` is shared). They were made by erasing the Portuguese lines with the background color (9, 156, 147) and drawing the English in URW Bookman Light with a 0.5 px stroke (close to Bookman Old Style Regular), at the same size, baseline and center.
- No Maven, Gradle, wrapper scripts, CI workflows, lint, or codegen config exist. The Odin project has unit tests for its pure logic.
- Java IntelliJ metadata: `.idea/` stays at the repo root and points to `java/TCC.iml`, which marks `java/src/` and `java/res/` as source roots, outputs to `java/bin/`, and targets JDK 27.
- Do not assume Eclipse files exist; there is no `.classpath` or `.project` in the current repo.

## Java: Build And Run

- Work from `java/`: `cd java`.
- Compile when a JDK is on `PATH`: `javac -cp "src;res" -d bin src\Main\Game.java` (on Linux/macOS use `:` instead of `;` and `/` instead of `\`: `javac -cp "src:res" -d bin src/Main/Game.java`).
- Run: `java -cp "bin;res" Main.Game`.
- Java sources are UTF-8 (`javac`'s default since JDK 18). Keep them UTF-8: the Portuguese accents were lost once when Latin-1 files were reformatted as UTF-8.
- The `java/` working directory matters because images/levels use classpath resources like `/Spritesheet.png`, while audio uses filesystem paths like `res/Menu.wav`.
- `java/bin/` and `java/doc/` are generated artifacts ignored by `.gitignore`; avoid hand-editing them and regenerate outputs intentionally when needed.

## Odin: Build And Run

- Requires Odin dev-2026-11 or newer (tested with dev-2026-11a); older releases lack the current `core:os` API (`os.read_entire_file(path, allocator)` returning `os.Error`, `os.lookup_env(key, allocator)`).
- Work from `odin/`: `odin run vacina`, `odin build vacina -o:speed` (output `vacina.bin` on Linux, `vacina.exe` on Windows), `odin test tests` (pure logic tests, no window or audio device). Add `-subsystem:windows` on Windows for a build without a console window.
- The code passes `odin check vacina -vet -strict-style`; `rules`, `keys`, `fontinfo` and `tests` pass the same check with `-no-entry-point`. Keep it that way.
- Nothing is downloaded: raylib 6.2 ships with the compiler (`vendor/raylib/`). In an Odin git clone those libraries are Git LFS files; without `git lfs pull` the link fails with "file format not recognized" on `libraylib.a`.
- Linux: linking needs the `libX11.so` symlink (`libx11-dev`), and running needs OpenGL 3.3 (Mesa llvmpipe works under Xvfb). Audio goes through raylib's miniaudio (PulseAudio, PipeWire, ALSA...); without a device the game runs silent. Only Linux was tested; Windows and macOS builds use the same raylib bindings but are untested.
- Headless check on Linux: `xvfb-run -a -s "-screen 0 1280x1024x24" odin run vacina`.
- Assets are embedded with `#load` in `odin/vacina/assets.odin`, so the binary runs from any directory. `odin/res/` holds copies of only the assets the game uses.
- Build outputs (`odin/*.bin`, `odin/*.exe`, `odin/*.pdb`) are ignored by `.gitignore`.
- Packages (one per folder):
  - `vacina/` (package `main`, uses raylib): `game.odin` (Game, texts, tick/render, keyPressed/keyReleased), `menu.odin` (Menu), `world.odin` (World/restartGame), `entities.odin` (Player, Enemy/Enemy02/Enemy03 as one `Enemy` with a `kind`), `text.odin` (font search and Java-like `drawString`), `sound.odin` (4 raylib sound aliases per sound, since Java opens a new `Clip` per play), `input.odin` (raylib keys to `keys.Frame_Input`), `gfx.odin` (colors, textures, sprites), `assets.odin`.
  - `rules/` (pure): Tile classes, map colors (`classify_pixel`), `build_level`, `place_free`, `Rectangle.intersects`, `(int)` casts, `Camera.clamp`.
  - `keys/` (pure): turns each frame's presses, repeats and held keys into ordered `keyPressed`/`keyReleased` events (W/A/S/D repeat while held; Esc/Enter do not).
  - `fontinfo/` (pure): TrueType/OpenType metrics (head, hhea, maxp, hmtx, cmap formats 4 and 12) for Java-like widths (em = point size in pixels, advances rounded per glyph, no kerning) and the size conversion for raylib (`pixel_height`, `raylib_ascent`: raylib sizes fonts by ascender - descender, not by the em).
  - `tests/`: the single test root; it imports the pure packages (and decodes the real level PNGs with `core:image/png`). Keep raylib and OS calls out of `rules`, `keys` and `fontinfo`.
- The world is drawn into a 240x160 `RenderTexture2D` and scaled 4x (point filter) to the 960x640 window; full-screen images and text are drawn on top at 960x640, like the Java `BufferedImage` + `BufferStrategy`.
- Text uses "Bookman Old Style" Bold (`BOOKOSB.TTF`, not redistributable) when present in `%WINDIR%\Fonts`, `%LOCALAPPDATA%\Microsoft\Windows\Fonts`, `$XDG_DATA_HOME/fonts` (or `~/.local/share/fonts`), `~/.fonts`, or on macOS `~/Library/Fonts`, `/Library/Fonts` and `/System/Library/Fonts/Supplemental`, then the free URW Bookman Demi clone (Linux, `fonts-urw-base35`), then Arial/DejaVu Sans/Liberation Sans Bold (Java's "Dialog" fallback), then raylib's bitmap font scaled by an integer factor. Widths come from `fontinfo`; raylib only rasterizes the glyphs (antialiased) at the nearest integer pixel height, so glyph shapes can be up to about 2% off the exact em size. A font missing any letter of `REQUIRED` in `text.odin` (or whose glyphs raylib renders empty) is skipped.

## Gameplay Data

- Both versions load `level1.png`, `level2.png`, and `level3.png` as pixel maps; exact ARGB colors create tiles, player starts, and enemy spawns.
- The level PNGs exist twice (`java/res/` and `odin/res/`). Editing a map changes gameplay layout, collision, and spawn points; update both copies (and the expected values in `odin/tests/rules_test.odin`).
- New map colors must be added in `java/src/World/World.java` and in `classify_pixel` in `odin/rules/rules.odin`.
- `Game.LEVEL` (Odin: `Game.level`) selects the level-specific map rules and player sprites; `World.restartGame` rebuilds the entity lists and reloads the level map.

## Manual Verification

- There are no automated gameplay tests; verify by launching either game and exercising it manually (on Linux, `xdotool` can drive both under Xvfb).
- Controls: `W`/`S` navigate menus, `Enter` selects (on the language option it toggles Portuguese/English), `Esc` pauses/unpauses or returns from credits, `Enter`/`Esc` on the end screen returns to the main menu, and in-game movement is `WASD`.
- Under Xvfb without a window manager, do not move the focus of the Java window with `xdotool windowfocus`: AWT receives keys through its own focus proxy window, which already has the focus. Give the Odin window the focus with `windowfocus`.

## Git Workflow

- If the user says `enter in the git workflow`, review the diff line by line, group changes by logical feature, and plan atomic commits (one logical change, max about 200 lines, independently reversible).
- Commit format: `<gitmoji> <scope>: <message>` or `<gitmoji> <message>`.
- Keep subjects under 60 characters and in imperative mood.
- Emoji priority: 💥 breaking, ✨ feature, 🐛 fix, ♻️ refactor.
