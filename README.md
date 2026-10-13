# Castle Fishing

A Roblox fishing game on a walled castle island. There are 8 numbered bases around a huge 600m-deep pond, and each base has its own private dock. Players get a base when they join.

## Gameplay loop
1. Join and spawn at your base with a **Basic Rod**.
2. Equip the rod and **click the water** to cast. Wait for the `!`.
3. Win the **reel minigame**: hold click, tap or Space to keep the green bar on the fish until the meter fills.
4. Sell at the **Fish Market** stall, or press **Sell All** in your Bag.
5. Buy better rods at the **Rod Shop** (walk up to the door) or from the Shop button.
6. Fish from **your own dock** to find dock-only fish, and **upgrade your dock** for more luck.
7. The fish you're carrying swim around in your base's **tank**.
8. Fill out the **Index**: 16 fish across 6 rarities.

## Setup (Rojo, recommended)
One-time:
1. Clone this repo with GitHub Desktop and switch to this branch.
2. Double-click **Start Rojo.bat** (Windows) or **Start Rojo.command** (Mac). The first run downloads Rojo and installs its Studio plugin. Keep the window open.
3. Open your place in Studio (restart Studio if it was already open), then click **Plugins → Rojo → Connect**.
4. Build the map: in the Command Bar run `require(game.ServerStorage.BuildMap)()`.

Every update afterwards: **Fetch/Pull** in GitHub Desktop. Studio picks up the changes by itself while Rojo is connected. Re-run the map line only when the map changed.

Edit code in the files, not inside Studio. Rojo overwrites Studio-side edits to synced scripts.

## Files
- `BuildMap.rbxm` / `map/BuildMap.lua`: builds the whole map. Insert it into Workspace, then run `require(workspace.BuildMap)()` in the Command Bar.
- `CastleFishing.rbxm`: all the game scripts in one drag-in file.
- `src/`: the same scripts as source code (for Rojo users).

## Your own rod model
Put an imported rod model in **ServerStorage** and name it `RodModel` (a model called `Root Scene` works too). The game scales it, works out which end is the handle, and uses it for every rod. If it's held wrong, change `Config.Rod` in `src/shared/Config.lua` (`Flip`, `Spin`, `Tilt`, `GripAt`).

## Tuning
All balance numbers are in `src/shared`:
- `Config.lua`: bite timing, bag size, dock upgrade costs and bonuses, rod model settings
- `FishData.lua`: fish, rarities, weights, prices and zones
- `RodData.lua`: rods, prices and stats

## Code layout
```
src/shared   -> ReplicatedStorage.Shared   (data tables, remotes, formatting)
src/server   -> ServerScriptService.Server (Data, Plot, Rod, Shop, Fishing services)
src/client   -> StarterPlayerScripts.Client (UI + fishing/minigame controller)
```
Fishing is server-authoritative. The server checks the cast distance and the water, rolls the fish, times the bite, and rejects reels that finish impossibly fast, so exploiters can't spawn fish.
