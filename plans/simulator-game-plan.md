# Plan: "Slime Stack Simulator" (working title)

A new Roblox simulator, unrelated to Spearfishing Cove. Planning only; no code yet.

## Concept
Collect slime blobs around the map with a vacuum backpack, sell them for coins, upgrade your gear, hatch pets that boost your income, and unlock new worlds. Core loop: **collect -> sell -> upgrade -> unlock**.

## Core loop (first 10 minutes)
1. Spawn in the Meadow world with a basic vacuum and a 20-slime backpack.
2. Walk over slimes to suck them up (hold click or tap).
3. Backpack fills; walk to the Sell Pad to turn slimes into coins.
4. Spend coins on: Backpack size, Vacuum range/speed, Walk speed.
5. At 500 coins, buy the first Egg and hatch a pet.
6. At 5,000 coins, unlock World 2 (Crystal Caves) via a gate.

## Systems
| System | Details |
|---|---|
| Collecting | Slimes spawn in clusters, respawn on a timer. Rarity: Common, Rare, Epic, Legendary (value x1, x3, x10, x50). |
| Backpack | Capacity upgrades; full-bag warning above the player. |
| Selling | Sell Pad per world, with a coin multiplier from pets and rebirths. |
| Upgrades | Capacity, collect speed, collect range, walk speed. Cost grows about x1.35 per level. |
| Pets | Eggs by world, hatch animation, up to 3 equipped (6 with game pass). Each gives a coin and collect multiplier. Rarity tiers match slimes. |
| Worlds | Meadow -> Crystal Caves -> Lava Fields -> Sky Islands. Each has higher slime value and a bigger egg price. |
| Rebirth | Reset coins and upgrades for a permanent x1.5 multiplier stacking per rebirth. Unlocks at 100k coins. |
| Daily reward | Login streak with coins, then an egg on day 7. |
| Leaderboard | Coins, rebirths, rarest pet. |
| Monetization | Game passes: 2x Coins, Auto-Collect, +3 Pet Slots. Products: Coin packs, Lucky Egg boost. |

## Technical design (Rojo)
```
src/shared   -> Config, SlimeData, PetData, WorldData, Remotes
src/server   -> DataService (DataStore + session lock), SlimeService, SellService,
                UpgradeService, PetService, RebirthService, StoreService
src/client   -> HUD (coins, backpack bar), UpgradeShop, PetInventory, EggHatchUI, SlimeRenderer
```
- Server owns all values (coins, inventory). Client only sends requests through RemoteEvents; the server validates range, cooldowns and affordability.
- Slimes are spawned server-side as anchored parts in a folder per world, collected with proximity checks. Use CollectionService tags and a pooled spawner to keep part counts low.
- Data saved with DataStoreService (UpdateAsync, autosave every 60s, save on leave and BindToClose).
- All balance numbers live in `src/shared` data modules so tuning needs no logic edits.

## Milestones
1. **Prototype (day 1-2):** baseplate, slimes, vacuum, backpack, sell pad, coins HUD.
2. **Progression (day 3-4):** upgrades shop, saving and loading, Meadow polish.
3. **Pets (day 5-7):** eggs, hatching UI, equip and multipliers, inventory.
4. **Worlds and rebirth (week 2):** Crystal Caves, gates, rebirth, leaderboard.
5. **Live-ops (week 3):** daily rewards, game passes, tutorial, sound, mobile UI pass.
6. **Playtest and launch:** friends test, tune the economy, publish.

## Risks and mitigations
- **Economy inflation:** model costs in a spreadsheet first; cap multipliers per tier.
- **Exploits:** never trust client coin or slime counts; rate-limit remotes.
- **Performance on mobile:** cap live slimes per player, use simple meshes, avoid per-frame server loops.
- **Data loss:** session locking and retry on DataStore errors.

## Open questions
- Art style (low-poly vs. cartoon)?
- Solo or co-op bonuses (shared event, trading)?
- Target audience age, which affects monetization choices.
