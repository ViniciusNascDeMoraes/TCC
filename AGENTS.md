# AGENTS.md

## Project Shape

- The repo holds two independent versions of the same 2D game ("Vacina"), one per folder:
  - `java/`: the original Java AWT/Swing game. Entry point `Main.Game.main(String[])`; `Main.Game` owns the window, loop, rendering, input, and global game state.
  - `zig/`: a faithful port to Zig 0.16 + raylib 6.0. Entry point `zig/src/main.zig`; `zig/src/game.zig` mirrors `Main.Game`.
- Keep gameplay identical between the two. When changing rules, timings, texts, or maps in one, port the change to the other.
- No Maven, Gradle, wrapper scripts, CI workflows, lint, or codegen config exist. The Zig project has unit tests for its pure logic.
- Java IntelliJ metadata: `.idea/` stays at the repo root and points to `java/TCC.iml`, which marks `java/src/` and `java/res/` as source roots, outputs to `java/bin/`, and targets JDK 25.
- Do not assume Eclipse files exist; there is no `.classpath` or `.project` in the current repo.

## Java: Build And Run

- Work from `java/`: `cd java`.
- Compile when a JDK is on `PATH`: `javac -cp "src;res" -d bin src\Main\Game.java` (use `:` instead of `;` on Linux/macOS).
- Run: `java -cp "bin;res" Main.Game`.
- Java sources are UTF-8 (`javac`'s default since JDK 18). Keep them UTF-8: the Portuguese accents were lost once when Latin-1 files were reformatted as UTF-8.
- The `java/` working directory matters because images/levels use classpath resources like `/Spritesheet.png`, while audio uses filesystem paths like `res/Menu.wav`.
- `java/bin/` and `java/doc/` are generated artifacts ignored by `.gitignore`; avoid hand-editing them and regenerate outputs intentionally when needed.

## Zig: Build And Run

- Requires Zig 0.16.x (`minimum_zig_version` in `zig/build.zig.zon`). raylib 6.0 does not build with older Zig, and Zig 0.17 is not supported by raylib yet.
- Work from `zig/`: `zig build run` (downloads and compiles raylib on the first build), `zig build test` (pure logic tests, no window), `zig build -Doptimize=ReleaseFast`.
- Cross-compile for Windows from any OS: `zig build -Dtarget=x86_64-windows`. Optimized Windows builds use the GUI subsystem (no console window); Debug builds keep the console for the FPS log.
- Linux builds need X11/GL dev packages (Debian/Ubuntu: `libx11-dev libxrandr-dev libxinerama-dev libxcursor-dev libxi-dev libgl-dev`).
- Assets are embedded into the executable through `zig/res/assets.zig` (`@embedFile`), so the binary runs from any directory. `zig/res/` holds copies of only the assets the game uses.
- `zig/.zig-cache/`, `zig/zig-out/`, and `zig/zig-pkg/` (Zig 0.16 package cache) are ignored by `.gitignore`.
- Module map: `game.zig` (Game), `menu.zig` (Menu), `world.zig` (World/restartGame), `entities.zig` (Player, Enemy/Enemy02/Enemy03 as one `Enemy` with a `kind`), `rules.zig` (Tile classes, map colors, `place_free`, `Rectangle.intersects`), `camera.zig`, `sound.zig`, `spritesheet.zig`, `text.zig` + `ttf.zig` (fonts), `gfx.zig` (colors/images).
- Keep raylib calls out of `rules.zig`, `camera.zig`, and `ttf.zig` so `zig build test` runs without a window.
- Text uses "Bookman Old Style" Bold from the system font folder when present (not redistributable), then Arial/DejaVu Sans Bold, then raylib's default font.

## Gameplay Data

- Both versions load `level1.png`, `level2.png`, and `level3.png` as pixel maps; exact ARGB colors create tiles, player starts, and enemy spawns.
- The level PNGs exist twice (`java/res/` and `zig/res/`). Editing a map changes gameplay layout, collision, and spawn points; update both copies.
- New map colors must be added in `java/src/World/World.java` and in `rules.classifyPixel` in `zig/src/rules.zig`.
- `Game.LEVEL` (Zig: `Game.level`) selects the level-specific map rules and player sprites; `World.restartGame` rebuilds the entity lists and reloads the level map.

## Manual Verification

- There are no automated gameplay tests; verify by launching either game and exercising it manually.
- Controls: `W`/`S` navigate menus, `Enter` selects, `Esc` pauses/unpauses or returns from credits, `Enter`/`Esc` on the end screen returns to the main menu, and in-game movement is `WASD`.

## Git Workflow

- If the user says `enter in the git workflow`, review the diff line by line, group changes by logical feature, and plan atomic commits (one logical change, max about 200 lines, independently reversible).
- Commit format: `<gitmoji> <scope>: <message>` or `<gitmoji> <message>`.
- Keep subjects under 60 characters and in imperative mood.
- Emoji priority: 💥 breaking, ✨ feature, 🐛 fix, ♻️ refactor.
