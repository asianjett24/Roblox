# MASTER PROMPT: build the Roblox game-making skill

## Run mode (read first)
- This run is unattended. I am asleep and will read your morning report. **Do not ask me any questions.** Every answer you need is in this file.
- This file is my explicit "just do it, use defaults, you decide" authorization from `CLAUDE.md`. For this run only, the ask-first rule in `CLAUDE.md` is suspended. Also for this run only, do NOT push to GitHub: commit locally on a new branch `skill-build`.
- If a command is blocked or needs an approval you can't get, don't wait. Choose another way, and log it.
- If a decision needs a human, write it in `DECISIONS_NEEDED.md` with your recommended default, use that default, and mark it reversible.

## Mission
Build a Claude Skill (plus a supporting knowledge vault) that lets Claude plan, build, test and launch a polished, fully working Roblox game and a social media presence for it, in as few attempts as possible. You are NOT building a game now. You are building the skill future Claude sessions will use.

## Time
You have a minimum of 12 hours of working time, and more if you need it. Use it. Do not stop because the first draft looks fine. Stop when the "Definition of done" is met, and keep improving until it is. If you finish early, use the remaining time to find more sources, add tests, and try to break your own work. Record timestamps (run `date`) in the work log.

## Setup and what to start from
- I'm new to Claude Code and Obsidian, on Windows. I make Roblox games with Claude.
- This folder is an Obsidian vault and git repo: `CLAUDE.md`, `_Claude/` (intake questions, Roblox rules, quality checklist), `Playbook/` (27 rules from one creator, plus a glossary), `Templates/`, `Games/`, `Logs/`, `00 Start Here/Current State.md`. Read all of it first.
- **Start the research from scratch.** Do not treat earlier transcripts or the existing Playbook as truth. The Playbook is an unverified draft: regenerate that source through your own pipeline, directly into this vault, then merge or replace the draft (git history keeps the old version).
- The only earlier input is `Research/urls.txt`: the link list for the TikTok account @dontrunsamurairoblox (a real solo Roblox developer whose own results are early-stage, so treat his rules as one person's experience). If it is missing, try to collect the links yourself (for example a headless browser that scrolls the profile). If you're blocked, log it and move on to other sources.
- My old game, Spearfishing Cove, is in git history at commit `219e4a3`. Its UI toolkit and icon-atlas system are a worked example worth studying. Do not restore it to the working tree.
- Lessons already learned on this machine: yt-dlp can't read a TikTok profile page, so use a URL list; pin `av<17` or faster-whisper breaks; audio-only extraction misses on-screen text, so download full videos; the `small` speech model misses voices under music; speech models transcribe song lyrics as speech, so ignore and never store lyrics; use a separate download-archive file per mode.

## Answers to the startup questions
- Hardware: Intel i7-13700KF (16 cores), 32 GB RAM, NVIDIA RTX 4070 with 12 GB, 732 GB free on C:. Use the GPU for speech transcription: set up the CUDA libraries per the faster-whisper docs, confirm with `nvidia-smi` that the GPU is actually in use, and fall back to CPU only if that fails. Use `large-v3` or `medium` for sources that matter and `small` for triage.
- Browser cookies: no. Downloads worked without them. Do not use my logged-in browser sessions.
- Disk and money: no spending of any kind. Cap disk use at about 100 GB. Delete raw media once processed.
- Installs: allowed for Python packages and a screenshot tool. Use a virtual environment in `Research/.venv` so you don't break the existing Python setup. No system-wide changes.
- Sources: English. TikTok and YouTube are the main platforms, plus official docs and articles. Prefer people with real results. Skip anything that looks AI-generated or is selling a course.
- Files: work inside this folder. Commit to the local branch `skill-build`. Do not push.

## What the finished skill must do
1. **One-shot or close to it.** Given a game idea, it plans, asks only the questions that matter, builds, checks its own work, and finishes in the fewest attempts.
2. **Know the goal.** The target is a successful game: fun, retaining players, launched with a social media presence. Not just code that runs.
3. **Ask well.** It asks only when the answer would materially change the result and can't be inferred, in batches, within a question budget. Otherwise it decides, records the decision and assumption in a log, and shows one alternative. "Just do it" and "use defaults" turn questions off.
4. **Non-generic UI.** It works out which screens the game needs from the design document, asks the style-shaping questions, picks a style direction, builds design tokens, designs components and screens, implements them for Roblox, and reviews them against a rubric. It must reliably avoid the generic default look.
5. **A judgment system that is honest.** See "Judge".
6. **A human playtest loop.** See "Playtest".
7. **Studio-native, editable output.** Never a game that is one giant script that builds everything at runtime. Anything a human will want to edit (UI, maps, props, lighting) must exist as real objects visible in the Explorer, stored in files Studio can read (for example Rojo model files or `.rbxmx`), with behavior in scripts and look and feel in properties and attributes. Every game ships with a handoff note mapping what is where and what to edit to change what. Include a "Studio literacy" module so builds follow how a person following a Studio tutorial would work. Check Roblox's current docs for any official way to connect Claude to Studio before relying on it.
8. **Cover everything a successful game needs:** concept and market research; core loop and scope; progression, difficulty, balance; economy; monetization and ethics for a young audience; retention and live ops; onboarding (the first five minutes); social and multiplayer; level and map design; camera, controls, game feel; UI and UX; art style; 3D building; animation; VFX; lighting; sound effects and music; performance and mobile optimization; security and anti-exploit; data saving; analytics and funnels; testing and QA; accessibility; localization; safety, privacy and Roblox policy compliance; release (game page, icon, thumbnails, trailer, age rating); marketing, ads, community and creator partnerships; the social media and online profile (branding, content pillars, formats, cadence, Discord, analytics, press kit, AI-disclosure rules); legal, IP, licensing and tax basics; project management; postmortems.

## Knowledge: research from real people, with provenance
- Study real, human sources, not AI-generated content: official Roblox docs (authority for rules and APIs), proven creators (judgment and taste), tutorials (workflow). Quality over quantity: a few hundred well-chosen sources beat thousands of weak ones. Go larger only where it clearly adds new information.
- Starting points, all to be verified: Roblox Creator Hub docs, Roblox Developer Forum and RDC talks; YouTube channels AlvinBlox, TheDevKing, BrawlDev; Game UI Database (Edd Coates) and videogameinterfaces.com; Celia Hodent's work and GDC talks on UX; Game Maker's Toolkit; Chris Zukowski (How To Market A Game); GameDiscoverCo; Deconstructor of Fun; Designing Sound, The Game Audio Tutorial and GameSoundCon for audio. Find many more, especially for Roblox-specific UI, current sound-design creators, TikTok and YouTube game-marketing creators, and Roblox Studio tutorials. Score each source on track record, evidence, recency, Roblox relevance, audience match, and conflicts of interest.
- For every extracted claim record: source, date, timestamp or location, confidence (official, multiple independent sources, single opinion), and an expiry hint. Cross-check important claims with at least two independent sources where possible. Merge duplicates. Keep conflicts visible and resolve them explicitly.
- Never fabricate a source, quote or URL. Verify that links exist. If you can't access something, say so.
- Store paraphrased rules with links in the vault. Keep raw transcripts only in `Research/_raw/` (git-ignored). Never reproduce song lyrics, books or long excerpts.
- Respect terms of service. This is personal research. Rate-limit requests. If a site blocks you, log it and move on. Do not create accounts, bypass paywalls or DRM, or try to evade blocks.
- Build the pipeline as resumable scripts: collect, download, transcribe, read on-screen text, sample frames, extract claims, dedupe, score, synthesize. Run local steps in the background and save progress after each item. Use your own reasoning only for extraction and synthesis, batched.
- Build a human review queue: a short list of the disputed or highest-impact rules for me to approve. Mark everything unreviewed as such.

## Judge: honest aesthetic and feel assessment
Claude cannot rely on gut feeling. Build a system that produces judgments matching mine often enough to trust, and measures that.
- Observation first: list what is visibly there. Only then judge. Every verdict cites specific visible evidence.
- Prefer pairwise comparison against labeled references over absolute scores.
- Rubrics built from observable criteria (hierarchy, contrast, alignment, consistency, density, readability, affordance, style coherence, and so on).
- A calibration set: create `Examples/` (good, bad, and a reason for each) and a fast labeling workflow I can finish in under an hour (a queue of pairs with a one-line reason each). Until I label examples, run the judge in "provisional" mode and say so. Never claim it is calibrated until it has been tested on held-out labeled examples and the agreement rate is recorded.
- "I can't tell" is an allowed answer. Separate how something looks (screenshots) from how it feels (needs players or measurements such as input latency and animation timing). Flag feel questions for human playtest.
- Every correction I make becomes a new labeled example.

## Playtest: think-aloud human feedback
- Produce per-build briefing cards (duration, device, focus, what to ignore), a think-aloud script for testers, a short end-of-session survey, and rules for the person running the test (do not help, hint or defend).
- Pipeline: screen and voice recording, transcribe with timestamps, pull the frame at each comment, classify issues (onboarding, UI clarity, feel, difficulty, audio, bugs, performance), rate severity (quit risk versus minor), count repeats across testers, and output a fix list with frames attached.
- Guidance for testers: target-age strangers where possible, several testers, retrospective commentary for fast games, parent or guardian permission for under-18 testers, combine with analytics funnels.
- Feed results back into the judge's examples and measure whether the judge predicted what testers said.

## The loop
Brief, plan, build, capture, judge, fix, repeat, with a maximum number of rounds, stop conditions, human checkpoints (playtests and taste-defining choices), a decision log, an assumptions list, state saved to files so it can resume, and a defined way to handle being stuck.

## UI module (build it fully; it is the pilot and the template for all others)
Systems-to-screens map; intake questions; style archetypes with concrete values; design tokens (color incl. contrast and color-blind safety, type scale, spacing, shape, shadow, motion); component library with states; mobile-first layout, safe areas, gamepad navigation; Roblox implementation notes (verify fonts and UI objects against current docs); icons and asset licensing; HUD versus menu hierarchy; onboarding UI; accessibility; an anti-pattern list; an annotated reference gallery structure. Where possible, prototype UI in HTML, render screenshots, and run the judge on them, so the loop can be exercised without Studio.

## Skill format
Use the `skill-creator` skill if available. A lean router `SKILL.md` that decides which modules to load, with detail in separate reference files loaded only when needed. One shared template for every module: intake, direction, rules, patterns, implementation, review, references. Keep the router short, avoid contradictions between modules, and version everything with a changelog. Keep the vault (sourced knowledge) and the skill (distilled rules) in sync and clearly separate.

## Evaluate it
Build a test harness. Run the same tasks with and without the skill across at least three genres: UI mockups, design documents, plans, and small Studio-native samples. Do not build full games. Compare blind where possible. Track: questions asked, editability, genericness of the UI, judge-versus-human agreement, completeness. Fix what the comparison exposes and repeat. Record results honestly, including failures.

## How to work
- Keep `WORKLOG.md` (timestamps, what you did, what you learned) and a state file so you can resume after any interruption or usage limit. Commit often to the local branch `skill-build`. Never push, and never merge into main.
- Safety: stay inside this folder, except for tool installs described above. No destructive operations on files you didn't create. No spending money, no publishing games or posts, no running ads, no contacting people. Check free disk space regularly.
- Honesty: report what is untested, unverified or guessed. Mark Roblox policy items "verify".
- Phases: (0) read everything and plan, (1) source list and scoring, (2) pipeline, (3) collection and processing, (4) claim extraction with provenance, (5) synthesis into the skill, (6) judge and playtest, (7) evaluation and iteration, (8) report. Review your own work at the end of every phase.

## Definition of done
- The skill folder exists, is lean, works from a cold start, and covers every area above.
- The vault holds sourced, dated, confidence-tagged rules, with a review queue for me.
- The judge, playtest module, loop spec, Studio-native standard and UI module are complete and tested.
- The evaluation shows the skill clearly beating plain Claude on the test tasks, with results recorded.
- A **morning report** at `00 Start Here/Morning Report.md`, written for someone new to all of this: what you built, how to use it, what's verified versus unverified, decisions I need to make, risks, what I must label or review first, and next steps.
