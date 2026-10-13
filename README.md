# Spearfishing Cove

A low-poly Roblox spearfishing game. Dive into a huge stepped ocean pit, spear sea creatures (from sardines to krakens and leviathans), and get your catch out of the water before the zone's guardian catches you.

## Gameplay
- **The chase:** every zone has four guardians, one sleeping in each corner of the zone floor. Spear a creature and you carry it on your back. The nearest guardian wakes up (and any other close enough to notice) and hunts you, lunging when it gets close. Get your head out of the water to bank the catch. If it bites you, you take damage and your catch swims away.
- **Zones and guardians:** Sunlit Shallows (Reef Shark), Coral Reef (Giant Moray), Twilight Trench (Great Hammerhead), The Abyss (The Kraken) and Leviathan's Rift (Ancient Leviathan). Each zone has its own fog colour. Deeper zones have rarer creatures and faster guardians.
- **Creatures:** 31 species, including sharks, squids, rays, a turtle, eels, a sea dragon, a Megalodon Pup, a Kraken Spawn and a Leviathan Hatchling. The rarest ones swim near the guardian's lair.
- **Sizes and mutations:** every catch rolls a size (Tiny, Normal, Large, Giant, Colossal) and can roll a mutation (Golden, Albino, Shadow, Neon, Rainbow). Both multiply its value.
- **Upgrades:** **Flippers** (swim speed, to outswim the guardians) and the **Air Tank** (time underwater). Six spearguns, from the Driftwood Speargun to the Royal Trident.
- **Bases:** each player gets a base. Its big aquarium shows their best catches swimming.
- **Sea Index:** every creature per zone, with the sizes and mutations you've found. Finding every creature in a zone pays a bonus.
- **Pearl Shop:** Robux game passes and products. They show "Soon" until you put real IDs in `Config.lua` (see below).

## Controls
- **Click**: fire. Diving takes out your speargun and switches to first person (**1** also holds or puts it away).
- **Shift** (or the **DASH** button on mobile): burst of speed underwater, with a cooldown.
- **B** Bag, **V** Shop, **X** Index, **P** Pearl Shop.

## Setup (Rojo)
One-time:
1. Clone this repo with GitHub Desktop and switch to this branch.
2. Double-click **Start Rojo.bat** (Windows) or **Start Rojo.command** (Mac). The first run downloads Rojo 7.7.0. Keep the window open. (You also need the Rojo plugin in Studio, from the Creator Store.)
3. Open your place in Studio, then click **Plugins → Rojo → Connect**.
4. Press **Play**. The game builds the map by itself the first time (and whenever the map code changes). To build it in edit mode too, run `require(game.ServerStorage.BuildMap)()` in the Command Bar.

Every update afterwards: **Fetch/Pull** in GitHub Desktop. Studio picks up the changes by itself while Rojo is connected.

Edit code in the files, not inside Studio. Rojo overwrites Studio-side edits to synced scripts.

## UI textures (one-time, about 2 minutes)
The menus use a texture sheet with real icons and halftone patterns: `assets/ui/ui_atlas.png`. Roblox needs every image uploaded once, so:
1. In Studio, open **View → Asset Manager**.
2. Click **Import** (called **Bulk Import** in older Studio versions), pick `assets/ui/ui_atlas.png` from your CastleFishing folder, and confirm.
3. Find `ui_atlas` under **Images** in the Asset Manager, right-click it and choose **Copy Asset ID** (or **Copy ID to Clipboard**).
4. Open `src/shared/Config.lua` in a text editor and paste it into the line `Config.UIAtlasId = 0` (for example `Config.UIAtlasId = "rbxassetid://123456789"`). Save. Rojo sends it to Studio.

Until you do this (or if Roblox is still checking the image), the game uses colour emoji icons instead, so nothing breaks. If the Output window says the atlas couldn't load: publish the place (**File → Publish to Roblox**), check that the image you uploaded is `assets/ui/ui_atlas.png`, and give Roblox a few minutes to approve it.
Icons are from game-icons.net (CC BY 3.0), credited in `assets/ui/CREDITS.md` and on the title screen. To change the sheet, edit and run `assets/ui/build_atlas.py`, then upload the new PNG.

## Robux shop
Create your game passes and developer products on the Creator Dashboard, then put their IDs in `Config.Store` in `src/shared/Config.lua` (replace the `Id = 0` entries). Anything with `Id = 0` shows as "Soon" and can't be bought.

## Tuning
All balance numbers are in `src/shared`:
- `Config.lua`: upgrade levels and costs (Flippers, Air Tank), dash, spear speed, respawn times, bag size, chase settings, store items
- `Zones.lua`: zone depths and sizes, fog colours, creature counts, and each guardian's speed, wake-up time, bite range and damage
- `FishData.lua`: creatures, rarities (and their health), sizes, mutations, prices, and the per-zone value multiplier
- `GunData.lua`: spearguns, prices, damage, range, reload and colours

## Code layout
```
src/shared       -> ReplicatedStorage.Shared       (data, zones, fish paths, low-poly geometry, creature and speargun models, remotes)
src/server       -> ServerScriptService.Server     (Map, Data, Plot, Gear, Shop, Store, Diver, Chase, Fish services)
src/client       -> StarterPlayerScripts.Client    (UIKit, Audio, controllers for UI, water, fish, diving, spear, guardians, underwater, intro, tutorial)
map/BuildMap.lua -> ServerStorage.BuildMap
```
Creature positions come from shared path maths (`FishPath`), so every player sees the same creatures with almost no network traffic. Guardians are simulated on the server and smoothed on clients. The server checks each shot (reload time, where it was fired from) and each hit (the creature must be within the gun's range at that moment) before you get the catch.
