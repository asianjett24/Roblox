# Castle Spearfishing

A Roblox spearfishing game on a walled castle island. Dive into a 600 m pond, spear fish with your speargun, sell your catch and upgrade your gear to reach the deeper zones.

## Gameplay
- **Dive zones:** Kelp Shallows (0 to 100 m), Coral Reef (100 to 300 m), Deep Trench (300 to 500 m) and The Abyss (500 to 600 m). Rarer fish live deeper.
- **Spearguns:** six tiers, from the Driftwood Speargun to the Royal Trident. Better guns hit harder, reach further and reload faster.
- **Fish:** 16 species, each with its own swimming model. Rarer fish take several hits and flee when hurt.
- **Air:** your tank drains underwater and refills at the surface. Upgrade it in **Gear** to dive deeper.
- **Bases:** you get one of 8 bases. Its aquarium shows your best fish swimming, and the dock has a ladder out of the water.
- **Fish Index:** collect all 16 species and beat your weight records.
- **Controls:** press **1** for the speargun and **click** to fire. Menus open with **B** (Bag), **V** (Shop), **X** (Index) and **G** (Gear).

## Setup (Rojo, recommended)
One-time:
1. Clone this repo with GitHub Desktop and switch to this branch.
2. Double-click **Start Rojo.bat** (Windows) or **Start Rojo.command** (Mac). The first run downloads Rojo 7.7.0. Keep the window open. (You also need the Rojo plugin in Studio, from the Creator Store.)
3. Open your place in Studio (restart Studio if it was already open), then click **Plugins → Rojo → Connect**.
4. Build the map: in the Command Bar run `require(game.ServerStorage.BuildMap)()`.

Every update afterwards: **Fetch/Pull** in GitHub Desktop. Studio picks up the changes by itself while Rojo is connected. Re-run the map line only when the map changed.

Edit code in the files, not inside Studio. Rojo overwrites Studio-side edits to synced scripts.

## Files
- `map/BuildMap.lua`: builds the whole map. It syncs to ServerStorage; run `require(game.ServerStorage.BuildMap)()` in the Command Bar. The game also rebuilds an out-of-date map automatically when you press Play.
- `src/shared`: data and logic used by both server and client (fish, spearguns, fish paths, speargun models).
- `src/server`: services for data, plots, gear, the shop, air and fish.
- `src/client`: the UI design kit, fish models, and controllers for the UI, fish drawing, spear shooting and underwater effects.

## Tuning
All balance numbers are in `src/shared`:
- `Config.lua`: spear speed, fish respawn, air tank levels and costs, drowning damage, bag size
- `FishData.lua`: fish, rarities (and their health), weights, prices, zones, swim speed and looks
- `GunData.lua`: spearguns, prices, damage, range, reload and colours
- `FishPath.lua`: the depth zones and how many fish live in each

## Code layout
```
src/shared      -> ReplicatedStorage.Shared       (data, fish paths, speargun models, remotes)
src/server      -> ServerScriptService.Server     (Map, Data, Plot, Gear, Shop, Oxygen, Fish services)
src/client      -> StarterPlayerScripts.Client    (UIKit, FishModels, UI / FishRenderer / Spear / Underwater)
map/BuildMap.lua -> ServerStorage.BuildMap
```
Fish positions are worked out from shared path maths (`FishPath`), so every player sees the same fish with almost no network traffic. The server checks each shot (reload time, where it was fired from) and each hit (the fish must be within the gun's range at that moment) before awarding a catch.
