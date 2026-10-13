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

## Files
- `map/BuildMap.lua`: builds the whole map. Paste it into Studio's Command Bar.
- `CastleFishing.rbxm`: all the game scripts in one drag-in file.
- `src/`: the same scripts as source code (for Rojo users).

## Tuning
All balance numbers are in `src/shared`:
- `Config.lua`: bite timing, bag size, pond upgrade costs and bonuses
- `FishData.lua`: fish, rarities, weights, prices and zones
- `RodData.lua`: rods, prices and stats

## Code layout
```
src/shared   -> ReplicatedStorage.Shared   (data tables, remotes, formatting)
src/server   -> ServerScriptService.Server (Data, Plot, Rod, Shop, Fishing services)
src/client   -> StarterPlayerScripts.Client (UI + fishing/minigame controller)
```
Fishing is server-authoritative. The server checks the cast distance and the water, rolls the fish, times the bite, and rejects reels that finish impossibly fast, so exploiters can't spawn fish.
