# Claude instructions

This repo is a knowledge vault only: no game code lives here. The whole repo opens in Obsidian ("Open folder as vault"). It holds the rules, plans and notes Claude works from when making Roblox games. Game code goes in each game's own repo.

## Every session
1. Read `00 Start Here/Current State.md` first.
2. Read only the notes the task needs. Follow `[[links]]`; never load the whole vault.
3. For game design or planning work, also use `Playbook/` (the rules for planning, making, releasing and marketing).

## Ask first, don't guess (most important rule)
When asked to make, design, plan or add a game, a system, or any feature with open design decisions:
- Do not start building, and do not fill in blanks with your own assumptions.
- Run the intake in `_Claude/Intake Questions.md`. Ask only what the vault and the code can't answer. Use AskUserQuestion, at most 4 questions per round, recommended option first. Stop asking when the minimum version is clear.
- Summarize the answers (use the Game Pitch template), get a yes, then build.
- Exception: the user explicitly says "just do it", "use defaults", "fill in the blanks" or "you decide". Then use the defaults listed in the intake note and write down every assumption in your reply and in the session log.
- Small, clear tasks (fix this bug, rename this, change this number) need no intake. Just do them.
- If a request conflicts with a Playbook rule or a Roblox rule, say so and ask before proceeding.

## Quality
- Follow `_Claude/Roblox Rules.md` and finish every task with `_Claude/Quality Checklist.md`.
- Tell the user what you could not test. There is no Roblox Studio or Luau tooling in the cloud session, so you can't run a game.

## When a game repo is attached
- Match its existing code style and layout. Edit code in files, not in Studio (Rojo overwrites Studio edits).
- Keep tuning numbers in data modules, not inline.
- Keep a note for each game in `Games/` and link it from `00 Start Here/Current State.md`.

## Saving usage
- Don't re-read files you already have. Use search for the part you need.
- Batch questions and edits. Prefer the smallest change that does the job.
- Keep notes short (under one screen). Update a note instead of adding a new one.

## End of every session
1. Update `00 Start Here/Current State.md` (what changed, what's next, open questions).
2. Add a short log from the Session Log template in `Logs/`.
3. Commit with a clear message and push to the branch you were given. Open a pull request only if asked.
