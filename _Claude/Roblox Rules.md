# Roblox Rules
Technical standards for any Roblox code here. Items marked (verify) depend on Roblox policy or APIs that change: check the current Roblox docs first.

## Authority and security
1. The server owns anything that matters: currency, inventory, damage, rewards, progression, purchases. The client asks and displays.
2. Every remote handler validates the player, argument count and types, number ranges (clamp, reject NaN), that the action is allowed right now (cooldown, distance, ownership), and rate-limits calls.
3. Client-side checks are for UX only, never for security.
4. Combat checks (reload, distance, line of sight) happen on the server.
5. Declare every remote in one shared module. No ad-hoc remotes.

## Data
6. Every DataStore call is in a `pcall` with retries and backoff. Never overwrite saved data after a failed load.
7. Save on `PlayerRemoving` and `game:BindToClose`, plus an autosave interval. Respect request budgets.
8. Version the data table and migrate old saves. New fields get defaults; never rename a field without a migration.
9. Developer products: `ProcessReceipt` must be idempotent and return the right enum. Game passes: check ownership on join and on purchase.

## Performance
10. Target low-end mobile. Watch part count, effects, per-frame work and network traffic. Prefer events over polling.
11. Pool or avoid per-frame object creation. Destroy what you create and disconnect connections when players leave.
12. Use `task.wait`, `task.spawn`, `task.delay`, not `wait`, `spawn`, `delay`.
13. Share computation instead of duplicating it per player.
14. Measure before optimizing (MicroProfiler, Developer Console).

## UI and input
15. Mobile first: scale-based sizing, size constraints, safe-area aware, large touch targets.
16. Every action works with touch, keyboard/mouse and gamepad.
17. Every screen can be opened and closed on every device.

## Code
18. One responsibility per module. Services on the server, controllers on the client, same Init-order pattern.
19. Tuning numbers live in the shared data modules, not inline.
20. Locals only, no globals. Use type annotations where the surrounding code does.
21. Warn with a `[ServiceName]` tag in development; fail safely for players.
22. Comments explain why, not what, at the density of the file you're editing.

## Roblox policy and publishing (verify)
23. Player-typed text shown to others goes through Roblox text filtering.
24. Paid random items may need odds disclosure under Roblox policy.
25. Use only assets, music and art you have the rights to.
26. The age-rating questionnaire and the "highly engaged player" requirement change over time. Check before launch.
