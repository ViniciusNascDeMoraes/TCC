# AGENTS.md

## Project type

Eclipse Java project targeting Java 1.8. No Maven, Gradle, or other build tool.

## Build & run

- **Entry point:** `Main.Game.main(String[])`
- **Source roots:** `src/` and `res/`
- **Output:** `bin/`
- Both Eclipse (`.classpath`, `.project`) and IntelliJ (`.idea/`, `TCC.iml`) configs exist; Eclipse is the canonical format.
- Build via Eclipse or manually with `javac -cp "src;res" -d bin src/Main/Game.java` (Windows) — note that all `.java` dependencies must be compiled together.
- There are no automated tests, lint, typecheck, or CI scripts. Verification is manual (run the game).

## Architecture

- Small 2D AWT/Swing game ("Vacina").
- `Main.Game` is the main loop and renderer.
- `World.World` loads levels from PNG pixel maps and instantiates tiles/entities.
- `res/` contains runtime assets (images, audio). They are loaded via classpath:
  `getClass().getResource("/Filename.png")`.

## Level design

- Levels are PNG images in `res/` (`level1.png`, `level2.png`, `level3.png`).
- `World.java` maps specific pixel colors to tile types and enemy spawn positions. Editing level art directly changes
  gameplay layout and spawn points.

## Notes

- `doc/` contains pre-generated Javadoc.
- No external dependencies; standard library only.

## Git Workflow

- If user says **"enter in the git workflow"**, perform:
    - Line-by-line diff review, then group changes by logical feature (not by file)
    - Plan atomic commits: one commit = one logical change, max ~200 lines, reversible independently
    - Commit format: `<gitmoji> <scope>: <message>` or `<gitmoji> <message>`
    - Keep subjects under 60 chars, imperative mood
    - Emoji priority: 💥 (breaking) > ✨ (feature) > 🐛 (fix) > ♻️ (refactor)