extends RefCounted
class_name RegionMapBuilder
## Generates multi-layer TileMapLayers and tile-accurate world layouts for all 12 regions and interiors.

const TILESET_TEX_PATH := "res://assets/tilesets/world_tileset.png"
const TILE_SIZE := 16

# Tile atlas coordinates in world_tileset.png (16 cols x 4 rows)
const T_GRASS_SPRING := Vector2i(0, 0)
const T_GRASS_FLOWER := Vector2i(1, 0)
const T_GRASS_LUSH := Vector2i(2, 0)
const T_DIRT := Vector2i(3, 0)
const T_TILLED_DRY := Vector2i(4, 0)
const T_TILLED_WET := Vector2i(5, 0)
const T_SAND := Vector2i(6, 0)
const T_DUNE := Vector2i(7, 0)
const T_SNOW := Vector2i(8, 0)
const T_SNOW_ALT := Vector2i(9, 0)
const T_GRASS_AUTUMN := Vector2i(10, 0)
const T_LEAF_TURF := Vector2i(11, 0)
const T_STONE_FLOOR := Vector2i(12, 0)
const T_MINE_FLOOR := Vector2i(13, 0)
const T_MUSHROOM_TURF := Vector2i(14, 0)
const T_SANCTUARY_TURF := Vector2i(15, 0)

const T_WATER := Vector2i(0, 1)
const T_WATER_DEEP := Vector2i(1, 1)
const T_SHORE := Vector2i(2, 1)
const T_COBBLE_PATH := Vector2i(3, 1)
const T_WOOD_PATH := Vector2i(4, 1)
const T_BRIDGE := Vector2i(5, 1)
const T_FENCE_POST := Vector2i(6, 1)
const T_FENCE_H := Vector2i(7, 1)
const T_STONE_WALL := Vector2i(8, 1)
const T_HEDGE := Vector2i(9, 1)
const T_CLIFF_FOREST := Vector2i(10, 1)
const T_CLIFF_MOUNTAIN := Vector2i(11, 1)
const T_INT_WOOD := Vector2i(12, 1)
const T_INT_RUG := Vector2i(13, 1)
const T_INT_WALL := Vector2i(14, 1)
const T_SHIPPING_BIN := Vector2i(15, 1)

const SOLID_TILES := [
	Vector2i(0, 1), Vector2i(1, 1), Vector2i(6, 1), Vector2i(7, 1),
	Vector2i(8, 1), Vector2i(9, 1), Vector2i(10, 1), Vector2i(11, 1), Vector2i(14, 1)
]

static var _cached_tileset: TileSet = null


static func get_shared_tileset() -> TileSet:
	if _cached_tileset != null:
		return _cached_tileset
	var ts := TileSet.new()
	ts.tile_size = Vector2i(TILE_SIZE, TILE_SIZE)
	ts.add_physics_layer(0)
	ts.set_physics_layer_collision_layer(0, 1)
	ts.set_physics_layer_collision_mask(0, 0)

	var src := TileSetAtlasSource.new()
	src.texture = load(TILESET_TEX_PATH) as Texture2D
	src.texture_region_size = Vector2i(TILE_SIZE, TILE_SIZE)
	ts.add_source(src, 0)

	var full_box := PackedVector2Array([
		Vector2(-8, -8), Vector2(8, -8), Vector2(8, 8), Vector2(-8, 8)
	])
	for y in range(4):
		for x in range(16):
			var c := Vector2i(x, y)
			src.create_tile(c)
			if c in SOLID_TILES:
				var td := src.get_tile_data(c, 0)
				td.set_collision_polygons_count(0, 1)
				td.set_collision_polygon_points(0, 0, full_box)

	_cached_tileset = ts
	return ts


static func get_tile_from_atlas(coords: Vector2i) -> AtlasTexture:
	var at := AtlasTexture.new()
	at.atlas = load(TILESET_TEX_PATH) as Texture2D
	at.region = Rect2(coords.x * TILE_SIZE, coords.y * TILE_SIZE, TILE_SIZE, TILE_SIZE)
	return at


