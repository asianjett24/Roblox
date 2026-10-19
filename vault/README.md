# Roblox x Claude vault
A notebook of rules, plans and templates that Claude reads before it works.

## Open it in Obsidian (first time)
1. In GitHub Desktop, make sure this repo is on the same branch Claude used, then **Fetch/Pull**.
2. In Obsidian click the vault name (bottom left) then **Manage vaults** then **Open folder as vault**.
3. Choose the `vault` folder inside the repo (not the repo itself).
4. Settings > Core plugins > turn on **Templates**, then set the template folder to `Templates`.

## Obsidian in 2 minutes
- A note is a text file. `[[Name]]` links to another note. Click the link to open it.
- **Ctrl+N** new note, **Ctrl+O** find a note, **Ctrl+Shift+F** search everything.
- Open **Graph view** (left bar) to see how notes connect.
- Insert a template into a note with the command palette (**Ctrl+P**) > "Templates: Insert template".

## Folders
- `00 Start Here` - Current State, the first thing Claude reads
- `_Claude` - rules Claude follows (intake questions, Roblox rules, quality checklist)
- `Playbook` - rules for planning, making, testing, releasing and marketing
- `Templates` - blank notes for pitches, design docs, tasks, launches
- `Games` - one folder per game
- `Inbox` - quick ideas
- `Session Log` - what each Claude session did

## Working with Claude
- Say "make a game" or "add a feature" and Claude asks questions first (see `_Claude/Intake Questions`).
- Say "just do it" or "use defaults" and it skips the questions and lists its assumptions.
- After a session, Fetch/Pull to see updated notes. If you edit notes, commit and push so Claude sees them next time.
- Edit rules freely. Claude follows what these notes say.
