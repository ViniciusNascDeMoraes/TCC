# AGENTS.md

## Project Shape

- Plain Java AWT/Swing game ("Vacina") with entry point `Main.Game.main(String[])`; `Main.Game` owns the window, loop, rendering, input, and global game state.
- No Maven, Gradle, wrapper scripts, README, CI workflows, automated tests, lint, formatter, or codegen config were found.
- IntelliJ metadata is the only project config in the repo: `TCC.iml` marks `src/` and `res/` as source roots, outputs to `bin/`, and targets JDK 25.
- Do not assume Eclipse files exist; there is no `.classpath` or `.project` in the current repo.

## Build And Run

- Compile from the repo root when a JDK is on `PATH`: `javac -cp "src;res" -d bin src\Main\Game.java`.
- Run from the repo root: `java -cp "bin;res" Main.Game`.
- The repo root working directory matters because images/levels use classpath resources like `/Spritesheet.png`, while audio uses filesystem paths like `res/Menu.wav`.
- `bin/` and `doc/` are generated artifacts ignored by `.gitignore`; avoid hand-editing them and regenerate outputs intentionally when needed.

## Gameplay Data

- `World.World` loads `res/level1.png`, `res/level2.png`, and `res/level3.png` as pixel maps; exact ARGB colors create tiles, player starts, and enemy spawns.
- Editing level PNGs changes gameplay layout, collision, and spawn points; update `World.java` if adding new map colors.
- `Game.LEVEL` selects the level-specific map rules and player sprites; `World.restartGame(String)` rebuilds the static entity lists and reloads `/levelN.png`.

## Manual Verification

- There are no test commands; verify by launching `Main.Game` and exercising the game manually.
- Controls: `W`/`S` navigate menus, `Enter` selects, `Esc` pauses or returns from credits, and in-game movement is `WASD`.

## Git Workflow

- If the user says `enter in the git workflow`, review the diff line by line, group changes by logical feature, and plan atomic commits (one logical change, max about 200 lines, independently reversible).
- Commit format: `<gitmoji> <scope>: <message>` or `<gitmoji> <message>`.
- Keep subjects under 60 characters and in imperative mood.
- Emoji priority: 💥 breaking, ✨ feature, 🐛 fix, ♻️ refactor.
