# WHISPERING VALLEY

🎮 **Chơi Trực Tiếp Trên Trình Duyệt / Play Online:**  
👉 **[https://giangha20.github.io/whispering-valley/](https://giangha20.github.io/whispering-valley/)**

Cozy 2D Pixel Art Farming, Life Simulation & Adventure RPG built with **Godot Engine 4.7.2** (`GL Compatibility` renderer, targeting both **Web HTML5/PWA** and **Windows Desktop**). All 78 automated systems tests passed (0 failures).

---

## Features Implemented
- **12 Interconnected Regions + Interiors + 100-Floor Ancient Mine**: Greenfield Farm, Willow Village, Whispering Forest, Crystal Lake, Sunflower Beach, Ancient Mine Quarry & 100-Floor Shaft (Bosses on floors 25, 50, 75, 100), Frostpeak Mountain, Golden Desert, Moonlight Garden, Forgotten Ruins (unlocks at Mine Floor 10), Mushroom Valley, and Hidden Sanctuary (unlocks at Mine Floor 25).
- **Character Creation & Layered Pixel Art**: Live 4x-zoomed animated preview with 54 customization choices (12 hairstyles, 10 hair colors, 14 outfits, 8 outfit colors, 12 accessories, 6 skin tones) and 5 save slots.
- **Farming Core**: Grid-based tilling, watering, 3 fertilizers, 64 unique crops across 6 categories, 5 growth stages, seasonal growth rules, all-season Greenhouse, regrowth crops, 4 quality tiers (Normal, Silver, Gold, Iridium), and automated sprinklers.
- **Animals & Farm Buildings**: 12 livestock species, Coop/Barn capacity, daily feeding/petting/product collection, plus 32 constructible/placeable buildings, machines (Furnace, Cheese Press, Mayonnaise Churn, Loom, Keg, Preserves Jar, Oil Press, Bee House), chests, paths, and fences with collision validation, move, and pack/demolish.
- **32 NPCs & 12 Shops**: Daily schedules, rainy-weather behavior, contextual seasonal/weather/friendship dialogue with choices, favorite/liked/disliked gift reactions with daily & weekly gift caps, and atomic shop buy/sell transactions + overnight Shipping Bin.
- **Fishing, Mining, Crafting & Cooking**: 84 biome/season/weather/time-filtered fish with active reel catch-bar mini-game; 100-floor procedural mine with ore nodes, bombs, treasure chests, monsters, and bosses; 104 crafting recipes & 84 cooking dishes with energy/health recovery and timed buffs.
- **Progression, Festivals & Audio**: 156 event-driven quests, 64 achievements, 12 annual festivals, collections codex, procedural cozy music/ambient/SFX audio with volume & mute controls.
- **PC & Mobile Controls**: Keyboard (`WASD`/`Arrows`, `Shift` run, `E` interact, `Space` tool/attack, `I/M/J/C/K/B`, `1-0` hotbar, `ESC` pause), Mouse click-to-move/use, and Mobile Virtual Joystick + Action Buttons (`Auto`, `Always Show`, or `Off` in Settings).
- **Crash-Safe Persistence**: Versioned JSON saves (`user://saves/slot_1..5.json`, persisted in IndexedDB on Web and AppData on Windows) with `.bak` crash recovery snapshots, schema migration, security validation, and JSON export/import.

## Running the Game (Godot 4.7.2)

### Launch Directly via Godot CLI
```powershell
& "C:\Users\giang\Downloads\Compressed\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" --path "C:\Users\giang\.gemini\antigravity\scratch\whispering-valley"
```

### Open in Godot Editor
```powershell
& "C:\Users\giang\Downloads\Compressed\Godot_v4.7.2-stable_win64.exe\Godot_v4.7.2-stable_win64.exe" -e --path "C:\Users\giang\.gemini\antigravity\scratch\whispering-valley"
```

### Run Automated Test Suite
```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\giang\.gemini\antigravity\scratch\whispering-valley\tools\build.ps1"
```

### Exporting Web HTML5 & Windows `.exe` Builds
`export_presets.cfg` is pre-configured with both `"Web"` (PWA-enabled) and `"Windows Desktop"` presets.
Once Godot 4.7.2 Export Templates are installed (`Editor -> Manage Export Templates` inside Godot Editor, or placed under `%APPDATA%\Godot\export_templates\4.7.2.stable`), run:
```powershell
powershell -ExecutionPolicy Bypass -File "C:\Users\giang\.gemini\antigravity\scratch\whispering-valley\tools\build.ps1" -ExportWeb -ExportWindows
```