static func build_region(parent: Node2D, region_id: String, season: String) -> Dictionary:
	var reg: Dictionary = GameData.regions.get(region_id, {})
	var w := int(reg.get("width", 48))
	var h := int(reg.get("height", 36))
	var biome := str(reg.get("biome", "farm"))
	var ts := get_shared_tileset()

	var ground := TileMapLayer.new()
	ground.name = "GroundLayer"
	ground.tile_set = ts
	parent.add_child(ground)

	var decor := TileMapLayer.new()
	decor.name = "DecorLayer"
	decor.tile_set = ts
	decor.z_index = 1
	parent.add_child(decor)

	var soil := TileMapLayer.new()
	soil.name = "FarmSoilLayer"
	soil.tile_set = ts
	soil.z_index = 2
	parent.add_child(soil)

	var water_tiles := {} # Vector2i -> true
	var rng := RandomNumberGenerator.new()
	rng.seed = region_id.hash() + 77

	var base_tile := _pick_biome_ground(biome, season)
	var border_tile := _pick_biome_border(biome)

	for y in range(h):
		for x in range(w):
			var is_border := (x == 0 or y == 0 or x == w - 1 or y == h - 1)
			var tp := Vector2i(x, y)
			if is_border:
				decor.set_cell(tp, 0, border_tile)
				ground.set_cell(tp, 0, base_tile)
				continue

			var chosen := base_tile
			if rng.randf() < 0.14:
				chosen = _pick_biome_variant(biome, season, base_tile)
			ground.set_cell(tp, 0, chosen)

	# Carve paths to all region connections so travel is always intuitive & unobstructed
	var cx := w / 2
	var cy := h / 2
	var path_tile := T_DIRT if biome in ["farm", "forest", "mushroom"] else T_COBBLE_PATH
	for conn in reg.get("connections", []):
		var ft: Array = conn.get("fromTile", [cx, cy])
		var tx := int(ft[0])
		var ty := int(ft[1])
		_carve_path(ground, decor, Vector2i(cx, cy), Vector2i(tx, ty), path_tile)
		# Open border gap at connection
		for dx in range(-1, 2):
			for dy in range(-1, 2):
				var gt := Vector2i(clampi(tx + dx, 0, w - 1), clampi(ty + dy, 0, h - 1))
				decor.erase_cell(gt)
				ground.set_cell(gt, 0, path_tile)

	# Region-specific landmarks, water pools, and farm zones
	if region_id == "greenfield_farm":
		# Clear fertile farm soil preview perimeter
		for fx in range(14, 36):
			for fy in range(13, 29):
				ground.set_cell(Vector2i(fx, fy), 0, T_DIRT if (fx == 14 or fx == 35) else base_tile)
		# Farm pond
		for px in range(4, 11):
			for py in range(27, 33):
				decor.set_cell(Vector2i(px, py), 0, T_WATER)
				water_tiles[Vector2i(px, py)] = true
		# Fence accent
		for fx in range(13, 37):
			if fx < 22 or fx > 26:
				decor.set_cell(Vector2i(fx, 11), 0, T_FENCE_H)
	elif biome == "lake":
		for px in range(12, 36):
			for py in range(12, 27):
				decor.set_cell(Vector2i(px, py), 0, T_WATER_DEEP if (px > 15 and px < 33 and py > 15 and py < 24) else T_WATER)
				water_tiles[Vector2i(px, py)] = true
		# Wooden fishing pier
		for py in range(8, 16):
			decor.erase_cell(Vector2i(24, py))
			decor.erase_cell(Vector2i(25, py))
			ground.set_cell(Vector2i(24, py), 0, T_BRIDGE)
			ground.set_cell(Vector2i(25, py), 0, T_BRIDGE)
	elif biome == "beach":
		for px in range(1, w - 1):
			for py in range(22, h - 1):
				decor.set_cell(Vector2i(px, py), 0, T_WATER if py < 26 else T_WATER_DEEP)
				water_tiles[Vector2i(px, py)] = true
		for py in range(19, 27):
			decor.erase_cell(Vector2i(26, py))
			ground.set_cell(Vector2i(26, py), 0, T_BRIDGE)
	elif biome == "village":
		# Cobble village square & river channel
		for sx in range(12, 40):
			for sy in range(12, 26):
				ground.set_cell(Vector2i(sx, sy), 0, T_COBBLE_PATH)
		for rx in range(2, w - 2):
			if rx < 24 or rx > 28:
				decor.set_cell(Vector2i(rx, 30), 0, T_WATER)
				water_tiles[Vector2i(rx, 30)] = true
			else:
				ground.set_cell(Vector2i(rx, 30), 0, T_BRIDGE)
	elif biome in ["forest", "desert", "snow", "sanctuary", "garden"]:
		var ox := w / 2 - 4
		var oy := h / 2 + 4
		for px in range(ox, ox + 7):
			for py in range(oy, oy + 5):
				decor.set_cell(Vector2i(px, py), 0, T_WATER)
				water_tiles[Vector2i(px, py)] = true

	return {
		"ground": ground,
		"decor": decor,
		"soil": soil,
		"width": w,
		"height": h,
		"waterTiles": water_tiles
	}


static func _carve_path(ground: TileMapLayer, decor: TileMapLayer, a: Vector2i, b: Vector2i, tile: Vector2i) -> void:
	var x := a.x
	var y := a.y
	while x != b.x:
		for dy in range(-1, 1):
			var tp := Vector2i(x, y + dy)
			ground.set_cell(tp, 0, tile)
			decor.erase_cell(tp)
		x += 1 if b.x > x else -1
	while y != b.y:
		for dx in range(-1, 1):
			var tp := Vector2i(x + dx, y)
			ground.set_cell(tp, 0, tile)
			decor.erase_cell(tp)
		y += 1 if b.y > y else -1


static func _pick_biome_ground(biome: String, season: String) -> Vector2i:
	match biome:
		"beach", "desert": return T_SAND
		"snow": return T_SNOW
		"quarry", "ruins": return T_STONE_FLOOR
		"mushroom": return T_MUSHROOM_TURF
		"sanctuary": return T_SANCTUARY_TURF
		_:
			if season == "winter":
				return T_SNOW
			if season == "autumn":
				return T_GRASS_AUTUMN
			if season == "summer":
				return T_GRASS_LUSH
			return T_GRASS_SPRING


static func _pick_biome_variant(biome: String, season: String, fallback: Vector2i) -> Vector2i:
	match biome:
		"desert", "beach": return T_DUNE
		"snow": return T_SNOW_ALT
		"quarry", "ruins": return T_MINE_FLOOR
		"mushroom": return T_GRASS_LUSH
		"sanctuary": return T_GRASS_FLOWER
		_:
			if season == "autumn":
				return T_LEAF_TURF
			if season == "winter":
				return T_SNOW_ALT
			return T_GRASS_FLOWER if biome != "village" else fallback


static func _pick_biome_border(biome: String) -> Vector2i:
	match biome:
		"quarry", "ruins", "snow": return T_CLIFF_MOUNTAIN
		"village": return T_STONE_WALL
		"desert", "beach": return T_STONE_WALL
		_: return T_CLIFF_FOREST
