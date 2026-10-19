# Claude instructions

This repo is a Roblox game (Rojo project) plus a knowledge vault in `vault/`. The vault opens in Obsidian ("Open folder as vault"). It holds the rules, plans and notes Claude works from.

## Every session
1. Read `vault/00 Start Here/Current State.md` first.
2. Read only the notes the task needs. Follow `[[links]]`; never load the whole vault.
3. For game design or planning work, also use `vault/Playbook/` (the rules for planning, making, releasing and marketing).

## Ask first, don't guess (most important rule)
When asked to make, design, plan or add a game, a system, or any feature with open design decisions:
- Do not start building, and do not fill in blanks with your own assumptions.
- Run the intake in `vault/_Claude/Intake Questions.md`. Ask only what the vault and the code can't answer. Use AskUserQuestion, at most 4 questions per round, recommended option first. Stop asking when the minimum version is clear.
- Summarize the answers (use the Game Pitch template), get a yes, then build.
- Exception: the user explicitly says "just do it", "use defaults", "fill in the blanks" or "you decide". Then use the defaults listed in the intake note and write down every assumption in your reply and in the session log.
- Small, clear tasks (fix this bug, rename this, change this number) need no intake. Just do them.
- If a request conflicts with a Playbook rule or a Roblox rule, say so and ask before proceeding.

## Quality
- Follow `vault/_Claude/Roblox Rules.md` and finish every task with `vault/_Claude/Quality Checklist.md`.
- Tell the user what you could not test. There is no Roblox Studio or Luau tooling in the cloud session, so you can't run the game.

## Repo conventions
- Edit code in files, never in Studio (Rojo overwrites Studio edits).
- Layout: `src/shared` (data, remotes, models), `src/server` (Services, started in order from `Main.server.lua`), `src/client` (Controllers).
- Tuning numbers live in the shared data modules (`Config`, `Zones`, `FishData`, `GunData`), not inline.
- Every remote is declared in `src/shared/Remotes.lua`; the server validates every call.
- Match the surrounding code: tabs, comment density, naming.

## Saving usage
- Don't re-read files you already have. Use search for the part you need.
- Batch questions and edits. Prefer the smallest change that does the job.
- Keep vault notes short (under one screen). Update a note instead of adding a new one.

## End of every session
1. Update `vault/00 Start Here/Current State.md` (what changed, what's next, open questions).
2. Add a short log from the Session Log template in `vault/Session Log/`.
3. Commit with a clear message and push to the branch you were given. Open a pull request only if asked.
