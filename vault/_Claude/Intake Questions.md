# Intake Questions
Used when the user asks Claude to make or plan a game or feature. See the rule in `CLAUDE.md`.

## How to ask
- Skip anything already answered in the vault or the code.
- Max 4 questions per round. Put your recommended option first. Wait for answers before the next round.
- Stop when the minimum version is clear. Don't interrogate.
- Finish with a summary using [[Game Pitch]], then ask "Is this right? Build it?"

## New game
**Round 1: the idea**
1. What is the game in one sentence, and what makes it worth playing over similar games?
2. Who is it for (age range), and which devices matter most (mobile, PC, console)?
3. What does the player do every 30 seconds (the core loop)?
4. How much time per week, what deadline, and what budget for paid things (assets, hires, ads)?

**Round 2: structure**
5. Solo or team? Which of scripting, models, UI, sound, VFX and art can you do yourself, and who covers the gaps?
6. What does the player earn, what do they spend it on, and what is the long-term goal?
7. Solo, co-op or competitive? How many players per server?
8. Monetization: none at first, game passes, products, ads? What is off limits (e.g. pay-to-win)?

**Round 3: feel and onboarding**
9. Art style and sound direction? Any reference games?
10. How does a new player learn the game in the first five minutes?
11. What can be reused (assets, plugins, existing code)?

**Round 4: launch**
12. Testing plan, launch window, and what counts as success (retention, playtime, players)?
13. Marketing plan: social channels, Discord, ad budget?
14. Which funnel steps should the game log from day one?

## New feature in an existing game
1. What problem does it solve for the player?
2. Where does it fit in the core loop, and who sees it first?
3. How does it affect the economy or balance?
4. How should it behave on mobile, PC and gamepad?
5. What does "done" look like, and how will it be tested?

## Defaults (only when the user says "use defaults" / "just do it")
Mobile-first UI, single place, core loop only for the first version, placeholder art, server-authoritative logic, versioned DataStore saving, simple hands-on tutorial, no monetization in the first version. List every assumption used at the end of your reply.
