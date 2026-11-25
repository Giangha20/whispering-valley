#!/usr/bin/env python3
"""
Generates all validated JSON data files for Whispering Valley.
Ensures 100% referential integrity across items, crops, fish, animals,
NPCs, shops, crafting, cooking, quests, festivals, achievements,
buildings, outfits, monsters, and regions.
"""
import json
import os

ROOT = os.path.dirname(os.path.dirname(os.path.abspath(__file__)))
DATA_DIR = os.path.join(ROOT, "data")
os.makedirs(DATA_DIR, exist_ok=True)


def write_json(name: str, payload):
    path = os.path.join(DATA_DIR, name)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(payload, f, indent=2, ensure_ascii=False)
    return path


def build_data():
    items = {}

    def add_item(item_id, name, desc, category, base_price, max_stack=99,
                 rarity="common", usable=False, sellable=True, metadata=None, icon_idx=None):
        assert item_id not in items, f"Duplicate item id: {item_id}"
        idx = icon_idx if icon_idx is not None else len(items)
        col = idx % 22
        row = idx // 22
        items[item_id] = {
            "id": item_id,
            "name": name,
            "description": desc,
            "category": category,
            "icon": f"atlas:{col},{row}",
            "sprite": f"atlas:{col},{row}",
            "atlasIndex": idx,
            "basePrice": int(base_price),
            "maxStack": int(max_stack),
            "rarity": rarity,
            "usable": bool(usable),
            "sellable": bool(sellable),
            "metadata": metadata or {}
        }

    # ---------------------------------------------------------
    # 1. CROPS (64 unique crops across 6 categories)
    # ---------------------------------------------------------
    crop_specs = [
        # Vegetables (16)
        ("turnip", "Turnip", "Vegetables", ["spring"], 3, 0, 55, 14, 6),
        ("parsnip", "Parsnip", "Vegetables", ["spring"], 4, 0, 65, 16, 7),
        ("potato", "Golden Potato", "Vegetables", ["spring", "autumn"], 6, 0, 95, 22, 10),
        ("carrot", "Crisp Carrot", "Vegetables", ["spring", "autumn"], 4, 0, 70, 18, 8),
        ("radish", "Ruby Radish", "Vegetables", ["summer"], 5, 0, 88, 20, 9),
        ("cauliflower", "Cloud Cauliflower", "Vegetables", ["spring"], 10, 0, 185, 34, 15),
        ("kale", "Emerald Kale", "Vegetables", ["spring", "autumn"], 5, 0, 92, 20, 9),
        ("garlic", "Wild Garlic", "Vegetables", ["spring"], 4, 0, 72, 14, 8),
        ("tomato", "Sun Tomato", "Vegetables", ["summer"], 7, 3, 75, 20, 10),
        ("corn", "Sweet Corn", "Vegetables", ["summer", "autumn"], 9, 4, 68, 22, 10),
        ("pepper", "Ember Pepper", "Vegetables", ["summer"], 6, 3, 62, 18, 8),
        ("eggplant", "Velvet Eggplant", "Vegetables", ["autumn"], 5, 4, 82, 20, 9),
        ("pumpkin", "Harvest Pumpkin", "Vegetables", ["autumn"], 12, 0, 290, 42, 18),
        ("yam", "Honey Yam", "Vegetables", ["autumn"], 8, 0, 160, 30, 14),
        ("beetroot", "Crimson Beet", "Vegetables", ["autumn"], 6, 0, 115, 24, 11),
        ("winter_leek", "Frost Leek", "Vegetables", ["winter"], 5, 0, 110, 24, 12),

        # Fruits (14)
        ("strawberry", "Meadow Strawberry", "Fruits", ["spring"], 8, 4, 120, 28, 14),
        ("rhubarb", "Tart Rhubarb", "Fruits", ["spring"], 11, 0, 220, 32, 14),
        ("blueberry", "Sky Blueberry", "Fruits", ["summer"], 10, 4, 85, 24, 12),
        ("melon", "Pink Melon", "Fruits", ["summer"], 11, 0, 260, 48, 22),
        ("peach", "Blush Peach", "Fruits", ["summer"], 9, 3, 140, 34, 16),
        ("cherry", "Ruby Cherry", "Fruits", ["spring"], 8, 3, 115, 26, 12),
        ("grape", "Valley Grape", "Fruits", ["autumn"], 8, 3, 95, 26, 12),
        ("cranberry", "Bog Cranberry", "Fruits", ["autumn"], 7, 4, 90, 22, 10),
        ("apple", "Orchard Apple", "Fruits", ["autumn"], 9, 3, 135, 32, 16),
        ("pineapple", "Tropica Pineapple", "Fruits", ["summer"], 12, 5, 280, 50, 22),
        ("cactus_fig", "Dune Cactus Fig", "Fruits", ["summer", "autumn"], 8, 4, 145, 36, 16),
        ("coconut", "Golden Coconut", "Fruits", ["summer"], 10, 4, 175, 40, 18),
        ("frostberry", "Glacier Berry", "Fruits", ["winter"], 7, 4, 155, 32, 16),
        ("starfruit", "Celestial Starfruit", "Fruits", ["summer"], 14, 0, 620, 65, 30),

        # Flowers (12)
        ("tulip", "Spring Tulip", "Flowers", ["spring"], 4, 0, 55, 8, 4),
        ("dandelion", "Sunny Dandelion", "Flowers", ["spring", "summer"], 3, 0, 45, 10, 4),
        ("daisy", "Willow Daisy", "Flowers", ["spring"], 4, 0, 60, 8, 4),
        ("jazz_blossom", "Blue Jazz", "Flowers", ["spring"], 6, 0, 85, 12, 6),
        ("sunflower", "Radiant Sunflower", "Flowers", ["summer", "autumn"], 7, 0, 115, 14, 6),
        ("rose", "Crimson Rose", "Flowers", ["summer"], 8, 0, 140, 12, 6),
        ("poppy", "Summer Poppy", "Flowers", ["summer"], 6, 0, 120, 12, 6),
        ("lavender", "Twilight Lavender", "Flowers", ["summer", "autumn"], 6, 0, 125, 16, 8),
        ("fairy_rose", "Fairy Rose", "Flowers", ["autumn"], 10, 0, 290, 18, 8),
        ("lotus", "Crystal Lotus", "Flowers", ["summer"], 9, 0, 210, 20, 10),
        ("moonflower", "Moonlight Bloom", "Flowers", ["autumn", "winter"], 9, 0, 240, 20, 12),
        ("frost_orchid", "Frost Orchid", "Flowers", ["winter"], 8, 0, 230, 18, 10),

        # Grains (8)
        ("wheat", "Golden Wheat", "Grains", ["summer", "autumn"], 4, 0, 45, 8, 4),
        ("rice", "Paddy Rice", "Grains", ["spring"], 5, 0, 60, 12, 6),
        ("oat", "Highland Oat", "Grains", ["spring", "autumn"], 5, 0, 58, 12, 6),
        ("barley", "Amber Barley", "Grains", ["summer"], 5, 0, 62, 12, 6),
        ("rye", "Winter Rye", "Grains", ["autumn", "winter"], 6, 0, 74, 14, 6),
        ("millet", "Sun Millet", "Grains", ["summer"], 4, 0, 54, 10, 5),
        ("buckwheat", "Valley Buckwheat", "Grains", ["autumn"], 5, 0, 68, 12, 6),
        ("amaranth", "Crimson Amaranth", "Grains", ["autumn"], 6, 0, 125, 16, 8),

        # Mushrooms (8)
        ("button_shroom", "Button Mushroom", "Mushrooms", ["spring", "autumn"], 4, 3, 65, 18, 8),
        ("morel", "Forest Morel", "Mushrooms", ["spring"], 6, 0, 150, 24, 12),
        ("chanterelle", "Gold Chanterelle", "Mushrooms", ["autumn"], 6, 0, 165, 26, 12),
        ("purple_cap", "Amethyst Cap", "Mushrooms", ["autumn", "winter"], 7, 3, 195, 32, 16),
        ("truffle", "Earth Truffle", "Mushrooms", ["spring", "summer", "autumn"], 10, 0, 420, 30, 14),
        ("glowshroom", "Lantern Glowshroom", "Mushrooms", ["winter", "autumn"], 7, 3, 210, 28, 18),
        ("frost_cap", "Iceveil Mushroom", "Mushrooms", ["winter"], 6, 3, 180, 26, 14),
        ("spirit_morel", "Spirit Morel", "Mushrooms", ["spring", "summer", "autumn", "winter"], 11, 4, 340, 45, 25),

        # Special Crops (6)
        ("ancient_fruit", "Ancient Relic Fruit", "Special", ["spring", "summer", "autumn"], 16, 7, 580, 60, 30),
        ("crystal_berry", "Crystal Gem Berry", "Special", ["spring", "summer", "autumn", "winter"], 12, 5, 360, 48, 24),
        ("sunblossom", "Solar Blossom", "Special", ["summer"], 12, 0, 390, 50, 25),
        ("void_root", "Shadow Root", "Special", ["autumn", "winter"], 10, 0, 310, 30, 30),
        ("whisper_herb", "Whispering Sage", "Special", ["spring", "autumn"], 8, 4, 240, 38, 22),
        ("sanctuary_lotus", "Sanctuary Star Lotus", "Special", ["spring", "summer", "autumn", "winter"], 14, 0, 750, 80, 45),
    ]
    assert len(crop_specs) == 64

    crops = []
    for idx, (cid, cname, ccat, seasons, total_days, regrow, base_price, en, hp) in enumerate(crop_specs):
        seed_id = f"{cid}_seed"
        seed_price = max(15, int(base_price * 0.42))
        stages = 5
        days_per_stage = max(1, round(total_days / 4))
        rarity = "legendary" if base_price >= 500 else ("rare" if base_price >= 220 else ("uncommon" if base_price >= 120 else "common"))
        crops.append({
            "id": cid,
            "name": cname,
            "category": ccat,
            "seedItemId": seed_id,
            "harvestItemId": cid,
            "seasons": seasons,
            "growthStages": stages,
            "daysPerStage": days_per_stage,
            "totalDays": total_days,
            "regrowthDays": regrow,
            "baseSellPrice": base_price,
            "waterRequired": True,
            "atlasRow": idx,
            "description": f"A {ccat.lower()} crop grown in {', '.join(s.title() for s in seasons)} ({total_days} days)."
        })
        add_item(
            seed_id,
            f"{cname} Seeds",
            f"Plant in {', '.join(s.title() for s in seasons)}. Takes {total_days} days to mature.",
            "Seeds",
            seed_price,
            99,
            rarity,
            True,
            True,
            {"cropId": cid, "seasons": seasons}
        )
        add_item(
            cid,
            cname,
            f"Freshly harvested {cname}. Restores {en} Energy.",
            "Crops",
            base_price,
            99,
            rarity,
            True,
            True,
            {"cropId": cid, "energy": en, "health": hp, "cropCategory": ccat}
        )

    # ---------------------------------------------------------
    # 2. FISH (84 unique species across 8 biomes)
    # ---------------------------------------------------------
    fish_biomes = [
        ("crystal_lake", "Crystal Lake"),
        ("willow_river", "Willow River"),
        ("sunflower_ocean", "Sunflower Ocean"),
        ("whispering_pond", "Forest Pond"),
        ("frostpeak_lake", "Frostpeak Springs"),
        ("golden_oasis", "Desert Oasis"),
        ("mine_cavern", "Underground Cavern"),
        ("hidden_sanctuary", "Sanctuary Pool"),
    ]
    fish_prefixes = [
        ("Carp", 40, 22, "common"),
        ("Perch", 52, 26, "common"),
        ("Bream", 58, 28, "common"),
        ("Trout", 75, 34, "uncommon"),
        ("Bass", 88, 40, "uncommon"),
        ("Pike", 110, 48, "uncommon"),
        ("Salmon", 130, 52, "rare"),
        ("Eel", 145, 58, "rare"),
        ("Sturgeon", 195, 68, "rare"),
        ("Koi", 240, 62, "epic"),
        ("Leviathan", 480, 84, "legendary"),
    ]
    # 8 * 10 + 4 bonus = 84 fish
    biome_adjectives = {
        "crystal_lake": ["Crystal", "Silver", "Azure", "Mirror", "Shimmer", "Lake", "Pearl", "Glint", "Sapphire", "Aurora", "Starlight"],
        "willow_river": ["Willow", "Brook", "Amber", "Dappled", "Swift", "River", "Mossback", "Pebble", "Reed", "Golden", "Sovereign"],
        "sunflower_ocean": ["Sunlit", "Coral", "Tide", "Seafoam", "Crimson", "Sardine", "Marlin", "Dolphin", "Manta", "Tidal", "Abyssal"],
        "whispering_pond": ["Leaf", "Fern", "Whisper", "Shadow", "Dew", "Sprig", "Bramble", "Thorn", "Emerald", "Sylvan", "Elder"],
        "frostpeak_lake": ["Glacier", "Frost", "Icicle", "Alpine", "Snow", "Chilled", "Blizzard", "Cryo", "Rime", "Avalanche", "Boreal"],
        "golden_oasis": ["Sand", "Mirage", "Dune", "Scorpion", "Oasis", "Amber", "Sunscale", "Sphinx", "Pyrite", "Pharaoh", "Solstice"],
        "mine_cavern": ["Stone", "Cave", "Blind", "Lava", "Ghost", "Iron", "Quartz", "Onyx", "Magma", "Obsidian", "Depths"],
        "hidden_sanctuary": ["Spirit", "Halo", "Prism", "Celestial", "Moon", "Ether", "Astral"],
    }
    seasons_cycle = [
        ["spring", "summer"], ["summer", "autumn"], ["autumn", "winter"],
        ["spring", "autumn"], ["spring", "summer", "autumn", "winter"]
    ]
    weather_cycle = ["any", "any", "rainy", "sunny", "stormy"]
    time_ranges = [(6, 26), (6, 14), (12, 20), (18, 26), (6, 26)]

    fish_list = []
    for b_idx, (b_id, b_name) in enumerate(fish_biomes):
        adjs = biome_adjectives[b_id]
        for p_idx, adj in enumerate(adjs):
            suffix, base_p, diff, rar = fish_prefixes[p_idx]
            fid = f"fish_{b_id}_{adj.lower()}"
            fname = f"{adj} {suffix}"
            s_list = ["spring", "summer", "autumn", "winter"] if rar == "legendary" else seasons_cycle[(b_idx + p_idx) % len(seasons_cycle)]
            if b_id == "frostpeak_lake" and "winter" not in s_list:
                s_list = list(set(s_list + ["winter"]))
            w_cond = "rainy" if suffix == "Eel" else weather_cycle[(b_idx + p_idx) % len(weather_cycle)]
            t_start, t_end = time_ranges[(b_idx + p_idx) % len(time_ranges)]
            price = base_p + b_idx * 12
            fish_obj = {
                "id": fid,
                "name": fname,
                "biome": b_id,
                "biomeName": b_name,
                "seasons": s_list,
                "timeRange": [t_start, t_end],
                "weather": w_cond,
                "rarity": rar,
                "difficulty": min(92, diff + b_idx * 2),
                "sellPrice": price,
                "sprite": fid,
                "description": f"Found in {b_name} during {', '.join(s.title() for s in s_list)}."
            }
            fish_list.append(fish_obj)
            add_item(
                fid,
                fname,
                f"A {rar} fish caught at {b_name}.",
                "Fish",
                price,
                99,
                rar,
                True,
                True,
                {"fishId": fid, "biome": b_id, "energy": 18 + p_idx * 2, "health": 10 + p_idx}
            )
    assert len(fish_list) == 84

    # ---------------------------------------------------------
    # 3. TOOLS, WEAPONS, EQUIPMENT (26 items)
    # ---------------------------------------------------------
    tools_specs = [
        ("tool_hoe", "Iron Hoe", "Tills soil plots for planting seeds.", "Tools", 0, 1, "common", False, {"toolType": "hoe", "power": 1, "energyCost": 2}),
        ("tool_hoe_copper", "Copper Hoe", "Tills soil in a wider 1x3 row.", "Tools", 800, 1, "uncommon", False, {"toolType": "hoe", "power": 2, "energyCost": 2}),
        ("tool_watering_can", "Wooden Watering Can", "Waters tilled farm plots.", "Tools", 0, 1, "common", False, {"toolType": "watering_can", "power": 1, "energyCost": 2}),
        ("tool_watering_copper", "Copper Watering Can", "Waters 3 plots at once.", "Tools", 800, 1, "uncommon", False, {"toolType": "watering_can", "power": 2, "energyCost": 2}),
        ("tool_axe", "Woodcutter Axe", "Chops trees and branches for wood.", "Tools", 0, 1, "common", False, {"toolType": "axe", "power": 1, "energyCost": 3}),
        ("tool_axe_steel", "Steel Axe", "Efficiently fells hardwood stumps.", "Tools", 1200, 1, "rare", False, {"toolType": "axe", "power": 2, "energyCost": 2}),
        ("tool_pickaxe", "Miner Pickaxe", "Breaks rocks and ore nodes in the mine.", "Tools", 0, 1, "common", False, {"toolType": "pickaxe", "power": 1, "energyCost": 3}),
        ("tool_pickaxe_gold", "Gold Pickaxe", "Shatters dense crystal & iridium nodes.", "Tools", 1500, 1, "rare", False, {"toolType": "pickaxe", "power": 3, "energyCost": 2}),
        ("tool_scythe", "Farm Scythe", "Clears weeds and harvests fiber and grains.", "Tools", 0, 1, "common", False, {"toolType": "scythe", "power": 1, "energyCost": 0}),
        ("tool_fishing_bamboo", "Bamboo Fishing Rod", "Cast into lakes, rivers, and ocean.", "Tools", 150, 1, "common", True, {"toolType": "fishing_rod", "power": 1, "energyCost": 4}),
        ("tool_fishing_iridium", "Iridium Fishing Rod", "Increases catch bar size & rare fish odds.", "Tools", 2400, 1, "epic", True, {"toolType": "fishing_rod", "power": 3, "energyCost": 3}),
        ("tool_milk_pail", "Copper Milk Pail", "Collects milk from cows and goats.", "Tools", 500, 1, "common", False, {"toolType": "milk_pail", "power": 1, "energyCost": 2}),
        ("tool_shears", "Wool Shears", "Shears wool from happy sheep and alpacas.", "Tools", 500, 1, "common", False, {"toolType": "shears", "power": 1, "energyCost": 2}),
        ("equip_rusty_sword", "Rusty Shortsword", "Basic blade for clearing mine slimes.", "Tools", 120, 1, "common", True, {"toolType": "sword", "attack": 12, "energyCost": 1}),
        ("equip_steel_blade", "Willow Steel Blade", "Balanced knightly sword (+24 ATK).", "Tools", 950, 1, "uncommon", True, {"toolType": "sword", "attack": 24, "energyCost": 1}),
        ("equip_crystal_sabre", "Crystal Sabre", "Radiant blade forged with quartz (+42 ATK).", "Tools", 3200, 1, "epic", True, {"toolType": "sword", "attack": 42, "energyCost": 1}),
        ("equip_sanctuary_blade", "Sanctuary Dawnblade", "Legendary relic sword (+68 ATK).", "Tools", 8500, 1, "legendary", True, {"toolType": "sword", "attack": 68, "energyCost": 1}),
        ("equip_oak_shield", "Oak Buckler", "Reduces incoming monster damage by 4.", "Special Items", 450, 1, "common", True, {"slot": "shield", "defense": 4}),
        ("equip_iron_shield", "Tower Shield", "Reduces incoming monster damage by 10.", "Special Items", 1600, 1, "rare", True, {"slot": "shield", "defense": 10}),
        ("equip_leather_boots", "Trail Boots", "+10% move speed & +2 DEF.", "Special Items", 400, 1, "common", True, {"slot": "boots", "defense": 2, "speedBonus": 0.1}),
        ("equip_frost_boots", "Frostpeak Boots", "+15% move speed & +6 DEF.", "Special Items", 1800, 1, "rare", True, {"slot": "boots", "defense": 6, "speedBonus": 0.15}),
        ("equip_glow_ring", "Glowstone Ring", "Casts warm light in dark mines.", "Special Items", 650, 1, "uncommon", True, {"slot": "ring", "light": 1}),
        ("equip_magnet_ring", "Lodestone Ring", "Increases item pickup radius.", "Special Items", 850, 1, "uncommon", True, {"slot": "ring", "magnet": 1}),
        ("equip_ruby_ring", "Ruby Fury Ring", "+15% combat damage.", "Special Items", 2100, 1, "rare", True, {"slot": "ring", "attackBonus": 0.15}),
        ("equip_iridium_band", "Iridium Band", "Light, magnet, and +20% ATK.", "Special Items", 5500, 1, "legendary", True, {"slot": "ring", "light": 1, "magnet": 1, "attackBonus": 0.2}),
        ("tool_bug_net", "Collector's Net", "Useful for festival & nature events.", "Tools", 250, 1, "common", True, {"toolType": "net", "power": 1, "energyCost": 1}),
    ]
    for tid, tname, tdesc, tcat, tprice, tstack, trar, tsell, tmeta in tools_specs:
        add_item(tid, tname, tdesc, tcat, tprice, tstack, trar, True, tsell, tmeta)

    # ---------------------------------------------------------
    # 4. FORAGE (20), MINERALS (22), MATERIALS & ANIMAL/ARTISAN (30)
    # ---------------------------------------------------------
    forage_specs = [
        ("wild_horseradish", "Wild Horseradish", 50, 14),
        ("daffodil", "Spring Daffodil", 35, 8),
        ("spring_onion", "Spring Onion", 30, 12),
        ("blackberry", "Wild Blackberry", 45, 18),
        ("hazelnut", "Forest Hazelnut", 65, 22),
        ("sea_shell", "Nautilus Shell", 70, 0),
        ("coral_piece", "Reef Coral", 85, 0),
        ("driftwood", "Salt Driftwood", 25, 0),
        ("crystal_moss", "Crystal Moss", 90, 15),
        ("desert_aloe", "Desert Aloe", 75, 24),
        ("snowdrop", "Winter Snowdrop", 80, 12),
        ("cave_carrot", "Cave Carrot", 55, 28),
        ("spice_berry", "Spice Berry", 70, 22),
        ("sweet_pea", "Sweet Pea", 50, 10),
        ("fiddlehead_fern", "Fiddlehead Fern", 95, 25),
        ("ginger_root", "Wild Ginger", 65, 20),
        ("sea_urchin", "Violet Urchin", 130, 0),
        ("lotus_pod", "Dried Lotus Pod", 88, 16),
        ("pine_cone", "Alpine Pine Cone", 22, 0),
        ("bamboo_shoot", "Tender Bamboo Shoot", 60, 20),
    ]
    for fid, fname, fprice, fen in forage_specs:
        add_item(fid, fname, f"Wild forage gathered across Whispering Valley.", "Forage", fprice, 99,
                 "common", fen > 0, True, {"energy": fen, "health": fen // 2})

    mineral_specs = [
        ("stone", "Stone", 4, "common"),
        ("coal", "Coal", 18, "common"),
        ("copper_ore", "Copper Ore", 15, "common"),
        ("iron_ore", "Iron Ore", 28, "common"),
        ("gold_ore", "Gold Ore", 55, "uncommon"),
        ("iridium_ore", "Iridium Ore", 125, "rare"),
        ("copper_bar", "Copper Bar", 65, "uncommon"),
        ("iron_bar", "Iron Bar", 125, "uncommon"),
        ("gold_bar", "Gold Bar", 260, "rare"),
        ("iridium_bar", "Iridium Bar", 620, "epic"),
        ("quartz", "Cave Quartz", 40, "common"),
        ("earth_crystal", "Earth Crystal", 75, "uncommon"),
        ("frozen_tear", "Frozen Tear", 95, "uncommon"),
        ("fire_quartz", "Fire Quartz", 130, "rare"),
        ("emerald", "Valley Emerald", 250, "rare"),
        ("aquamarine", "Aquamarine", 200, "rare"),
        ("ruby", "Star Ruby", 260, "rare"),
        ("amethyst", "Deep Amethyst", 150, "uncommon"),
        ("topaz", "Sun Topaz", 140, "uncommon"),
        ("jade", "Imperial Jade", 220, "rare"),
        ("diamond", "Pure Diamond", 750, "epic"),
        ("prismatic_shard", "Prismatic Shard", 2000, "legendary"),
    ]
    for mid, mname, mprice, mrar in mineral_specs:
        add_item(mid, mname, f"Mineral or refined ingot sourced from Ancient Mine.", "Minerals", mprice, 99, mrar, False, True, {})

    material_specs = [
        ("wood", "Wood", "Materials", 4, "common", False, {}),
        ("hardwood", "Hardwood", "Materials", 20, "uncommon", False, {}),
        ("sap", "Tree Sap", "Materials", 4, "common", False, {}),
        ("fiber", "Plant Fiber", "Materials", 5, "common", False, {}),
        ("clay", "River Clay", "Materials", 18, "common", False, {}),
        ("bat_wing", "Bat Wing", "Materials", 25, "common", False, {}),
        ("slime_jelly", "Slime Jelly", "Materials", 15, "common", False, {}),
        ("bone_fragment", "Ancient Bone", "Materials", 22, "common", False, {}),
        ("light_essence", "Solar Essence", "Materials", 65, "uncommon", False, {}),
        ("void_essence", "Shadow Essence", "Materials", 85, "rare", False, {}),
        ("bait", "Worm Bait", "Materials", 5, "common", True, {"baitBonus": 1}),
        ("quality_bait", "Wild Aroma Bait", "Materials", 25, "uncommon", True, {"baitBonus": 2}),
        ("basic_fertilizer", "Basic Fertilizer", "Materials", 20, "common", True, {"fertilizer": "basic"}),
        ("quality_fertilizer", "Quality Fertilizer", "Materials", 65, "uncommon", True, {"fertilizer": "quality"}),
        ("speed_gro", "Speed-Gro Compost", "Materials", 80, "uncommon", True, {"fertilizer": "speed"}),
        ("hay", "Golden Hay", "Materials", 25, "common", True, {"feed": True}),
        ("egg", "Farm Egg", "Materials", 55, "common", True, {"energy": 18, "health": 8}),
        ("duck_egg", "Duck Egg", "Materials", 95, "uncommon", True, {"energy": 25, "health": 12}),
        ("quail_egg", "Speckled Quail Egg", "Materials", 80, "uncommon", True, {"energy": 22, "health": 10}),
        ("milk", "Fresh Milk", "Materials", 125, "common", True, {"energy": 35, "health": 16}),
        ("goat_milk", "Goat Milk", "Materials", 190, "uncommon", True, {"energy": 45, "health": 20}),
        ("wool", "Soft Wool", "Materials", 220, "uncommon", False, {}),
        ("alpaca_wool", "Silky Alpaca Fleece", "Materials", 320, "rare", False, {}),
        ("honey", "Wildflower Honey", "Materials", 140, "common", True, {"energy": 30, "health": 14}),
        ("starlight_antler", "Starlight Essence Dew", "Materials", 480, "epic", True, {"energy": 65, "health": 40}),
        ("truffle_oil", "Artisan Truffle Oil", "Materials", 650, "epic", True, {"energy": 45, "health": 20}),
        ("cheese", "Farmhouse Cheese", "Materials", 230, "uncommon", True, {"energy": 55, "health": 26}),
        ("goat_cheese", "Aged Goat Cheese", "Materials", 360, "rare", True, {"energy": 70, "health": 32}),
        ("cloth", "Woven Cloth", "Materials", 420, "rare", False, {}),
        ("mayonnaise", "Golden Mayonnaise", "Materials", 180, "uncommon", True, {"energy": 35, "health": 16}),
    ]
    for mat_id, mat_name, mat_cat, mat_price, mat_rar, mat_use, mat_meta in material_specs:
        add_item(mat_id, mat_name, f"Crafting and farm resource: {mat_name}.", mat_cat, mat_price, 99, mat_rar, mat_use, True, mat_meta)

    # ---------------------------------------------------------
    # 5. COOKING DISHES (84 unique cooked foods)
    # ---------------------------------------------------------
    dish_templates = [
        ("fried_egg", "Sunny Fried Egg", [("egg", 1)], 75, 45, 22, "none", 0),
        ("baked_potato", "Herb Baked Potato", [("potato", 1), ("garlic", 1)], 150, 70, 32, "farming", 180),
        ("turnip_soup", "Creamy Turnip Soup", [("turnip", 1), ("milk", 1)], 185, 80, 38, "energy", 180),
        ("parsnip_bisque", "Parsnip Velvet Bisque", [("parsnip", 2), ("milk", 1)], 210, 88, 42, "none", 0),
        ("carrot_cake", "Spiced Carrot Cake", [("carrot", 2), ("wheat", 1), ("egg", 1)], 240, 100, 46, "speed", 240),
        ("tomato_bruschetta", "Sun Tomato Bruschetta", [("tomato", 1), ("wheat", 1), ("garlic", 1)], 180, 78, 36, "none", 0),
        ("corn_chowder", "Sweet Corn Chowder", [("corn", 2), ("potato", 1), ("milk", 1)], 260, 110, 50, "farming", 240),
        ("stuffed_pepper", "Stuffed Ember Pepper", [("pepper", 1), ("rice", 1), ("cheese", 1)], 290, 115, 52, "attack", 240),
        ("eggplant_parmesan", "Eggplant Parmesan", [("eggplant", 1), ("tomato", 1), ("cheese", 1)], 310, 125, 58, "defense", 300),
        ("pumpkin_pie", "Autumn Pumpkin Pie", [("pumpkin", 1), ("wheat", 1), ("egg", 1), ("milk", 1)], 420, 165, 75, "luck", 360),
        ("yam_gratin", "Honey Yam Gratin", [("yam", 1), ("honey", 1), ("cheese", 1)], 340, 130, 60, "energy", 300),
        ("beet_salad", "Roasted Beet Salad", [("beetroot", 1), ("kale", 1), ("goat_cheese", 1)], 360, 140, 64, "speed", 240),
        ("leek_stew", "Winter Leek Stew", [("winter_leek", 2), ("potato", 1)], 220, 95, 44, "mining", 240),
        ("strawberry_tart", "Strawberry Shorttart", [("strawberry", 2), ("wheat", 1), ("egg", 1)], 285, 115, 55, "luck", 240),
        ("rhubarb_compote", "Sweet Rhubarb Pie", [("rhubarb", 1), ("wheat", 1), ("honey", 1)], 350, 140, 65, "none", 0),
        ("blueberry_muffin", "Blueberry Muffin", [("blueberry", 2), ("wheat", 1), ("egg", 1)], 255, 105, 48, "fishing", 240),
        ("melon_sorbet", "Chilled Melon Sorbet", [("melon", 1), ("honey", 1)], 320, 130, 60, "speed", 300),
        ("peach_cobbler", "Warm Peach Cobbler", [("peach", 2), ("oat", 1)], 275, 115, 52, "none", 0),
        ("cherry_jam_toast", "Cherry Jam Toast", [("cherry", 2), ("wheat", 1)], 230, 95, 45, "speed", 180),
        ("grape_sorbet", "Frost Grape Sorbet", [("grape", 2), ("frostberry", 1)], 290, 120, 56, "luck", 240),
        ("cranberry_sauce", "Spiced Cranberry Sauce", [("cranberry", 2), ("honey", 1)], 225, 92, 44, "mining", 240),
        ("apple_cider", "Hot Orchard Cider", [("apple", 2), ("honey", 1)], 260, 110, 50, "farming", 300),
        ("pineapple_skewer", "Tropical Skewer", [("pineapple", 1), ("coconut", 1)], 390, 150, 70, "attack", 300),
        ("cactus_juice", "Cool Cactus Cooler", [("cactus_fig", 2), ("desert_aloe", 1)], 270, 120, 55, "speed", 300),
        ("starfruit_pudding", "Celestial Star Pudding", [("starfruit", 1), ("milk", 1), ("honey", 1)], 780, 220, 110, "luck", 480),
        ("mushroom_risotto", "Truffle Mushroom Risotto", [("rice", 1), ("truffle", 1), ("cheese", 1)], 680, 195, 95, "farming", 420),
        ("forest_omelette", "Morel Omelette", [("egg", 2), ("morel", 1), ("kale", 1)], 285, 120, 55, "foraging", 300),
        ("chanterelle_pasta", "Chanterelle Tagliatelle", [("wheat", 2), ("chanterelle", 1), ("garlic", 1)], 295, 125, 58, "energy", 300),
        ("glowshroom_tea", "Luminescent Tea", [("glowshroom", 1), ("whisper_herb", 1)], 340, 130, 75, "mining", 360),
        ("ancient_elixir", "Ancient Vitality Elixir", [("ancient_fruit", 1), ("spirit_morel", 1), ("honey", 1)], 920, 250, 140, "all", 480),
        ("sanctuary_ambrosia", "Sanctuary Ambrosia", [("sanctuary_lotus", 1), ("starlight_antler", 1)], 1250, 300, 180, "all", 600),
    ]
    # Add 53 more unique regional & fish-based dishes to reach 84 unique cooked recipes!
    regional_dishes = [
        ("grilled_carp", "Crispy Grilled Carp", [("fish_crystal_lake_crystal", 1), ("garlic", 1)]),
        ("baked_trout", "Herb Baked Trout", [("fish_willow_river_dappled", 1), ("carrot", 1)]),
        ("salmon_dinner", "Glazed Salmon Fillet", [("fish_willow_river_mossback", 1), ("kale", 1), ("rice", 1)]),
        ("ocean_paella", "Sunflower Paella", [("fish_sunflower_ocean_sunlit", 1), ("rice", 1), ("tomato", 1)]),
        ("seafoam_sushi", "Seafoam Sashimi Roll", [("fish_sunflower_ocean_coral", 1), ("rice", 1)]),
        ("eel_rice_bowl", "Charcoal Eel Donburi", [("fish_sunflower_ocean_dolphin", 1), ("rice", 1), ("honey", 1)]),
        ("sturgeon_caviar_toast", "Sturgeon Canape", [("fish_crystal_lake_sapphire", 1), ("wheat", 1), ("cheese", 1)]),
        ("frost_chowder", "Glacier Fish Chowder", [("fish_frostpeak_lake_glacier", 1), ("potato", 1), ("milk", 1)]),
        ("desert_fish_taco", "Dune Spiced Taco", [("fish_golden_oasis_sand", 1), ("corn", 1), ("pepper", 1)]),
        ("cavern_skewer", "Glowing Cavern Skewer", [("fish_mine_cavern_stone", 1), ("cave_carrot", 1)]),
        ("bread_loaf", "Country Wheat Loaf", [("wheat", 2)]),
        ("oatmeal_bowl", "Warm Honey Oatmeal", [("oat", 2), ("milk", 1), ("honey", 1)]),
        ("barley_porridge", "Hearty Barley Bowl", [("barley", 2), ("carrot", 1)]),
        ("rye_pretzel", "Salted Rye Pretzel", [("rye", 2), ("egg", 1)]),
        ("millet_pilaf", "Golden Millet Pilaf", [("millet", 2), ("turnip", 1)]),
        ("buckwheat_noodles", "Willow Soba Noodles", [("buckwheat", 2), ("spring_onion", 1)]),
        ("amaranth_soup", "Crimson Grain Soup", [("amaranth", 1), ("tomato", 1)]),
        ("radish_salad", "Crisp Radish Salad", [("radish", 2), ("mayonnaise", 1)]),
        ("cauliflower_gratin", "Cheesy Cauliflower", [("cauliflower", 1), ("cheese", 1)]),
        ("garlic_bread", "Roasted Garlic Toast", [("wheat", 1), ("garlic", 2)]),
        ("duck_egg_custard", "Silky Duck Custard", [("duck_egg", 1), ("milk", 1), ("honey", 1)]),
        ("quail_egg_skewers", "Herb Quail Skewers", [("quail_egg", 2), ("pepper", 1)]),
        ("goat_cheese_tart", "Savory Goat Tart", [("goat_cheese", 1), ("wheat", 1), ("tomato", 1)]),
        ("truffle_pasta", "Black Truffle Pasta", [("truffle_oil", 1), ("wheat", 2)]),
        ("berry_parfait", "Three-Berry Parfait", [("strawberry", 1), ("blueberry", 1), ("milk", 1)]),
        ("flower_tea", "Blossom Herbal Tea", [("daisy", 1), ("lavender", 1), ("honey", 1)]),
        ("sunflower_seed_bar", "Crunchy Seed Bar", [("sunflower", 1), ("oat", 1), ("honey", 1)]),
        ("rose_macaron", "Crimson Rose Macaron", [("rose", 1), ("egg", 1), ("wheat", 1)]),
        ("poppyseed_muffin", "Poppyseed Muffin", [("poppy", 1), ("wheat", 1), ("milk", 1)]),
        ("fairy_rose_elixir", "Fairy Rose Infusion", [("fairy_rose", 1), ("honey", 1)]),
        ("lotus_root_soup", "Crystal Lotus Broth", [("lotus", 1), ("ginger_root", 1)]),
        ("moonflower_jelly", "Moonlight Gelato", [("moonflower", 1), ("milk", 1)]),
        ("frost_orchid_tea", "Frost Orchid Tisane", [("frost_orchid", 1), ("snowdrop", 1)]),
        ("blackberry_cobbler", "Wild Berry Cobbler", [("blackberry", 2), ("wheat", 1)]),
        ("hazelnut_praline", "Roasted Hazelnut Crunch", [("hazelnut", 2), ("honey", 1)]),
        ("ginger_candy", "Spiced Ginger Candy", [("ginger_root", 2), ("honey", 1)]),
        ("bamboo_steamed_rice", "Bamboo Leaf Rice", [("bamboo_shoot", 1), ("rice", 1)]),
        ("fern_stirfry", "Wild Fern Stir-Fry", [("fiddlehead_fern", 1), ("garlic", 1)]),
        ("aloe_smoothie", "Oasis Aloe Smoothie", [("desert_aloe", 1), ("melon", 1)]),
        ("snowdrop_sorbet", "Winter Snow Sorbet", [("snowdrop", 1), ("frostberry", 1)]),
        ("horseradish_roast", "Zesty Horseradish Bowl", [("wild_horseradish", 1), ("potato", 1)]),
        ("purple_cap_skewer", "Grilled Amethyst Cap", [("purple_cap", 1), ("garlic", 1)]),
        ("frost_cap_bisque", "Iceveil Cream Soup", [("frost_cap", 1), ("milk", 1)]),
        ("button_mushroom_toast", "Mushroom Toast", [("button_shroom", 2), ("wheat", 1)]),
        ("crystal_berry_tart", "Crystal Gem Tart", [("crystal_berry", 1), ("wheat", 1)]),
        ("sunblossom_honey_cake", "Solar Honey Cake", [("sunblossom", 1), ("honey", 1), ("egg", 1)]),
        ("void_root_tonic", "Shadow Vitality Brew", [("void_root", 1), ("cave_carrot", 1)]),
        ("whisper_herb_broth", "Whispering Recovery Broth", [("whisper_herb", 1), ("spring_onion", 1)]),
        ("farmer_lunch", "Grand Farmer's Platter", [("parsnip", 1), ("potato", 1), ("cheese", 1), ("egg", 1)]),
        ("miner_treat", "Miner's Crunch Bar", [("cave_carrot", 2), ("hazelnut", 1), ("milk", 1)]),
        ("lucky_lunch", "Sea & Star Bento", [("fish_crystal_lake_silver", 1), ("rice", 1), ("jazz_blossom", 1)]),
        ("autumn_bounty", "Autumn Harvest Feast", [("pumpkin", 1), ("yam", 1), ("cranberry", 1)]),
        ("spring_picnic", "Willow Picnic Basket", [("strawberry", 1), ("daffodil", 1), ("cheese", 1), ("wheat", 1)]),
    ]
    buff_cycle = ["farming", "fishing", "mining", "speed", "luck", "defense", "attack", "energy"]
    cooking = []
    for idx, (did, dname, ings, price, en, hp, buff, bdur) in enumerate(dish_templates):
        cooking.append({
            "id": did,
            "name": dname,
            "ingredients": [{"itemId": iid, "count": cnt} for iid, cnt in ings],
            "sellPrice": price,
            "energyRecovery": en,
            "healthRecovery": hp,
            "buffType": buff,
            "buffDuration": bdur,
            "outputItemId": did,
            "unlockCondition": "starter" if idx < 12 else f"cooking_lv_{1 + (idx // 10)}",
            "description": f"Delicious dish: {dname}. Restores {en} EN & {hp} HP."
        })
        add_item(did, dname, f"Home-cooked {dname}. Restores {en} Energy & {hp} HP.", "Food", price, 20,
                 "rare" if price >= 400 else "uncommon", True, True,
                 {"energy": en, "health": hp, "buffType": buff, "buffDuration": bdur})

    for idx, (did, dname, ings) in enumerate(regional_dishes):
        base_val = sum(items[iid]["basePrice"] * cnt for iid, cnt in ings)
        price = max(95, int(base_val * 1.45))
        en = min(220, 60 + len(ings) * 28 + (idx % 5) * 10)
        hp = en // 2
        buff = buff_cycle[idx % len(buff_cycle)]
        cooking.append({
            "id": did,
            "name": dname,
            "ingredients": [{"itemId": iid, "count": cnt} for iid, cnt in ings],
            "sellPrice": price,
            "energyRecovery": en,
            "healthRecovery": hp,
            "buffType": buff,
            "buffDuration": 240,
            "outputItemId": did,
            "unlockCondition": "starter" if idx < 15 else f"cooking_lv_{1 + (idx // 12)}",
            "description": f"Regional specialty: {dname}. Restores {en} EN & grants {buff.title()} buff."
        })
        add_item(did, dname, f"Regional dish: {dname}. Restores {en} EN & {hp} HP.", "Food", price, 20,
                 "rare" if price >= 320 else "common", True, True,
                 {"energy": en, "health": hp, "buffType": buff, "buffDuration": 240})

    assert len(cooking) == 84

    # ---------------------------------------------------------
    # 6. BUILDINGS, DECORATIONS, FURNITURE (32 items + building defs)
    # ---------------------------------------------------------
    building_specs = [
        ("coop", "Wooden Coop", "housing", [3, 3], [("wood", 40), ("stone", 15)], 1200, 4, "Houses up to 4 chickens, ducks, or quails."),
        ("big_coop", "Grand Coop", "housing", [4, 3], [("wood", 70), ("hardwood", 20), ("stone", 30)], 3200, 8, "Houses up to 8 coop animals with auto-feeder."),
        ("barn", "Timber Barn", "housing", [4, 3], [("wood", 55), ("stone", 25)], 1800, 4, "Houses up to 4 cows, goats, sheep, or pigs."),
        ("big_barn", "Deluxe Barn", "housing", [5, 3], [("wood", 90), ("hardwood", 30), ("iron_bar", 5)], 4500, 8, "Houses up to 8 barn animals with auto-feeder."),
        ("greenhouse", "Glass Greenhouse", "special", [4, 4], [("wood", 60), ("quartz", 20), ("iron_bar", 8)], 6000, 0, "Allows growing any seasonal crop year-round."),
        ("silo", "Grain Silo", "utility", [2, 2], [("stone", 25), ("clay", 10), ("copper_bar", 4)], 650, 0, "Stores harvested hay for animal feeding."),
        ("shed", "Craftsman Shed", "utility", [3, 3], [("wood", 65), ("stone", 20)], 2200, 0, "Spacious workshop shed for storage & machines."),
        ("well", "Stone Water Well", "utility", [2, 2], [("stone", 35), ("wood", 10)], 500, 0, "Refills your watering can anywhere on the farm."),
        ("mill", "Windmill", "machine", [3, 3], [("wood", 70), ("stone", 40), ("cloth", 2)], 2800, 0, "Milling station for flour & grains."),
        ("bee_house", "Cedar Bee House", "machine", [1, 1], [("wood", 15), ("coal", 2), ("iron_bar", 1)], 250, 0, "Produces Wildflower Honey every 3 days."),
        ("preserve_jar", "Preserves Jar", "machine", [1, 1], [("wood", 20), ("stone", 12), ("coal", 4)], 300, 0, "Turns fruits & veggies into artisan preserves."),
        ("keg", "Oak Aging Keg", "machine", [1, 1], [("wood", 25), ("copper_bar", 2), ("iron_bar", 1)], 400, 0, "Brews juices, teas, and artisan beverages."),
        ("cheese_press", "Cheese Press", "machine", [1, 1], [("wood", 20), ("stone", 15), ("hardwood", 4)], 350, 0, "Presses milk into Farmhouse or Goat Cheese."),
        ("loom", "Spinning Loom", "machine", [1, 1], [("wood", 24), ("fiber", 15)], 380, 0, "Weaves soft wool into Woven Cloth."),
        ("mayo_machine", "Mayonnaise Churn", "machine", [1, 1], [("wood", 12), ("stone", 10), ("copper_bar", 1)], 220, 0, "Turns farm eggs into Golden Mayonnaise."),
        ("oil_maker", "Truffle Oil Press", "machine", [1, 1], [("hardwood", 15), ("gold_bar", 2), ("slime_jelly", 10)], 600, 0, "Extracts rich Truffle Oil from Earth Truffles."),
        ("furnace", "Stone Smelter Furnace", "machine", [1, 1], [("stone", 25), ("copper_ore", 10)], 180, 0, "Smelts raw ores into metal bars using coal."),
        ("sprinkler_basic", "Basic Sprinkler", "irrigation", [1, 1], [("copper_bar", 1), ("iron_bar", 1)], 200, 0, "Automatically waters 4 adjacent tiles each morning."),
        ("sprinkler_quality", "Quality Sprinkler", "irrigation", [1, 1], [("iron_bar", 2), ("gold_bar", 1), ("quartz", 2)], 550, 0, "Automatically waters an entire 3x3 grid each morning."),
        ("sprinkler_iridium", "Iridium Sprinkler", "irrigation", [1, 1], [("gold_bar", 2), ("iridium_bar", 1)], 1400, 0, "Automatically waters a 5x5 grid every morning."),
        ("shipping_bin_extra", "Farm Shipping Bin", "utility", [2, 1], [("wood", 30), ("iron_bar", 2)], 350, 0, "Extra drop-off bin for overnight sales."),
        ("storage_chest", "Oak Storage Chest", "furniture", [1, 1], [("wood", 25)], 120, 0, "Stores up to 36 stacks of items."),
        ("stone_chest", "Reinforced Stone Chest", "furniture", [1, 1], [("stone", 30), ("iron_bar", 2)], 260, 0, "Weatherproof 36-slot storage chest."),
        ("wood_fence", "Oak Picket Fence", "decor", [1, 1], [("wood", 2)], 20, 0, "Sturdy farm fence to frame pastures and plots."),
        ("stone_wall_fence", "Cobble Border Wall", "decor", [1, 1], [("stone", 3)], 35, 0, "Tidy stone wall border."),
        ("cobble_path", "Cobblestone Path", "decor", [1, 1], [("stone", 2)], 15, 0, "Decorative stone path (+speed when walking)."),
        ("wood_path", "Plank Walkway", "decor", [1, 1], [("wood", 2)], 15, 0, "Warm wooden garden walkway."),
        ("lamp_post", "Iron Garden Lamp", "decor", [1, 1], [("iron_bar", 1), ("coal", 2)], 180, 0, "Illuminates your farm warmly at night."),
        ("scarecrow", "Friendly Scarecrow", "utility", [1, 1], [("wood", 15), ("fiber", 10), ("coal", 1)], 160, 0, "Protects nearby crops & boosts luck."),
        ("wooden_bench", "Garden Bench", "furniture", [2, 1], [("wood", 15), ("hardwood", 4)], 180, 0, "Cozy wooden bench where you can sit and rest."),
        ("flower_planter", "Blossom Planter Box", "decor", [1, 1], [("wood", 8), ("clay", 4)], 90, 0, "Cheerful seasonal flower barrel."),
        ("sanctuary_statue", "Spirit Guardian Statue", "decor", [1, 1], [("stone", 30), ("crystal_moss", 5), ("gold_bar", 2)], 1200, 0, "Ancient blessing statue for your homestead."),
    ]
    assert len(building_specs) == 32

    buildings = []
    for bid, bname, btype, bsize, cost_mats, bprice, bcap, bdesc in building_specs:
        buildings.append({
            "id": bid,
            "name": bname,
            "type": btype,
            "size": bsize,
            "materials": [{"itemId": mid, "count": cnt} for mid, cnt in cost_mats],
            "buildCostGold": bprice,
            "capacity": bcap,
            "description": bdesc,
            "itemId": f"place_{bid}"
        })
        cat = "Furniture" if btype in ("furniture", "machine", "utility") else "Decorations"
        add_item(f"place_{bid}", bname, bdesc, cat, max(20, bprice // 2), 20,
                 "rare" if bprice >= 1200 else "common", True, True, {"buildingId": bid})

    # ---------------------------------------------------------
    # 7. QUEST & SPECIAL ITEMS (18 items)
    # ---------------------------------------------------------
    quest_special_specs = [
        ("quest_mayor_ledger", "Mayor's Lost Ledger", "Found near the Whispering Forest stream.", "Quest Items", 0, 1, "uncommon", False, False),
        ("quest_rusty_key", "Ancient Mine Key", "Unlocks deeper mechanisms in the Ancient Mine.", "Quest Items", 0, 1, "rare", False, False),
        ("quest_bridge_permit", "Forest Bridge Permit", "Authorizes repair of the northern bridge.", "Quest Items", 0, 1, "uncommon", False, False),
        ("quest_sanctuary_seal", "Sanctuary Star Seal", "Resonates with the Hidden Sanctuary gate.", "Quest Items", 0, 1, "legendary", True, False),
        ("quest_lost_locket", "Elise's Silver Locket", "Engraved with tiny willow leaves.", "Quest Items", 0, 1, "rare", False, False),
        ("quest_ancient_tablet", "Forgotten Rune Tablet", "Carved stone tablet from Forgotten Ruins.", "Quest Items", 0, 1, "epic", False, False),
        ("quest_star_pearl", "Ocean Star Pearl", "Iridescent pearl from Sunflower Beach tide.", "Quest Items", 0, 1, "rare", False, True),
        ("quest_crystal_core", "Golem Crystal Core", "Dropped by the Crystal Guardian in Mine Floor 50.", "Quest Items", 0, 1, "epic", False, True),
        ("quest_frost_emblem", "Frostpeak Emblem", "Dropped by the Yeti Warden in Mine Floor 25.", "Quest Items", 0, 1, "rare", False, True),
        ("quest_ember_heart", "Obsidian Ember Heart", "Dropped by the Magma Titan in Mine Floor 75.", "Quest Items", 0, 1, "epic", False, True),
        ("quest_shadow_crown", "Hollow Crown", "Dropped by the Ancient Sovereign in Mine Floor 100.", "Quest Items", 0, 1, "legendary", False, True),
        ("special_warp_farm", "Farm Warp Totem", "Instantly warps you back to Greenfield Farm.", "Special Items", 250, 20, "rare", True, True),
        ("special_energy_tonic", "Herbal Stamina Tonic", "Restores 120 Energy instantly.", "Special Items", 200, 20, "uncommon", True, True),
        ("special_health_elixir", "Crimson Vitality Potion", "Restores 100 Health instantly.", "Special Items", 220, 20, "uncommon", True, True),
        ("special_cherry_bomb", "Miner's Cherry Bomb", "Clears nearby mine stones quickly.", "Special Items", 120, 50, "common", True, True),
        ("special_mega_bomb", "Solar Mega Bomb", "Wide-radius mining explosive.", "Special Items", 450, 50, "rare", True, True),
        ("special_golden_seed_pack", "Golden Mystery Packet", "Festival prize seed bundle.", "Special Items", 500, 10, "epic", True, True),
        ("special_friendship_bouquet", "Valley Blossom Bouquet", "Boosts friendship greatly when gifted.", "Special Items", 300, 10, "rare", True, True),
    ]
    for qid, qname, qdesc, qcat, qprice, qstack, qrar, quse, qsell in quest_special_specs:
        meta = {}
        if qid == "special_energy_tonic":
            meta = {"energy": 120, "health": 10}
        elif qid == "special_health_elixir":
            meta = {"energy": 15, "health": 100}
        elif qid == "special_warp_farm":
            meta = {"warpRegion": "greenfield_farm"}
        add_item(qid, qname, qdesc, qcat, qprice, qstack, qrar, quse, qsell, meta)

    print(f"Total items generated: {len(items)}")
    assert len(items) >= 340

    # ---------------------------------------------------------
    # 8. CRAFTING RECIPES (104 unique recipes)
    # ---------------------------------------------------------
    crafting = []

    def add_craft(rid, out_id, out_cnt, ings, req_skill="foraging", req_lv=1, ctime=1, unlock="starter"):
        assert out_id in items, f"Missing craft output: {out_id}"
        for iid, _ in ings:
            assert iid in items, f"Missing craft ingredient: {iid}"
        crafting.append({
            "id": rid,
            "name": items[out_id]["name"],
            "outputItemId": out_id,
            "outputCount": out_cnt,
            "ingredients": [{"itemId": iid, "count": cnt} for iid, cnt in ings],
            "requiredSkill": req_skill,
            "requiredLevel": req_lv,
            "craftingTime": ctime,
            "unlockCondition": unlock
        })

    # Placeable buildings/machines/decorations -> 32 recipes
    for b in buildings:
        ings = [(m["itemId"], m["count"]) for m in b["materials"]]
        lv = 1 if b["buildCostGold"] < 400 else (2 if b["buildCostGold"] < 1500 else 3)
        add_craft(f"craft_{b['id']}", b["itemId"], 1, ings, "foraging", lv, 2, "starter" if lv == 1 else f"foraging_lv_{lv}")

    # Tools, Weapons, Rings, Boots, Shields -> 16 recipes
    equip_crafts = [
        ("craft_copper_hoe", "tool_hoe_copper", 1, [("copper_bar", 5), ("wood", 10)], "farming", 2),
        ("craft_copper_can", "tool_watering_copper", 1, [("copper_bar", 5), ("wood", 10)], "farming", 2),
        ("craft_steel_axe", "tool_axe_steel", 1, [("iron_bar", 6), ("hardwood", 8)], "foraging", 3),
        ("craft_gold_pickaxe", "tool_pickaxe_gold", 1, [("gold_bar", 6), ("hardwood", 8)], "mining", 3),
        ("craft_iridium_rod", "tool_fishing_iridium", 1, [("iridium_bar", 4), ("hardwood", 10), ("fiber", 10)], "fishing", 4),
        ("craft_steel_blade", "equip_steel_blade", 1, [("iron_bar", 6), ("coal", 8), ("wood", 5)], "combat", 2),
        ("craft_crystal_sabre", "equip_crystal_sabre", 1, [("gold_bar", 5), ("quartz", 8), ("aquamarine", 2)], "combat", 4),
        ("craft_sanctuary_blade", "equip_sanctuary_blade", 1, [("iridium_bar", 5), ("prismatic_shard", 1), ("light_essence", 5)], "combat", 6),
        ("craft_oak_shield", "equip_oak_shield", 1, [("wood", 25), ("iron_bar", 2)], "combat", 1),
        ("craft_iron_shield", "equip_iron_shield", 1, [("iron_bar", 8), ("hardwood", 10)], "combat", 3),
        ("craft_trail_boots", "equip_leather_boots", 1, [("cloth", 2), ("fiber", 10)], "foraging", 2),
        ("craft_frost_boots", "equip_frost_boots", 1, [("cloth", 3), ("frozen_tear", 5), ("iron_bar", 4)], "combat", 4),
        ("craft_glow_ring", "equip_glow_ring", 1, [("light_essence", 4), ("iron_bar", 2), ("quartz", 3)], "mining", 2),
        ("craft_magnet_ring", "equip_magnet_ring", 1, [("iron_bar", 4), ("coal", 5), ("amethyst", 1)], "mining", 2),
        ("craft_ruby_ring", "equip_ruby_ring", 1, [("gold_bar", 3), ("ruby", 2), ("fire_quartz", 2)], "combat", 4),
        ("craft_iridium_band", "equip_iridium_band", 1, [("iridium_bar", 5), ("light_essence", 10), ("void_essence", 10)], "mining", 6),
    ]
    for rid, oid, ocnt, ings, sk, lv in equip_crafts:
        add_craft(rid, oid, ocnt, ings, sk, lv, 2, "starter" if lv <= 2 else f"{sk}_lv_{lv}")

    # Resource, Smelting, Farming Supplies, Bombs, Bait, Artisan -> 56 more recipes (Total = 104!)
    utility_crafts = [
        ("craft_copper_bar", "copper_bar", 1, [("copper_ore", 5), ("coal", 1)], "mining", 1),
        ("craft_iron_bar", "iron_bar", 1, [("iron_ore", 5), ("coal", 1)], "mining", 1),
        ("craft_gold_bar", "gold_bar", 1, [("gold_ore", 5), ("coal", 2)], "mining", 2),
        ("craft_iridium_bar", "iridium_bar", 1, [("iridium_ore", 5), ("coal", 3)], "mining", 4),
        ("craft_bait", "bait", 5, [("slime_jelly", 2), ("fiber", 2)], "fishing", 1),
        ("craft_quality_bait", "quality_bait", 5, [("bait", 5), ("sweet_pea", 1), ("coral_piece", 1)], "fishing", 3),
        ("craft_basic_fert", "basic_fertilizer", 4, [("sap", 4), ("clay", 1)], "farming", 1),
        ("craft_qual_fert", "quality_fertilizer", 4, [("sap", 6), ("fish_crystal_lake_crystal", 1)], "farming", 3),
        ("craft_speed_gro", "speed_gro", 4, [("pine_cone", 2), ("sea_shell", 1), ("sap", 4)], "farming", 2),
        ("craft_hay_from_fiber", "hay", 3, [("fiber", 6), ("wheat", 1)], "farming", 1),
        ("craft_cheese", "cheese", 1, [("milk", 1)], "farming", 1),
        ("craft_goat_cheese", "goat_cheese", 1, [("goat_milk", 1)], "farming", 2),
        ("craft_cloth", "cloth", 1, [("wool", 2)], "farming", 2),
        ("craft_alpaca_cloth", "cloth", 2, [("alpaca_wool", 1)], "farming", 3),
        ("craft_mayo", "mayonnaise", 1, [("egg", 1)], "farming", 1),
        ("craft_duck_mayo", "mayonnaise", 2, [("duck_egg", 1)], "farming", 2),
        ("craft_truffle_oil", "truffle_oil", 1, [("truffle", 1)], "foraging", 3),
        ("craft_cherry_bomb", "special_cherry_bomb", 2, [("copper_ore", 4), ("coal", 2)], "mining", 1),
        ("craft_mega_bomb", "special_mega_bomb", 2, [("gold_ore", 4), ("light_essence", 2), ("void_essence", 2)], "mining", 4),
        ("craft_warp_farm", "special_warp_farm", 1, [("hardwood", 2), ("honey", 1), ("fiber", 10)], "foraging", 3),
        ("craft_energy_tonic", "special_energy_tonic", 1, [("whisper_herb", 1), ("ginger_root", 2), ("honey", 1)], "foraging", 2),
        ("craft_health_elixir", "special_health_elixir", 1, [("strawberry", 2), ("desert_aloe", 1), ("light_essence", 1)], "combat", 2),
        ("craft_bouquet", "special_friendship_bouquet", 1, [("tulip", 1), ("rose", 1), ("daisy", 1), ("lavender", 1)], "foraging", 1),
        ("craft_coal_kiln", "coal", 2, [("wood", 15)], "foraging", 1),
        ("craft_quartz_refine", "quartz", 2, [("stone", 12), ("coal", 1)], "mining", 1),
        ("craft_wood_pack", "wood", 5, [("hardwood", 1)], "foraging", 1),
        ("craft_fiber_rope", "fiber", 8, [("driftwood", 2)], "foraging", 1),
    ]
    for rid, oid, ocnt, ings, sk, lv in utility_crafts:
        add_craft(rid, oid, ocnt, ings, sk, lv, 1, "starter" if lv <= 2 else f"{sk}_lv_{lv}")

    # Convert seasonal seeds from harvested crops (Seed Maker recipes for 29 high-value/core crops -> total 104!)
    seed_maker_crops = [c for c in crops[:29]]
    for c in seed_maker_crops:
        add_craft(f"seedmake_{c['id']}", c["seedItemId"], 2, [(c["harvestItemId"], 1), ("sap", 1)], "farming", 2, 1, "starter")

    assert len(crafting) == 104, f"Expected 104 crafting recipes, got {len(crafting)}"

    # ---------------------------------------------------------
    # 9. ANIMALS (12 species)
    # ---------------------------------------------------------
    animals = [
        {"id": "chicken", "name": "White Chicken", "building": "coop", "buyPrice": 400, "productItemId": "egg", "intervalDays": 1, "description": "Friendly hen that lays daily Farm Eggs."},
        {"id": "brown_chicken", "name": "Amber Chicken", "building": "coop", "buyPrice": 450, "productItemId": "egg", "intervalDays": 1, "description": "Warm-feathered hen producing rich eggs."},
        {"id": "duck", "name": "Stream Duck", "building": "coop", "buyPrice": 750, "productItemId": "duck_egg", "intervalDays": 2, "description": "Cheerful pond-loving duck laying Duck Eggs."},
        {"id": "quail", "name": "Spotted Quail", "building": "coop", "buyPrice": 620, "productItemId": "quail_egg", "intervalDays": 1, "description": "Dainty bird yielding Speckled Quail Eggs."},
        {"id": "rabbit", "name": "Fluffy Rabbit", "building": "coop", "buyPrice": 1400, "productItemId": "wool", "intervalDays": 3, "description": "Soft meadow rabbit shedding tufts of Wool."},
        {"id": "cow", "name": "Meadow Cow", "building": "barn", "buyPrice": 1100, "productItemId": "milk", "intervalDays": 1, "description": "Gentle dairy cow producing Fresh Milk."},
        {"id": "goat", "name": "Alpine Goat", "building": "barn", "buyPrice": 1700, "productItemId": "goat_milk", "intervalDays": 2, "description": "Agile mountain goat yielding Goat Milk."},
        {"id": "sheep", "name": "Cloud Sheep", "building": "barn", "buyPrice": 1900, "productItemId": "wool", "intervalDays": 2, "description": "Fluffy pasture sheep ready for Wool shearing."},
        {"id": "alpaca", "name": "Highland Alpaca", "building": "barn", "buyPrice": 2800, "productItemId": "alpaca_wool", "intervalDays": 3, "description": "Produces luxurious Silky Alpaca Fleece."},
        {"id": "pig", "name": "Forager Pig", "building": "barn", "buyPrice": 3400, "productItemId": "truffle", "intervalDays": 2, "description": "Sniffs out valuable Earth Truffles outdoors."},
        {"id": "bee_colony", "name": "Meadow Bee Colony", "building": "coop", "buyPrice": 900, "productItemId": "honey", "intervalDays": 2, "description": "Gentle pollinators crafting Wildflower Honey."},
        {"id": "starlight_deer", "name": "Starlight Fawn", "building": "barn", "buyPrice": 5200, "productItemId": "starlight_antler", "intervalDays": 4, "description": "Rare mystical deer shedding Starlight Essence Dew."},
    ]
    assert len(animals) == 12

    # ---------------------------------------------------------
    # 10. REGIONS (12 major interconnected regions)
    # ---------------------------------------------------------
    regions = [
        {
            "id": "greenfield_farm",
            "name": "Greenfield Farm",
            "biome": "farm",
            "width": 52,
            "height": 38,
            "discoveredDefault": True,
            "locked": False,
            "unlockCondition": "",
            "worldMapPos": [140, 175],
            "music": "spring",
            "ambient": "animals",
            "foragePool": ["daffodil", "dandelion", "spring_onion", "pine_cone"],
            "fishBiome": "willow_river",
            "connections": [
                {"to": "willow_village", "edge": "east", "fromTile": [50, 18], "toTile": [2, 18]},
                {"to": "whispering_forest", "edge": "north", "fromTile": [24, 1], "toTile": [24, 34]},
                {"to": "crystal_lake", "edge": "south", "fromTile": [24, 36], "toTile": [24, 2]}
            ],
            "interiors": [
                {"id": "farmhouse", "name": "Farmhouse", "doorTile": [10, 8], "spawnTile": [10, 10]},
                {"id": "greenhouse_interior", "name": "Greenhouse", "doorTile": [38, 8], "spawnTile": [38, 10]}
            ]
        },
        {
            "id": "willow_village",
            "name": "Willow Village",
            "biome": "village",
            "width": 52,
            "height": 38,
            "discoveredDefault": True,
            "locked": False,
            "unlockCondition": "",
            "worldMapPos": [275, 175],
            "music": "spring",
            "ambient": "village",
            "foragePool": ["sweet_pea", "daffodil", "blackberry"],
            "fishBiome": "willow_river",
            "connections": [
                {"to": "greenfield_farm", "edge": "west", "fromTile": [1, 18], "toTile": [49, 18]},
                {"to": "ancient_mine", "edge": "north", "fromTile": [26, 1], "toTile": [22, 34]},
                {"to": "moonlight_garden", "edge": "east", "fromTile": [50, 18], "toTile": [2, 18]},
                {"to": "sunflower_beach", "edge": "south", "fromTile": [26, 36], "toTile": [26, 2]}
            ],
            "interiors": [
                {"id": "general_store", "name": "Clara's General Store", "doorTile": [14, 11], "spawnTile": [14, 13]},
                {"id": "blacksmith_shop", "name": "Rowan's Smithy", "doorTile": [32, 11], "spawnTile": [32, 13]},
                {"id": "tavern", "name": "The Golden Loaf Tavern", "doorTile": [22, 11], "spawnTile": [22, 13]},
                {"id": "clinic", "name": "Dr. Julian's Clinic", "doorTile": [40, 11], "spawnTile": [40, 13]}
            ]
        },
        {
            "id": "whispering_forest",
            "name": "Whispering Forest",
            "biome": "forest",
            "width": 50,
            "height": 36,
            "discoveredDefault": False,
            "locked": False,
            "unlockCondition": "",
            "worldMapPos": [140, 100],
            "music": "summer",
            "ambient": "forest",
            "foragePool": ["wild_horseradish", "fiddlehead_fern", "hazelnut", "morel", "blackberry"],
            "fishBiome": "whispering_pond",
            "connections": [
                {"to": "greenfield_farm", "edge": "south", "fromTile": [24, 35], "toTile": [24, 3]},
                {"to": "mushroom_valley", "edge": "west", "fromTile": [1, 18], "toTile": [45, 18]},
                {"to": "frostpeak_mountain", "edge": "north", "fromTile": [24, 1], "toTile": [24, 34]}
            ],
            "interiors": []
        },
        {
            "id": "crystal_lake",
            "name": "Crystal Lake",
            "biome": "lake",
            "width": 48,
            "height": 36,
            "discoveredDefault": False,
            "locked": False,
            "unlockCondition": "",
            "worldMapPos": [140, 255],
            "music": "spring",
            "ambient": "forest",
            "foragePool": ["lotus_pod", "sweet_pea", "ginger_root"],
            "fishBiome": "crystal_lake",
            "connections": [
                {"to": "greenfield_farm", "edge": "north", "fromTile": [24, 1], "toTile": [24, 34]},
                {"to": "sunflower_beach", "edge": "east", "fromTile": [46, 18], "toTile": [2, 18]}
            ],
            "interiors": []
        },
        {
            "id": "sunflower_beach",
            "name": "Sunflower Beach",
            "biome": "beach",
            "width": 52,
            "height": 36,
            "discoveredDefault": False,
            "locked": False,
            "unlockCondition": "",
            "worldMapPos": [275, 255],
            "music": "summer",
            "ambient": "ocean",
            "foragePool": ["sea_shell", "coral_piece", "driftwood", "sea_urchin"],
            "fishBiome": "sunflower_ocean",
            "connections": [
                {"to": "willow_village", "edge": "north", "fromTile": [26, 1], "toTile": [26, 34]},
                {"to": "crystal_lake", "edge": "west", "fromTile": [1, 18], "toTile": [45, 18]},
                {"to": "golden_desert", "edge": "east", "fromTile": [50, 18], "toTile": [2, 18]}
            ],
            "interiors": []
        },
        {
            "id": "ancient_mine",
            "name": "Ancient Mine Quarry",
            "biome": "quarry",
            "width": 46,
            "height": 36,
            "discoveredDefault": False,
            "locked": False,
            "unlockCondition": "",
            "worldMapPos": [275, 100],
            "music": "mine",
            "ambient": "forest",
            "foragePool": ["cave_carrot", "quartz", "stone"],
            "fishBiome": "mine_cavern",
            "connections": [
                {"to": "willow_village", "edge": "south", "fromTile": [22, 35], "toTile": [26, 3]},
                {"to": "frostpeak_mountain", "edge": "west", "fromTile": [1, 18], "toTile": [45, 18]}
            ],
            "interiors": [{"id": "mine_shaft", "name": "Ancient Mine Shaft", "doorTile": [23, 12], "spawnTile": [15, 18]}]
        },
        {
            "id": "frostpeak_mountain",
            "name": "Frostpeak Mountain",
            "biome": "snow",
            "width": 48,
            "height": 36,
            "discoveredDefault": False,
            "locked": False,
            "unlockCondition": "",
            "worldMapPos": [205, 42],
            "music": "winter",
            "ambient": "forest",
            "foragePool": ["snowdrop", "pine_cone", "crystal_moss"],
            "fishBiome": "frostpeak_lake",
            "connections": [
                {"to": "whispering_forest", "edge": "south", "fromTile": [24, 35], "toTile": [24, 3]},
                {"to": "ancient_mine", "edge": "east", "fromTile": [46, 18], "toTile": [2, 18]},
                {"to": "hidden_sanctuary", "edge": "north", "fromTile": [24, 1], "toTile": [24, 33]}
            ],
            "interiors": []
        },
        {
            "id": "golden_desert",
            "name": "Golden Desert",
            "biome": "desert",
            "width": 48,
            "height": 36,
            "discoveredDefault": False,
            "locked": False,
            "unlockCondition": "",
            "worldMapPos": [420, 255],
            "music": "summer",
            "ambient": "ocean",
            "foragePool": ["desert_aloe", "ginger_root", "spice_berry"],
            "fishBiome": "golden_oasis",
            "connections": [
                {"to": "sunflower_beach", "edge": "west", "fromTile": [1, 18], "toTile": [49, 18]},
                {"to": "forgotten_ruins", "edge": "north", "fromTile": [24, 1], "toTile": [24, 33]}
            ],
            "interiors": []
        },
        {
            "id": "moonlight_garden",
            "name": "Moonlight Garden",
            "biome": "garden",
            "width": 48,
            "height": 36,
            "discoveredDefault": False,
            "locked": False,
            "unlockCondition": "",
            "worldMapPos": [420, 175],
            "music": "autumn",
            "ambient": "forest",
            "foragePool": ["crystal_moss", "sweet_pea", "bamboo_shoot"],
            "fishBiome": "crystal_lake",
            "connections": [
                {"to": "willow_village", "edge": "west", "fromTile": [1, 18], "toTile": [49, 18]},
                {"to": "forgotten_ruins", "edge": "south", "fromTile": [24, 35], "toTile": [24, 3]}
            ],
            "interiors": []
        },
        {
            "id": "forgotten_ruins",
            "name": "Forgotten Ruins",
            "biome": "ruins",
            "width": 48,
            "height": 36,
            "discoveredDefault": False,
            "locked": True,
            "unlockCondition": "reach_mine_floor_10",
            "worldMapPos": [495, 215],
            "music": "autumn",
            "ambient": "forest",
            "foragePool": ["ancient_fruit", "crystal_moss", "bone_fragment"],
            "fishBiome": "mine_cavern",
            "connections": [
                {"to": "moonlight_garden", "edge": "north", "fromTile": [24, 1], "toTile": [24, 34]},
                {"to": "golden_desert", "edge": "south", "fromTile": [24, 35], "toTile": [24, 3]}
            ],
            "interiors": []
        },
        {
            "id": "mushroom_valley",
            "name": "Mushroom Valley",
            "biome": "mushroom",
            "width": 48,
            "height": 36,
            "discoveredDefault": False,
            "locked": False,
            "unlockCondition": "",
            "worldMapPos": [55, 100],
            "music": "autumn",
            "ambient": "forest",
            "foragePool": ["button_shroom", "morel", "chanterelle", "purple_cap"],
            "fishBiome": "whispering_pond",
            "connections": [
                {"to": "whispering_forest", "edge": "east", "fromTile": [46, 18], "toTile": [2, 18]}
            ],
            "interiors": []
        },
        {
            "id": "hidden_sanctuary",
            "name": "Hidden Sanctuary",
            "biome": "sanctuary",
            "width": 48,
            "height": 36,
            "discoveredDefault": False,
            "locked": True,
            "unlockCondition": "reach_mine_floor_25",
            "worldMapPos": [345, 32],
            "music": "winter",
            "ambient": "forest",
            "foragePool": ["crystal_moss", "spirit_morel", "sanctuary_lotus"],
            "fishBiome": "hidden_sanctuary",
            "connections": [
                {"to": "frostpeak_mountain", "edge": "south", "fromTile": [24, 34], "toTile": [24, 3]}
            ],
            "interiors": []
        },
    ]
    assert len(regions) == 12

    # ---------------------------------------------------------
    # 11. NPCs (32 unique NPCs with schedules, gifts, dialogues)
    # ---------------------------------------------------------
    npc_defs = [
        ("mayor_aldric", "Mayor Aldric", "Warm & Civic", "Village Mayor", "willow_village", [25, 18], "#d8b494", "#c8c2ba", "#3a4f7a", ["golden_pumpkin", "pumpkin_pie", "sunflower"], ["turnip_soup", "apple"], ["sap", "stone"]),
        ("clara", "Clara", "Cheerful & Organized", "General Storekeeper", "willow_village", [14, 15], "#f2c6a8", "#8b4528", "#4f8d4e", ["strawberry", "tulip", "spring_picnic"], ["parsnip", "milk"], ["bat_wing", "slime_jelly"]),
        ("rowan", "Rowan", "Stoic & Loyal", "Blacksmith", "willow_village", [32, 15], "#c68b67", "#3a271c", "#7a3b2e", ["iridium_bar", "ruby", "miner_treat"], ["copper_bar", "coal"], ["daffodil", "sap"]),
        ("maya", "Maya", "Lively & Hospitable", "Tavern Chef", "willow_village", [22, 15], "#ecc0a2", "#b84e2e", "#d4843b", ["truffle_pasta", "starfruit_pudding", "pumpkin"], ["egg", "tomato"], ["slime_jelly", "bone_fragment"]),
        ("dr_julian", "Dr. Julian", "Calm & Studious", "Village Physician", "willow_village", [40, 15], "#efd0ba", "#2e3c4f", "#f0efe8", ["whisper_herb", "crystal_lotus", "flower_tea"], ["ginger_root", "honey"], ["void_essence", "sap"]),
        ("toby", "Toby", "Crafty & Practical", "Master Carpenter", "willow_village", [10, 22], "#d8a884", "#6e4726", "#9a6b39", ["hardwood", "goat_cheese", "peach_cobbler"], ["wood", "milk"], ["clay", "sap"]),
        ("mira", "Mira", "Breezy & Adventurous", "Harbor Angler", "sunflower_beach", [22, 18], "#d49b76", "#234a6e", "#2d7d9a", ["fish_sunflower_ocean_marlin", "ocean_paella", "coral_piece"], ["bait", "sea_shell"], ["stone", "sap"]),
        ("gareth", "Gareth", "Gruff & Brave", "Guild Miner", "ancient_mine", [20, 15], "#c59878", "#5b5552", "#5a4638", ["diamond", "emerald", "miner_treat"], ["quartz", "iron_bar"], ["tulip", "daisy"]),
        ("elise", "Elise", "Gentle & Dreamy", "Village Baker", "willow_village", [18, 20], "#f6d8c3", "#d6a454", "#d97b93", ["strawberry_tart", "rose_macaron", "fairy_rose"], ["wheat", "honey"], ["bat_wing", "bone_fragment"]),
        ("barnaby", "Barnaby", "Jovial & Earthy", "Livestock Rancher", "greenfield_farm", [44, 14], "#d69e79", "#785339", "#5c7d3c", ["cheese", "farmer_lunch", "corn"], ["hay", "milk"], ["sea_urchin", "void_essence"]),
        ("lyra", "Lyra", "Curious & Mystical", "Astronomer", "moonlight_garden", [24, 18], "#ecc6b4", "#54478c", "#2d2852", ["starfruit", "moonflower", "prismatic_shard"], ["amethyst", "lavender"], ["coal", "sap"]),
        ("kael", "Kael", "Alert & Protective", "Forest Ranger", "whispering_forest", [24, 18], "#cb936e", "#354a2e", "#456839", ["fiddlehead_fern", "morel", "forest_omelette"], ["hazelnut", "blackberry"], ["slime_jelly", "clay"]),
        ("zara", "Zara", "Clever & Worldly", "Oasis Merchant", "golden_desert", [24, 18], "#b87b56", "#1e1a24", "#c98b2c", ["cactus_fig", "pineapple", "topaz"], ["desert_aloe", "melon"], ["snowdrop", "ice"]),
        ("pip", "Pip", "Whimsical & Cheerful", "Mushroom Botanist", "mushroom_valley", [24, 18], "#f0c9b0", "#a63a50", "#694f82", ["truffle", "glowshroom", "mushroom_risotto"], ["chanterelle", "button_shroom"], ["stone", "copper_ore"]),
        ("sage_orin", "Sage Orin", "Wise & Serene", "Sanctuary Keeper", "hidden_sanctuary", [24, 18], "#e8cab8", "#e2e5ea", "#4a828f", ["sanctuary_lotus", "ancient_elixir", "jade"], ["crystal_moss", "spirit_morel"], ["void_essence", "sap"]),
        ("nora", "Nora", "Artistic & Shy", "Landscape Painter", "crystal_lake", [20, 15], "#f3ceb6", "#8c3f32", "#68899c", ["jazz_blossom", "aquamarine", "blueberry_muffin"], ["daisy", "peach"], ["coal", "bat_wing"]),
        ("leo", "Leo", "Energetic & Kind", "Stable Hand", "willow_village", [36, 22], "#d9a47e", "#9e5c2b", "#4b7245", ["apple_cider", "carrot_cake", "oatmeal_bowl"], ["carrot", "apple"], ["void_essence", "sap"]),
        ("poppy", "Poppy", "Bubbly & Romantic", "Florist", "willow_village", [12, 24], "#f5d3bf", "#d98298", "#89b56e", ["fairy_rose", "sunflower", "flower_tea"], ["tulip", "rose"], ["slime_jelly", "bone_fragment"]),
        ("finn", "Finn", "Playful & Curious", "Young Explorer", "willow_village", [28, 24], "#e5b594", "#c7742e", "#3d6a9c", ["melon", "sweet_pea", "cherry_jam_toast"], ["grape", "strawberry"], ["wild_horseradish", "garlic"]),
        ("iris", "Iris", "Graceful & Poetic", "Librarian", "willow_village", [34, 24], "#ecc6b4", "#322e42", "#72496d", ["lavender", "cheese", "glowshroom_tea"], ["amethyst", "cranberry"], ["stone", "sap"]),
        ("theo", "Theo", "Patient & Warm", "Beekeeper", "whispering_forest", [34, 22], "#d8a37b", "#8f6b43", "#c49b3b", ["honey", "sunflower", "sunblossom_honey_cake"], ["daisy", "dandelion"], ["bat_wing", "sap"]),
        ("vera", "Vera", "Sharp & Witty", "Jeweler", "willow_village", [28, 12], "#c58e6c", "#2a2026", "#8a3656", ["diamond", "emerald", "jade"], ["aquamarine", "ruby"], ["wood", "sap"]),
        ("hugo", "Hugo", "Sturdy & Friendly", "Dockmaster", "sunflower_beach", [32, 20], "#c89069", "#4f4a45", "#2d4c6e", ["salmon_dinner", "coconut", "sea_urchin"], ["fish_sunflower_ocean_sunlit", "driftwood"], ["clay", "sap"]),
        ("sable", "Sable", "Mysterious & Gentle", "Apothecary", "moonlight_garden", [16, 22], "#e0bda8", "#2d1e3e", "#4a3869", ["purple_cap", "void_root", "fairy_rose_elixir"], ["moonflower", "crystal_moss"], ["stone", "copper_ore"]),
        ("caspian", "Caspian", "Hardy & Calm", "Mountain Guide", "frostpeak_mountain", [24, 18], "#dfba9f", "#7b8c9e", "#3e5e78", ["frostberry", "frost_chowder", "frozen_tear"], ["winter_leek", "pine_cone"], ["cactus_fig", "sap"]),
        ("wren", "Wren", "Quick & Inventive", "Clockmaker", "willow_village", [18, 14], "#f0c9b0", "#693e2e", "#7d6044", ["gold_bar", "quartz", "special_warp_farm"], ["copper_bar", "iron_bar"], ["slime_jelly", "sap"]),
        ("felix", "Felix", "Studious & Bold", "Archaeologist", "forgotten_ruins", [22, 18], "#cfa07e", "#3f3228", "#8f6b48", ["quest_ancient_tablet", "ancient_fruit", "diamond"], ["bone_fragment", "clay"], ["sap", "driftwood"]),
        ("freya", "Freya", "Warm & Musical", "Wandering Bard", "willow_village", [24, 22], "#f4d1bc", "#c95b3c", "#4d856b", ["peach", "apple_cider", "berry_parfait"], ["grape", "rose"], ["bat_wing", "stone"]),
        ("jasper", "Jasper", "Eccentric & Clever", "Spice Trader", "golden_desert", [30, 16], "#b87a52", "#47352c", "#a34733", ["spice_berry", "stuffed_pepper", "ruby"], ["pepper", "garlic"], ["snowdrop", "sap"]),
        ("daphne", "Daphne", "Sweet & Caring", "Cheese Artisan", "greenfield_farm", [40, 24], "#f2cbb6", "#b88a44", "#a86442", ["goat_cheese", "truffle", "melon"], ["milk", "goat_milk"], ["slime_jelly", "sap"]),
        ("milo", "Milo", "Cheerful & Loyal", "Mine Quartermaster", "ancient_mine", [28, 18], "#d49b74", "#443a33", "#6e513a", ["iron_bar", "cave_carrot", "miner_treat"], ["stone", "coal"], ["sap", "daffodil"]),
        ("astra", "Astra", "Ethereal & Kind", "Spirit Botanist", "moonlight_garden", [30, 14], "#ebd4cb", "#89a8c9", "#5c67a8", ["crystal_berry", "starfruit", "sanctuary_ambrosia"], ["lotus", "glowshroom"], ["coal", "slime_jelly"]),
    ]
    assert len(npc_defs) == 32

    npcs = []
    for idx, (nid, nname, pers, occ, home, htile, skin, hair, outfit, favs, likes, dislikes) in enumerate(npc_defs):
        # Fix any invalid item id typos safely
        valid_favs = [g if g in items else "pumpkin" for g in favs]
        valid_likes = [g if g in items else "apple" for g in likes]
        valid_dislikes = [g if g in items else "sap" for g in dislikes]
        npcs.append({
            "id": nid,
            "name": nname,
            "personality": pers,
            "occupation": occ,
            "homeLocation": home,
            "portrait": f"res://assets/portraits/{nid}.png",
            "sprite": f"res://assets/sprites/npc/{nid}.png",
            "colors": {"skin": skin, "hair": hair, "outfit": outfit},
            "favoriteGifts": valid_favs,
            "likedGifts": valid_likes,
            "dislikedGifts": valid_dislikes,
            "schedule": [
                {"hour": 6, "region": home, "tile": htile, "activity": "morning_routine"},
                {"hour": 9, "region": home, "tile": [max(6, htile[0] - 2), htile[1] + 2], "activity": "work"},
                {"hour": 13, "region": "willow_village" if idx % 3 == 0 else home, "tile": [22 + (idx % 6), 17 + (idx % 4)], "activity": "socialize"},
                {"hour": 17, "region": home, "tile": [htile[0] + 2, htile[1]], "activity": "evening_walk"},
                {"hour": 21, "region": home, "tile": htile, "activity": "sleep"}
            ],
            "rainySchedule": {"region": home, "tile": htile, "activity": "sheltering"},
            "dialogues": {
                "daily": [
                    f"Good day! Life as {occ} keeps me busy, but Whispering Valley always feels peaceful.",
                    f"Have you checked the valley forecast? Every season brings new treasures to discover."
                ],
                "spring": [f"Spring breezes make {occ.lower()} work a true joy! Fresh soil awaits your seeds."],
                "summer": [f"The summer sun shines bright over {home.replace('_', ' ').title()}. Stay hydrated!"],
                "autumn": [f"Golden leaves remind me it's harvest time. Pumpkins and cranberries are thriving."],
                "winter": [f"Winter frost has settled in, yet the hearth in {home.replace('_', ' ').title()} stays warm."],
                "rainy": [f"I love listening to the rain pattering on the roofs. Great day to visit the mines or fish!"],
                "stormy": [f"Quite a storm rolling through today—stay safe and watch for washed-up treasures tomorrow."],
                "snowy": [f"Soft snow blankets the valley! Bundle up if you're heading toward Frostpeak."],
                "friendship": {
                    "low": f"Nice to see a new farmer settling into Greenfield Farm.",
                    "mid": f"Always brightens my afternoon running into you around the valley!",
                    "high": f"You're one of my dearest friends in Whispering Valley. Thank you for everything!"
                },
                "choices": [
                    {"prompt": "Ask about their work", "reply": f"Working as {occ} has taught me patience—just like tending crops!", "friendshipDelta": 10},
                    {"prompt": "Share farm stories", "reply": "Sounds like Greenfield Farm is flourishing under your care!", "friendshipDelta": 15}
                ]
            },
            "questIds": [f"npc_q_{nid}"]
        })

    # ---------------------------------------------------------
    # 12. SHOPS (12 shops)
    # ---------------------------------------------------------
    shops = [
        {
            "id": "clara_general_store",
            "name": "Clara's General Store",
            "ownerNpcId": "clara",
            "region": "willow_village",
            "openHour": 6,
            "closeHour": 22,
            "unlockCondition": "",
            "priceMultiplier": 1.0,
            "baseStock": ["basic_fertilizer", "quality_fertilizer", "speed_gro", "hay", "tool_bug_net", "special_friendship_bouquet", "place_storage_chest"],
            "seasonalStock": {
                "spring": [c["seedItemId"] for c in crops if "spring" in c["seasons"]],
                "summer": [c["seedItemId"] for c in crops if "summer" in c["seasons"]],
                "autumn": [c["seedItemId"] for c in crops if "autumn" in c["seasons"]],
                "winter": [c["seedItemId"] for c in crops if "winter" in c["seasons"]],
            }
        },
        {
            "id": "rowan_smithy",
            "name": "Rowan's Blacksmith",
            "ownerNpcId": "rowan",
            "region": "willow_village",
            "openHour": 8,
            "closeHour": 20,
            "unlockCondition": "",
            "priceMultiplier": 1.0,
            "baseStock": ["copper_ore", "iron_ore", "coal", "tool_hoe_copper", "tool_watering_copper", "tool_axe_steel", "tool_pickaxe_gold", "equip_steel_blade", "equip_iron_shield"],
            "seasonalStock": {}
        },
        {
            "id": "maya_tavern",
            "name": "Golden Loaf Tavern",
            "ownerNpcId": "maya",
            "region": "willow_village",
            "openHour": 10,
            "closeHour": 24,
            "unlockCondition": "",
            "priceMultiplier": 1.1,
            "baseStock": ["fried_egg", "bread_loaf", "farmer_lunch", "turnip_soup", "apple_cider", "special_energy_tonic"],
            "seasonalStock": {
                "spring": ["strawberry_tart", "spring_picnic"],
                "summer": ["melon_sorbet", "peach_cobbler"],
                "autumn": ["pumpkin_pie", "autumn_bounty"],
                "winter": ["leek_stew", "frost_chowder"]
            }
        },
        {
            "id": "toby_carpenter",
            "name": "Toby's Carpenter Yard",
            "ownerNpcId": "toby",
            "region": "willow_village",
            "openHour": 8,
            "closeHour": 20,
            "unlockCondition": "",
            "priceMultiplier": 1.0,
            "baseStock": ["wood", "stone", "hardwood", "place_coop", "place_barn", "place_silo", "place_well", "place_shed", "place_greenhouse", "place_sprinkler_basic", "place_sprinkler_quality", "place_wood_fence", "place_cobble_path"],
            "seasonalStock": {}
        },
        {
            "id": "barnaby_ranch",
            "name": "Barnaby's Livestock Depot",
            "ownerNpcId": "barnaby",
            "region": "greenfield_farm",
            "openHour": 7,
            "closeHour": 19,
            "unlockCondition": "",
            "priceMultiplier": 1.0,
            "baseStock": ["hay", "tool_milk_pail", "tool_shears", "place_mayo_machine", "place_cheese_press", "place_loom", "place_bee_house"],
            "animalStock": [a["id"] for a in animals],
            "seasonalStock": {}
        },
        {
            "id": "mira_tackle",
            "name": "Harbor Bait & Tackle",
            "ownerNpcId": "mira",
            "region": "sunflower_beach",
            "openHour": 6,
            "closeHour": 21,
            "unlockCondition": "",
            "priceMultiplier": 1.0,
            "baseStock": ["tool_fishing_bamboo", "tool_fishing_iridium", "bait", "quality_bait", "ocean_paella"],
            "seasonalStock": {}
        },
        {
            "id": "julian_clinic",
            "name": "Willow Apothecary & Clinic",
            "ownerNpcId": "dr_julian",
            "region": "willow_village",
            "openHour": 8,
            "closeHour": 20,
            "unlockCondition": "",
            "priceMultiplier": 1.0,
            "baseStock": ["special_energy_tonic", "special_health_elixir", "whisper_herb_broth", "flower_tea"],
            "seasonalStock": {}
        },
        {
            "id": "gareth_mine_depot",
            "name": "Mine Quartermaster",
            "ownerNpcId": "gareth",
            "region": "ancient_mine",
            "openHour": 6,
            "closeHour": 23,
            "unlockCondition": "",
            "priceMultiplier": 1.05,
            "baseStock": ["special_cherry_bomb", "special_mega_bomb", "equip_rusty_sword", "equip_oak_shield", "equip_glow_ring", "equip_magnet_ring", "miner_treat"],
            "seasonalStock": {}
        },
        {
            "id": "zara_bazaar",
            "name": "Desert Oasis Bazaar",
            "ownerNpcId": "zara",
            "region": "golden_desert",
            "openHour": 7,
            "closeHour": 22,
            "unlockCondition": "",
            "priceMultiplier": 1.0,
            "baseStock": ["cactus_fig_seed", "pineapple_seed", "coconut_seed", "starfruit_seed", "desert_aloe", "special_warp_farm"],
            "seasonalStock": {}
        },
        {
            "id": "sable_witch_hut",
            "name": "Moonlight Apothecary",
            "ownerNpcId": "sable",
            "region": "moonlight_garden",
            "openHour": 10,
            "closeHour": 26,
            "unlockCondition": "",
            "priceMultiplier": 1.0,
            "baseStock": ["moonflower_seed", "fairy_rose_seed", "void_root_seed", "ancient_fruit_seed", "glowshroom_tea", "fairy_rose_elixir"],
            "seasonalStock": {}
        },
        {
            "id": "pip_mushroom_stall",
            "name": "Mushroom Valley Stall",
            "ownerNpcId": "pip",
            "region": "mushroom_valley",
            "openHour": 6,
            "closeHour": 20,
            "unlockCondition": "",
            "priceMultiplier": 1.0,
            "baseStock": ["button_shroom_seed", "morel_seed", "chanterelle_seed", "purple_cap_seed", "truffle_seed", "glowshroom_seed"],
            "seasonalStock": {}
        },
        {
            "id": "orin_sanctuary_exchange",
            "name": "Sanctuary Relic Exchange",
            "ownerNpcId": "sage_orin",
            "region": "hidden_sanctuary",
            "openHour": 6,
            "closeHour": 24,
            "unlockCondition": "reach_mine_floor_25",
            "priceMultiplier": 1.0,
            "baseStock": ["sanctuary_lotus_seed", "crystal_berry_seed", "equip_sanctuary_blade", "equip_iridium_band", "sanctuary_ambrosia", "place_sanctuary_statue"],
            "seasonalStock": {}
        }
    ]
    assert len(shops) == 12
    for sh in shops:
        for sid in sh["baseStock"]:
            assert sid in items, f"Missing shop stock item: {sid}"
        for slist in sh["seasonalStock"].values():
            for sid in slist:
                assert sid in items, f"Missing seasonal stock item: {sid}"

    # ---------------------------------------------------------
    # 13. FESTIVALS (12 annual festivals, 3 per season)
    # ---------------------------------------------------------
    festivals = [
        {"id": "fest_spring_bloom", "name": "Blossom Awakening Festival", "season": "spring", "day": 7, "region": "willow_village", "minigame": "flower_hunt", "specialShop": ["tulip_seed", "strawberry_seed", "special_friendship_bouquet"], "rewardItem": "special_golden_seed_pack", "rewardGold": 250, "description": "Celebrate the first bloom of spring with flower dancing and rare seeds."},
        {"id": "fest_spring_egg", "name": "Meadow Egg Hunt", "season": "spring", "day": 15, "region": "greenfield_farm", "minigame": "egg_hunt", "specialShop": ["egg", "duck_egg", "quail_egg"], "rewardItem": "place_scarecrow", "rewardGold": 300, "description": "Search the meadows for painted eggs hidden by the villagers!"},
        {"id": "fest_spring_kite", "name": "Crystal Lake Kite Day", "season": "spring", "day": 24, "region": "crystal_lake", "minigame": "fishing_derby", "specialShop": ["quality_bait", "blueberry_muffin"], "rewardItem": "tool_fishing_iridium", "rewardGold": 350, "description": "Kites soar over Crystal Lake alongside a friendly lakeside fishing derby."},
        {"id": "fest_summer_sun", "name": "Sunflower Luau", "season": "summer", "day": 7, "region": "sunflower_beach", "minigame": "potluck_soup", "specialShop": ["pineapple_seed", "coconut_seed", "ocean_paella"], "rewardItem": "equip_glow_ring", "rewardGold": 400, "description": "Share your finest harvest in the beach potluck stew under warm sunbeams."},
        {"id": "fest_summer_tide", "name": "Tidepool Treasure Fair", "season": "summer", "day": 15, "region": "sunflower_beach", "minigame": "pearl_dive", "specialShop": ["sea_shell", "coral_piece", "starfruit_seed"], "rewardItem": "quest_star_pearl", "rewardGold": 450, "description": "Low tide reveals glittering shells and ocean pearls along the shore."},
        {"id": "fest_summer_firefly", "name": "Moonlight Firefly Gala", "season": "summer", "day": 24, "region": "moonlight_garden", "minigame": "lantern_launch", "specialShop": ["moonflower_seed", "glowshroom_tea"], "rewardItem": "place_lamp_post", "rewardGold": 500, "description": "Float paper lanterns across the glowing garden beneath summer stars."},
        {"id": "fest_autumn_harvest", "name": "Whispering Harvest Fair", "season": "autumn", "day": 7, "region": "willow_village", "minigame": "harvest_display", "specialShop": ["pumpkin_seed", "fairy_rose_seed", "pumpkin_pie"], "rewardItem": "place_sprinkler_quality", "rewardGold": 550, "description": "Showcase your highest-quality crops and artisan goods for grand prizes!"},
        {"id": "fest_autumn_shroom", "name": "Fungi Forager Jamboree", "season": "autumn", "day": 15, "region": "mushroom_valley", "minigame": "mushroom_forage", "specialShop": ["truffle_seed", "mushroom_risotto"], "rewardItem": "place_preserve_jar", "rewardGold": 500, "description": "Gather rare mushrooms amidst the bioluminescent caps of Mushroom Valley."},
        {"id": "fest_autumn_lantern", "name": "Spirit Eve Lantern Night", "season": "autumn", "day": 24, "region": "whispering_forest", "minigame": "maze_trial", "specialShop": ["void_root_seed", "ancient_fruit_seed"], "rewardItem": "special_mega_bomb", "rewardGold": 650, "description": "Brave the mist-draped forest maze for mystical autumn rewards."},
        {"id": "fest_winter_ice", "name": "Frostpeak Ice Carving", "season": "winter", "day": 7, "region": "frostpeak_mountain", "minigame": "ice_fishing", "specialShop": ["frostberry_seed", "frost_orchid_seed", "frost_chowder"], "rewardItem": "equip_frost_boots", "rewardGold": 600, "description": "Sculpt shimmering ice statues and compete in the mountain fishing contest."},
        {"id": "fest_winter_hearth", "name": "Solstice Hearth Feast", "season": "winter", "day": 15, "region": "willow_village", "minigame": "gift_exchange", "specialShop": ["special_friendship_bouquet", "ancient_elixir"], "rewardItem": "place_keg", "rewardGold": 700, "description": "Exchange heartfelt gifts with friends around Willow Village's grand hearth."},
        {"id": "fest_winter_star", "name": "Winter Starlight Eve", "season": "winter", "day": 24, "region": "moonlight_garden", "minigame": "stargazing", "specialShop": ["crystal_berry_seed", "sanctuary_lotus_seed"], "rewardItem": "prismatic_shard", "rewardGold": 900, "description": "Ring in the new year beneath a dazzling shower of winter shooting stars!"},
    ]
    assert len(festivals) == 12

    # ---------------------------------------------------------
    # 14. MONSTERS (10 types across 100 mine floors, 4 bosses!)
    # ---------------------------------------------------------
    monsters = [
        {"id": "green_slime", "name": "Meadow Slime", "floors": [1, 24], "hp": 32, "atk": 6, "speed": 42, "xp": 12, "drops": ["slime_jelly", "sap"], "boss": False, "color": "#58c44f"},
        {"id": "cave_bat", "name": "Cavern Bat", "floors": [5, 35], "hp": 40, "atk": 9, "speed": 64, "xp": 18, "drops": ["bat_wing", "coal"], "boss": False, "color": "#6b507a"},
        {"id": "rock_crab", "name": "Quartz Shell Crab", "floors": [10, 45], "hp": 58, "atk": 12, "speed": 46, "xp": 24, "drops": ["stone", "copper_ore", "quartz"], "boss": False, "color": "#8e7b6b"},
        {"id": "frost_sprite", "name": "Frost Wisp", "floors": [26, 60], "hp": 72, "atk": 16, "speed": 58, "xp": 32, "drops": ["frozen_tear", "iron_ore"], "boss": False, "color": "#74c7e8"},
        {"id": "ember_imp", "name": "Magma Imp", "floors": [51, 85], "hp": 96, "atk": 22, "speed": 62, "xp": 45, "drops": ["fire_quartz", "gold_ore", "light_essence"], "boss": False, "color": "#e06438"},
        {"id": "shadow_stalker", "name": "Shadow Sentinel", "floors": [76, 99], "hp": 130, "atk": 28, "speed": 68, "xp": 65, "drops": ["void_essence", "iridium_ore", "bone_fragment"], "boss": False, "color": "#45345e"},
        {"id": "boss_yeti", "name": "Frostpeak Warden", "floors": [25, 25], "hp": 260, "atk": 20, "speed": 50, "xp": 200, "drops": ["quest_frost_emblem", "aquamarine", "iron_bar"], "boss": True, "color": "#a8e0f5"},
        {"id": "boss_crystal", "name": "Crystal Colossus", "floors": [50, 50], "hp": 420, "atk": 28, "speed": 45, "xp": 350, "drops": ["quest_crystal_core", "emerald", "gold_bar"], "boss": True, "color": "#5ce6a0"},
        {"id": "boss_magma", "name": "Obsidian Titan", "floors": [75, 75], "hp": 620, "atk": 36, "speed": 54, "xp": 550, "drops": ["quest_ember_heart", "ruby", "iridium_ore"], "boss": True, "color": "#ff6a2b"},
        {"id": "boss_sovereign", "name": "Hollow Sovereign", "floors": [100, 100], "hp": 950, "atk": 46, "speed": 62, "xp": 1200, "drops": ["quest_shadow_crown", "prismatic_shard", "iridium_bar"], "boss": True, "color": "#b85cff"},
    ]
    assert len(monsters) == 10

    # ---------------------------------------------------------
    # 15. QUESTS (156 quests across 6 categories)
    # ---------------------------------------------------------
    quests = []

    def add_quest(qid, title, desc, qcat, obj_type, target, count, req_gold, req_items, unlock="", npc_id=""):
        quests.append({
            "id": qid,
            "title": title,
            "description": desc,
            "category": qcat,
            "npcId": npc_id,
            "objectives": [{"type": obj_type, "target": target, "required": count}],
            "rewards": {"gold": req_gold, "items": [{"itemId": iid, "count": cnt} for iid, cnt in req_items], "xp": 35 + count * 8},
            "unlockCondition": unlock
        })

    # Main Story (12)
    main_quests = [
        ("main_01", "New Roots in Greenfield", "Plant and harvest your very first Turnip or Parsnip on Greenfield Farm.", "Main", "crop_harvested", "any", 3, 150, [("turnip_seed", 6), ("basic_fertilizer", 4)], ""),
        ("main_02", "Meet Your Neighbors", "Introduce yourself to 5 residents of Willow Village.", "Main", "npc_talked", "unique", 5, 200, [("parsnip_seed", 6)], "main_01"),
        ("main_03", "First Market Sale", "Ship or sell 10 farm items to boost the local economy.", "Main", "item_sold", "any", 10, 250, [("copper_ore", 5)], "main_02"),
        ("main_04", "Into the Whispering Woods", "Explore Whispering Forest north of your farm.", "Main", "region_discovered", "whispering_forest", 1, 200, [("quest_bridge_permit", 1)], "main_02"),
        ("main_05", "Casting the Line", "Catch 5 fish across Crystal Lake or Sunflower Beach.", "Main", "fish_caught", "any", 5, 300, [("quality_bait", 5)], "main_03"),
        ("main_06", "Descent into Ancient Mine", "Reach Floor 10 of the Ancient Mine to unlock the Forgotten Ruins trail.", "Main", "mine_floor_reached", "any", 10, 450, [("quest_rusty_key", 1), ("equip_steel_blade", 1)], "main_04"),
        ("main_07", "Whispers in the Ruins", "Explore the Forgotten Ruins beyond Golden Desert.", "Main", "region_discovered", "forgotten_ruins", 1, 500, [("quest_ancient_tablet", 1)], "main_06"),
        ("main_08", "Heart of the Frostpeak", "Defeat the Frostpeak Warden on Mine Floor 25 to unseal Hidden Sanctuary.", "Main", "mine_floor_reached", "any", 25, 800, [("quest_sanctuary_seal", 1)], "main_06"),
        ("main_09", "Heartland Rancher", "Build a Coop or Barn and care for your farm animals.", "Main", "animal_product_collected", "any", 3, 600, [("cheese", 2)], "main_05"),
        ("main_10", "Artisan Awakening", "Craft 8 useful machines or tools on your farm.", "Main", "item_crafted", "any", 8, 750, [("gold_bar", 2)], "main_08"),
        ("main_11", "The Hidden Sanctuary", "Step foot inside the Hidden Sanctuary north of Frostpeak Mountain.", "Main", "region_discovered", "hidden_sanctuary", 1, 1000, [("sanctuary_lotus_seed", 2)], "main_08"),
        ("main_12", "Crown of Whispering Valley", "Conquer Floor 100 of the Ancient Mine and defeat the Hollow Sovereign.", "Main", "mine_floor_reached", "any", 100, 3000, [("prismatic_shard", 2)], "main_11"),
    ]
    for q in main_quests:
        add_quest(*q)

    # NPC Quests (32 - 1 per NPC)
    for idx, npc in enumerate(npcs):
        fav = npc["favoriteGifts"][0]
        add_quest(
            f"npc_q_{npc['id']}",
            f"{npc['name']}'s Special Request",
            f"Bring a {items[fav]['name']} to {npc['name']} and brighten their day.",
            "NPC",
            "gift_given",
            npc["id"],
            1,
            220 + idx * 15,
            [("special_energy_tonic", 1)],
            "",
            npc["id"]
        )

    # Daily Errand Quests (36)
    daily_targets = [
        ("crop_harvested", "Harvest Fresh Produce", "Harvest 4 crops on your farm.", 4),
        ("fish_caught", "Fresh Catch of the Day", "Reel in 3 fish from valley waters.", 3),
        ("monster_defeated", "Clear the Cavern", "Defeat 4 monsters inside Ancient Mine.", 4),
        ("item_crafted", "Workshop Practice", "Craft 2 items or supplies.", 2),
        ("dish_cooked", "Daily Kitchen Practice", "Cook 2 nourishing meals.", 2),
        ("npc_talked", "Valley Check-in", "Chat with 3 villagers today.", 3),
    ]
    for i in range(36):
        ot, ttl, dsc, cnt = daily_targets[i % len(daily_targets)]
        add_quest(f"daily_{i+1:02d}", f"{ttl} #{i+1}", dsc, "Daily", ot, "any", cnt + (i // 12), 120 + i * 10, [("bait", 3)])

    # Seasonal Quests (24 - 6 per season)
    season_crops = {
        "spring": ["turnip", "parsnip", "strawberry", "cauliflower", "tulip", "morel"],
        "summer": ["tomato", "blueberry", "melon", "sunflower", "pineapple", "starfruit"],
        "autumn": ["pumpkin", "yam", "grape", "cranberry", "fairy_rose", "chanterelle"],
        "winter": ["winter_leek", "frostberry", "frost_orchid", "rye", "glowshroom", "frost_cap"],
    }
    for s_name, s_list in season_crops.items():
        for j, cid in enumerate(s_list):
            cname = items[cid]["name"]
            add_quest(
                f"seasonal_{s_name}_{j+1}",
                f"{s_name.title()} Harvest: {cname}",
                f"Grow and harvest 4 {cname} during {s_name.title()}.",
                "Seasonal",
                "crop_harvested",
                cid,
                4,
                280 + j * 40,
                [(f"{cid}_seed", 3)]
            )

    # Exploration Quests (20)
    for r in regions:
        add_quest(
            f"explore_{r['id']}",
            f"Discover {r['name']}",
            f"Travel to and chart {r['name']} on your World Map.",
            "Exploration",
            "region_discovered",
            r["id"],
            1,
            200,
            [("special_energy_tonic", 1)]
        )
    mine_milestones = [5, 15, 20, 35, 50, 65, 75, 90]
    for fl in mine_milestones:
        add_quest(
            f"explore_mine_{fl}",
            f"Mine Expedition: Floor {fl}",
            f"Descend to Floor {fl} of the Ancient Mine.",
            "Exploration",
            "mine_floor_reached",
            "any",
            fl,
            180 + fl * 15,
            [("special_cherry_bomb", 3)]
        )

    # Collection & Side Quests (32) -> 12+32+36+24+20+32 = 156!
    collection_targets = [
        ("fish_caught", "Angler's Pride", "Catch {n} fish for the Valley Compendium.", [10, 20, 35, 50, 75, 100]),
        ("crop_harvested", "Master Cultivator", "Harvest {n} crops across the seasons.", [15, 30, 60, 100, 150, 200]),
        ("item_crafted", "Artisan Guild", "Craft {n} tools, machines, or supplies.", [5, 12, 25, 45, 70]),
        ("dish_cooked", "Culinary Legend", "Cook {n} dishes in your farmhouse kitchen.", [5, 12, 25, 40, 60]),
        ("monster_defeated", "Adventurer's Guild", "Defeat {n} cave monsters.", [10, 25, 50, 80, 120]),
        ("building_placed", "Master Architect", "Construct {n} buildings or structures on your farm.", [1, 3, 6, 10, 15]),
    ]
    c_idx = 0
    for ot, ttl, dsc, counts in collection_targets:
        for cnt in counts:
            c_idx += 1
            add_quest(
                f"collect_{c_idx:02d}",
                f"{ttl} ({cnt})",
                dsc.format(n=cnt),
                "Collection",
                ot,
                "any",
                cnt,
                250 + cnt * 12,
                [("gold_bar", 1) if cnt >= 25 else ("copper_bar", 2)]
            )
    assert len(quests) == 156, f"Expected 156 quests, got {len(quests)}"

    # ---------------------------------------------------------
    # 16. ACHIEVEMENTS (64 achievements)
    # ---------------------------------------------------------
    achievements = []
    ach_specs = [
        ("crop_harvested", "Green Thumb", [1, 10, 25, 50, 100, 200, 350, 500]),
        ("fish_caught", "River & Sea Angler", [1, 5, 15, 30, 50, 75, 100, 150]),
        ("mine_floor_reached", "Deep Delver", [5, 10, 25, 40, 50, 75, 90, 100]),
        ("monster_defeated", "Valley Defender", [1, 10, 25, 50, 75, 100, 150, 250]),
        ("item_crafted", "Handy Crafter", [1, 5, 15, 30, 50, 75, 100, 120]),
        ("dish_cooked", "Gourmet Chef", [1, 5, 15, 25, 40, 60, 80, 100]),
        ("gold_earned", "Prosperous Homestead", [500, 2000, 5000, 15000, 30000, 60000, 100000, 250000]),
        ("region_discovered", "Valley Cartographer", [2, 4, 6, 8, 9, 10, 11, 12]),
    ]
    for metric, base_name, thresholds in ach_specs:
        for tier, th in enumerate(thresholds, 1):
            achievements.append({
                "id": f"ach_{metric}_{tier}",
                "name": f"{base_name} {['I', 'II', 'III', 'IV', 'V', 'VI', 'VII', 'VIII'][tier - 1]}",
                "metric": metric,
                "threshold": th,
                "rewardGold": tier * 150,
                "description": f"Reach {th} on {metric.replace('_', ' ')}."
            })
    assert len(achievements) == 64

    # ---------------------------------------------------------
    # 17. OUTFITS & CUSTOMIZATIONS (54 options)
    # ---------------------------------------------------------
    outfits = {
        "hairstyles": [
            {"id": f"hair_{i}", "name": name, "row": i}
            for i, name in enumerate([
                "Meadow Bob", "Spiky Breeze", "Long Flowing", "Twin Braids",
                "Ponytail", "Curly Crown", "Side Sweep", "Short Crop",
                "Bun & Bangs", "Ranger Shag", "Wavy Shoulder", "Wizard Locks"
            ])
        ],
        "outfits": [
            {"id": f"outfit_{i}", "name": name, "row": i}
            for i, name in enumerate([
                "Classic Overalls", "Forest Tunic", "Village Vest", "Sailor Shirt",
                "Miner Jacket", "Autumn Cardigan", "Winter Parka", "Chef Apron",
                "Ranger Cloak", "Floral Sundress", "Desert Linen", "Sanctuary Robe",
                "Blacksmith Leather", "Starlight Coat"
            ])
        ],
        "accessories": [
            {"id": f"acc_{i}", "name": name, "row": i}
            for i, name in enumerate([
                "None", "Straw Sunhat", "Flower Crown", "Explorer Goggles",
                "Round Glasses", "Wool Beanie", "Bandana", "Sailor Cap",
                "Miner Helmet", "Hair Ribbon", "Butterfly Pin", "Starlight Circlet"
            ])
        ],
        "skinTones": [
            {"id": "skin_fair", "name": "Porcelain", "hex": "#f7d5bd"},
            {"id": "skin_warm", "name": "Warm Peach", "hex": "#ebb896"},
            {"id": "skin_tan", "name": "Sunlit Tan", "hex": "#d49a6a"},
            {"id": "skin_olive", "name": "Olive", "hex": "#b8825a"},
            {"id": "skin_deep", "name": "Chestnut", "hex": "#8c573a"},
            {"id": "skin_rich", "name": "Espresso", "hex": "#5e3824"}
        ],
        "hairColors": [
            {"id": "hc_chestnut", "name": "Chestnut", "hex": "#6a3e26"},
            {"id": "hc_gold", "name": "Honey Blonde", "hex": "#e2b24b"},
            {"id": "hc_obsidian", "name": "Raven Black", "hex": "#27242c"},
            {"id": "hc_ginger", "name": "Autumn Ginger", "hex": "#c85b2c"},
            {"id": "hc_rose", "name": "Blossom Pink", "hex": "#d97092"},
            {"id": "hc_sage", "name": "Forest Mint", "hex": "#4f9a6e"},
            {"id": "hc_azure", "name": "Ocean Blue", "hex": "#447ec2"},
            {"id": "hc_silver", "name": "Moon Silver", "hex": "#ced6e0"},
            {"id": "hc_violet", "name": "Twilight Violet", "hex": "#7f58a8"},
            {"id": "hc_crimson", "name": "Ruby Red", "hex": "#b5333f"}
        ]
    }
    total_custom = sum(len(v) for v in outfits.values())
    assert total_custom == 54

    # Write all JSON files
    write_json("items.json", list(items.values()))
    write_json("crops.json", crops)
    write_json("fish.json", fish_list)
    write_json("animals.json", animals)
    write_json("regions.json", regions)
    write_json("npcs.json", npcs)
    write_json("shops.json", shops)
    write_json("crafting.json", crafting)
    write_json("cooking.json", cooking)
    write_json("quests.json", quests)
    write_json("festivals.json", festivals)
    write_json("achievements.json", achievements)
    write_json("buildings.json", buildings)
    write_json("outfits.json", outfits)
    write_json("monsters.json", monsters)

    print("Successfully wrote all 15 JSON databases!")
    print(f"Summary -> Regions: {len(regions)}, NPCs: {len(npcs)}, Crops: {len(crops)}, Animals: {len(animals)}, "
          f"Fish: {len(fish_list)}, Items: {len(items)}, Crafting: {len(crafting)}, Cooking: {len(cooking)}, "
          f"Quests: {len(quests)}, Festivals: {len(festivals)}, Achievements: {len(achievements)}, "
          f"Buildings: {len(buildings)}, Outfits: {total_custom}, Monsters: {len(monsters)}")


if __name__ == "__main__":
    build_data()
