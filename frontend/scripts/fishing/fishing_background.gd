extends Node2D
## Composes the Village Pond fishing background from tileset and props.
## Sky gradient at top, grass with shore, water filling the lower portion.
## Props placed according to the art brief layout.

@export var pond_tileset: Texture2D
@export var dock_texture: Texture2D
@export var tree_texture: Texture2D
@export var rocks_texture: Texture2D
@export var cattails_texture: Texture2D

const TILE_SIZE := 32
const SCALE := 3
const SCALED_TILE := TILE_SIZE * SCALE

# Wang tile grid positions (col, row) in the 4x4 spritesheet.
const WATER := Vector2i(2, 1)
const GRASS := Vector2i(0, 3)
# Shore transitions (grass on top, water on bottom).
const SHORE_LEFT := Vector2i(0, 2)       # wang_11: grass NW+SW+NE, water SE
const SHORE_MID := Vector2i(1, 2)        # wang_3: grass top, water bottom
const SHORE_RIGHT := Vector2i(3, 2)      # wang_2: grass NW, water rest

func _ready() -> void:
	_build_background()

func _build_background() -> void:
	var vp := get_viewport_rect().size
	var cols := ceili(vp.x / SCALED_TILE) + 1
	var total_rows := ceili(vp.y / SCALED_TILE) + 1

	# Shore at roughly 30% down — leaves room for sky/trees above.
	var shore_row := int(total_rows * 0.30)

	# Draw sky gradient as a simple ColorRect behind everything.
	_draw_sky(vp, shore_row)

	# Tile the ground.
	for row in total_rows:
		for col in cols:
			var tile_coord: Vector2i
			if row < shore_row:
				tile_coord = GRASS
			elif row == shore_row:
				if col == 0:
					tile_coord = SHORE_LEFT
				elif col == cols - 1:
					tile_coord = SHORE_RIGHT
				else:
					tile_coord = SHORE_MID
			else:
				tile_coord = WATER

			_add_tile(tile_coord, col, row)

	# Place props.
	_place_props(vp, shore_row)

func _draw_sky(vp: Vector2, shore_row: int) -> void:
	# Sky only shows behind the grass area (top portion).
	var sky := ColorRect.new()
	sky.color = Color(0.53, 0.81, 0.92, 1)  # Light sky blue #87ceeb
	sky.size = Vector2(vp.x, shore_row * SCALED_TILE)
	sky.z_index = -2
	add_child(sky)

func _add_tile(tile_coord: Vector2i, col: int, row: int) -> void:
	var sprite := Sprite2D.new()
	sprite.texture = pond_tileset
	sprite.region_enabled = true
	sprite.region_rect = Rect2(
		tile_coord.x * TILE_SIZE, tile_coord.y * TILE_SIZE,
		TILE_SIZE, TILE_SIZE
	)
	sprite.centered = false
	sprite.scale = Vector2(SCALE, SCALE)
	sprite.position = Vector2(col * SCALED_TILE, row * SCALED_TILE)
	sprite.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
	sprite.z_index = -1
	add_child(sprite)

func _place_props(vp: Vector2, shore_row: int) -> void:
	var shore_y := float(shore_row * SCALED_TILE)
	var prop_scale := Vector2(SCALE, SCALE)

	# Tree: background, left-center, rooted on the grass above shore.
	if tree_texture:
		var tree := Sprite2D.new()
		tree.texture = tree_texture
		tree.centered = false
		tree.scale = prop_scale
		# Tree is 96x128. Place so trunk base is at the shore.
		tree.position = Vector2(30, shore_y - 128 * SCALE + 15 * SCALE)
		tree.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		tree.z_index = 0
		add_child(tree)

	# Dock: right side, extending from shore into water.
	if dock_texture:
		var dock := Sprite2D.new()
		dock.texture = dock_texture
		dock.centered = false
		dock.scale = prop_scale
		# Dock is 128x96. Place at the shore, extending right.
		dock.position = Vector2(vp.x - 128 * SCALE - 10, shore_y - 30 * SCALE)
		dock.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		dock.z_index = 1
		add_child(dock)

	# Cattails: left side along shoreline.
	if cattails_texture:
		var cattail := Sprite2D.new()
		cattail.texture = cattails_texture
		cattail.centered = false
		cattail.scale = prop_scale
		# Cattails are 64x96. Place at shore edge, left side.
		cattail.position = Vector2(vp.x * 0.15, shore_y - 50 * SCALE)
		cattail.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		cattail.z_index = 2
		add_child(cattail)

	# Rocks: near shore, center-right area.
	if rocks_texture:
		var rocks := Sprite2D.new()
		rocks.texture = rocks_texture
		rocks.centered = false
		rocks.scale = prop_scale
		# Rocks are 64x48. Place at shore edge.
		rocks.position = Vector2(vp.x * 0.45, shore_y - 10 * SCALE)
		rocks.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST
		rocks.z_index = 1
		add_child(rocks)
