# Castle Fishing

A Roblox fishing game built on the castle island map. Each player gets one of the pads as their plot. The hole in the pad is their **private pond**, and the big central pool is shared by everyone.

## Gameplay loop
1. Join and spawn on your plot with a **Basic Rod**.
2. Equip the rod and **click the water** to cast. Wait for the `!`.
3. Win the **reel minigame**: hold click, tap or Space to keep the green bar on the fish until the meter fills.
4. Open the **Bag** and **Sell All** for coins.
5. Buy better rods in the **Shop** (more luck, faster bites, a wider reel bar and longer range).
6. **Upgrade your Pond** for extra luck and faster bites when fishing at home.
7. Fill out the **Index**. There are 16 fish across 6 rarities. Some only live in the Pool and some only in Ponds.

Progress saves with DataStores. Legendary and Mythic catches are announced to the whole server.

## Setup (Rojo)
1. Install the Rojo plugin in Studio from the Creator Store ("Rojo" by rojo-rbx).
2. Install the Rojo CLI. Use `aftman install` in this folder, or download it from https://github.com/rojo-rbx/rojo/releases (v7.4.x).
3. Run `rojo serve` in this folder.
4. In Studio, open your castle place, click the Rojo plugin, then click **Connect**. The scripts show up in ReplicatedStorage, ServerScriptService and StarterPlayerScripts, and edits sync live.

## One-time map setup in Studio
The scripts need to know which parts are plots and which parts are water:

- **Plots:** create a Folder named `Plots` in Workspace and move each pad Model into it. You can tag each pad Model `Plot` with the Tag editor instead.
  - Optional: add a part named `Spawn` inside a plot to choose exactly where its owner spawns.
- **Plot holes (ponds):** put a water part in each hole, inside that plot's Model. Name it `Hole` or `Pond`, or tag it `FishingWater`.
- **Central pool:** parts named `WaterTri` or `Water` already count, as does anything with the Water material, Terrain water, or the `FishingWater` tag.
- **Merchant (optional):** tag any part `Merchant` to give it a "Sell All Fish" prompt. Set `Config.SellAnywhere = false` to require visiting it.
- Turn on **Game Settings → Security → Enable Studio Access to API Services** so saving works while you test.

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
