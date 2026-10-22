extends Node2D

const WORLD_SIZE := Vector2(1800, 1200)
const PLAYER_SPEED := 230.0
const KOI_TEXTURE_PATH := "res://assets/file_00000000072882079690a16cbdd8338a.png"
const SPRITE_COLUMNS := 4
const SPRITE_ROWS := 4
const WALK_FPS := 10.0
const IDLE_BOB_SPEED := 0.0

var player_position := Vector2(900, 600)
var held_directions: Dictionary = {}
var status_label: Label
var proximity_label: Label
var koi_texture: Texture2D
var tileset_texture: Texture2D
const TILESET_PATH := "res://assets/tileset.png"
var walk_time := 0.0
var walk_frame := 0
var facing := "down"
var is_player_moving := false
var dialogue_label: Label
var nearby_npc_name := ""
var dialogue_open := false
var coins := 100
const SAVE_PATH := "user://koi_world_save.cfg"
var autosave_timer := 0.0
var hud_canvas: CanvasLayer
var dialogue_canvas: CanvasLayer
var dialogue_panel: PanelContainer
var talk_button: Button
var direction_buttons: Dictionary = {}

func _ready() -> void:
	if ResourceLoader.exists(KOI_TEXTURE_PATH):
		koi_texture = load(KOI_TEXTURE_PATH) as Texture2D
	if ResourceLoader.exists(TILESET_PATH):
		tileset_texture = load(TILESET_PATH) as Texture2D
	_load_game()
	_build_hud()
	_build_dialogue_ui()
	_layout_ui()
	get_viewport().size_changed.connect(_layout_ui)
	_update_camera(1.0)
	queue_redraw()

func _process(delta: float) -> void:
	if (Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_ENTER)) and nearby_npc_name != "" and not dialogue_open:
		_open_npc_dialogue()
	if dialogue_open:
		is_player_moving = false
		walk_frame = 0
		_update_camera(delta)
		queue_redraw()
		return
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or held_directions.has("left"):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D) or held_directions.has("right"):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W) or held_directions.has("up"):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S) or held_directions.has("down"):
		direction.y += 1.0
	is_player_moving = direction != Vector2.ZERO
	if is_player_moving:
		player_position += direction.normalized() * PLAYER_SPEED * delta
		if absf(direction.x) > absf(direction.y):
			facing = "right" if direction.x > 0 else "left"
		else:
			facing = "down" if direction.y > 0 else "up"
		walk_time += delta
		walk_frame = int(walk_time * WALK_FPS) % SPRITE_COLUMNS
	else:
		walk_frame = 0
	player_position.x = clampf(player_position.x, 30.0, WORLD_SIZE.x - 30.0)
	player_position.y = clampf(player_position.y, 70.0, WORLD_SIZE.y - 30.0)
	_update_nearby_npc()
	autosave_timer += delta
	if autosave_timer >= 10.0:
		autosave_timer = 0.0
		_save_game()
	_update_camera(delta)
	queue_redraw()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_APPLICATION_PAUSED:
		_save_game()

func _save_game() -> void:
	var save := ConfigFile.new()
	save.set_value("player", "x", player_position.x)
	save.set_value("player", "y", player_position.y)
	save.set_value("player", "facing", facing)
	save.set_value("wallet", "coins", coins)
	save.save(SAVE_PATH)

func _load_game() -> void:
	var save := ConfigFile.new()
	if save.load(SAVE_PATH) != OK:
		return
	player_position.x = float(save.get_value("player", "x", player_position.x))
	player_position.y = float(save.get_value("player", "y", player_position.y))
	facing = str(save.get_value("player", "facing", facing))
	coins = int(save.get_value("wallet", "coins", coins))
	player_position.x = clampf(player_position.x, 30.0, WORLD_SIZE.x - 30.0)
	player_position.y = clampf(player_position.y, 70.0, WORLD_SIZE.y - 30.0)

func _update_camera(delta: float) -> void:
	var viewport_size := get_viewport_rect().size
	var target_offset := viewport_size * 0.5 - player_position
	# Keep the camera inside the world so empty space never appears at edges.
	target_offset.x = clampf(target_offset.x, viewport_size.x - WORLD_SIZE.x, 0.0)
	target_offset.y = clampf(target_offset.y, viewport_size.y - WORLD_SIZE.y, 0.0)
	position = position.lerp(target_offset, 1.0 - exp(-8.0 * delta))

func _update_nearby_npc() -> void:
	var npc_data := [
		{"name": "Mira", "position": Vector2(730, 450)},
		{"name": "Raka", "position": Vector2(1040, 670)},
		{"name": "Dian", "position": Vector2(580, 690)}
	]
	nearby_npc_name = ""
	for npc in npc_data:
		if player_position.distance_to(npc.position) <= 95.0:
			nearby_npc_name = npc.name
			break
	if proximity_label != null:
		proximity_label.text = "Tekan BICARA untuk ngobrol dengan %s" % nearby_npc_name if nearby_npc_name != "" else "Dekati penduduk untuk mengobrol"
		proximity_label.visible = not dialogue_open

func _build_dialogue_ui() -> void:
	var canvas := CanvasLayer.new()
	canvas.name = "DialogueLayer"
	add_child(canvas)
	dialogue_canvas = canvas
	var panel := PanelContainer.new()
	panel.name = "DialoguePanel"
	panel.visible = false
	dialogue_panel = panel
	canvas.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	dialogue_label = Label.new()
	dialogue_label.text = "Dekati penduduk untuk mengobrol"
	dialogue_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	box.add_child(dialogue_label)
	var close_button := Button.new()
	close_button.text = "Tutup"
	close_button.pressed.connect(_close_npc_dialogue)
	box.add_child(close_button)
	talk_button = Button.new()
	talk_button.text = "BICARA"
	talk_button.custom_minimum_size = Vector2(112, 52)
	talk_button.pressed.connect(_open_npc_dialogue)
	canvas.add_child(talk_button)

func _open_npc_dialogue() -> void:
	if nearby_npc_name == "":
		if dialogue_label != null:
			dialogue_label.text = "Dekati penduduk terlebih dahulu."
		return
	dialogue_open = true
	held_directions.clear()
	if proximity_label != null:
		proximity_label.visible = false
	var canvas := get_node_or_null("DialogueLayer") as CanvasLayer
	if canvas != null:
		var panel := canvas.get_node_or_null("DialoguePanel") as PanelContainer
		if panel != null:
			panel.visible = true
	if dialogue_label != null:
		dialogue_label.text = "%s: Hai! Senang bertemu denganmu di Lumnia. Semoga harimu menyenangkan!" % nearby_npc_name

func _close_npc_dialogue() -> void:
	dialogue_open = false
	_update_nearby_npc()
	var canvas := get_node_or_null("DialogueLayer") as CanvasLayer
	if canvas != null:
		var panel := canvas.get_node_or_null("DialoguePanel") as PanelContainer
		if panel != null:
			panel.visible = false

func _draw() -> void:
	# Rebuild the whole town from pieces of the uploaded atlas.
	# Atlas regions are kept in one place so their coordinates can be adjusted easily.
	if tileset_texture == null:
		draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#79b96d"))
		_draw_fallback_map()
		_draw_npc(Vector2(730, 450), Color("#e8c0a0"), Color("#8657b7"))
		_draw_npc(Vector2(1040, 670), Color("#f1d1b1"), Color("#e06c75"))
		_draw_npc(Vector2(580, 690), Color("#bd8a67"), Color("#4f7fc2"))
		_draw_player()
		return

	var tile := 48.0
	# Atlas is a generated sheet; sample consistent square cells from its grid.
	var atlas_size := Vector2(tileset_texture.get_size())
	var cols := 8
	var rows := 8
	var cell_w := atlas_size.x / float(cols)
	var cell_h := atlas_size.y / float(rows)
	# Ground base and gentle grass variation across the complete map.
	for x in range(0, int(WORLD_SIZE.x), int(tile)):
		for y in range(0, int(WORLD_SIZE.y), int(tile)):
			var idx := (int(x / tile) * 7 + int(y / tile) * 13) % 5
			var grass_cell := 0 if idx < 3 else 1
			_draw_atlas_cell(grass_cell, 0, Rect2(x, y, tile, tile), cols, rows)

	# Wide horizontal and vertical roads, plus a plaza at the crossing.
	for x in range(0, int(WORLD_SIZE.x), int(tile)):
		_draw_atlas_cell(2, 0, Rect2(x, 504, tile, tile), cols, rows)
		_draw_atlas_cell(2, 0, Rect2(x, 552, tile, tile), cols, rows)
	for y in range(0, int(WORLD_SIZE.y), int(tile)):
		_draw_atlas_cell(2, 0, Rect2(816, y, tile, tile), cols, rows)
		_draw_atlas_cell(2, 0, Rect2(864, y, tile, tile), cols, rows)
	# Crossroads paved centre.
	for x in range(816, 912, int(tile)):
		for y in range(504, 600, int(tile)):
			_draw_atlas_cell(2, 0, Rect2(x, y, tile, tile), cols, rows)

	# Pond assembled from water tiles, surrounded by sandy edge tiles.
	for x in range(480, 720, int(tile)):
		for y in range(744, 984, int(tile)):
			var is_edge := x == 480 or x == 672 or y == 744 or y == 936
			_draw_atlas_cell(3 if is_edge else 4, 0, Rect2(x, y, tile, tile), cols, rows)

	# Homes and shops are laid out as garden lots, with atlas decoration around them.
	_draw_atlas_cell(5, 0, Rect2(240, 240, 240, 192), cols, rows)
	_draw_atlas_cell(6, 0, Rect2(1180, 228, 264, 204), cols, rows)
	_draw_atlas_cell(5, 0, Rect2(288, 744, 288, 216), cols, rows)
	_draw_atlas_cell(6, 0, Rect2(1200, 768, 240, 192), cols, rows)

	# Trees, shrubs, flowers, fences and park furniture from the same sheet.
	for tree in [
		Vector2(130, 130), Vector2(190, 170), Vector2(500, 360), Vector2(680, 260),
		Vector2(1500, 180), Vector2(1570, 220), Vector2(1510, 650), Vector2(1600, 700),
		Vector2(1080, 980), Vector2(1160, 1030), Vector2(420, 1030), Vector2(1650, 1040),
		Vector2(160, 680), Vector2(690, 1010), Vector2(1380, 480), Vector2(360, 430)
	]:
		_draw_atlas_cell(7, 0, Rect2(tree - Vector2(36, 42), Vector2(72, 84)), cols, rows)
	for flower in [Vector2(102, 842), Vector2(146, 885), Vector2(198, 850), Vector2(176, 916), Vector2(119, 910), Vector2(740, 300), Vector2(1080, 850)]:
		_draw_atlas_cell(0, 1, Rect2(flower - Vector2(12, 12), Vector2(24, 24)), cols, rows)
	for fence_x in range(70, 250, 48):
		_draw_atlas_cell(1, 1, Rect2(fence_x, 790, 48, 24), cols, rows)
	_draw_atlas_cell(2, 1, Rect2(180, 860, 48, 48), cols, rows)
	_draw_atlas_cell(3, 1, Rect2(220, 860, 36, 48), cols, rows)

	_draw_npc(Vector2(730, 450), Color("#e8c0a0"), Color("#8657b7"))
	_draw_npc(Vector2(1040, 670), Color("#f1d1b1"), Color("#e06c75"))
	_draw_npc(Vector2(580, 690), Color("#bd8a67"), Color("#4f7fc2"))
	_draw_player()

func _draw_atlas_cell(col: int, row: int, dest: Rect2, cols: int, rows: int) -> void:
	if tileset_texture == null:
		return
	var atlas_size := Vector2(tileset_texture.get_size())
	var cell := atlas_size / Vector2(float(cols), float(rows))
	var source := Rect2(Vector2(float(col), float(row)) * cell, cell)
	draw_texture_rect_region(tileset_texture, dest, source)

func _draw_fallback_map() -> void:
	# Used only if the uploaded texture is missing at runtime.
	for x in range(0, int(WORLD_SIZE.x), 48):
		for y in range(0, int(WORLD_SIZE.y), 48):
			draw_rect(Rect2(x, y, 48, 48), Color("#79b96d") if ((x / 48 + y / 48) % 3 != 0) else Color("#73b267"))
	draw_rect(Rect2(0, 504, WORLD_SIZE.x, 96), Color("#d8c7a5"))
	draw_rect(Rect2(816, 0, 96, WORLD_SIZE.y), Color("#d8c7a5"))
	draw_circle(Vector2(600, 864), 112, Color("#4eaccb"))
func _draw_player() -> void:
	if koi_texture != null:
		var size := Vector2(76, 96)
		var sheet_size := Vector2(koi_texture.get_size())
		var cell := sheet_size / Vector2(SPRITE_COLUMNS, SPRITE_ROWS)
		var row := 0
		match facing:
			"down": row = 0
			"left": row = 1
			"right": row = 2
			"up": row = 3
		var frame := walk_frame if is_player_moving else 0
		var source := Rect2(Vector2(frame, row) * cell, cell)
		# Keep the sprite anchored consistently; frame animation supplies the movement.
		draw_texture_rect_region(koi_texture, Rect2(player_position - Vector2(size.x / 2.0, size.y / 2.0), size), source)
	else:
		draw_circle(player_position + Vector2(0, 8), 18, Color(0, 0, 0, 0.2))
		draw_circle(player_position, 16, Color("#f5cda7"))
		draw_rect(Rect2(player_position + Vector2(-13, 4), Vector2(26, 25)), Color("#6555cf"))
		draw_circle(player_position + Vector2(0, -7), 12, Color("#4c342a"))
	draw_rect(Rect2(player_position + Vector2(-24, -58), Vector2(48, 19)), Color("#26354a"))
	draw_string(ThemeDB.fallback_font, player_position + Vector2(-19, -45), "Koi", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

func _draw_building(pos: Vector2, size: Vector2, color: Color, title: String) -> void:
	draw_rect(Rect2(pos + Vector2(7, 9), size), Color(0, 0, 0, 0.18))
	draw_rect(Rect2(pos, size), color)
	draw_rect(Rect2(pos + Vector2(8, 8), size - Vector2(16, 16)), color.lightened(0.12), false, 4.0)
	draw_rect(Rect2(pos + Vector2(size.x * 0.4, size.y - 43), Vector2(size.x * 0.2, 43)), Color("#674a3c"))
	draw_string(ThemeDB.fallback_font, pos + Vector2(15, 30), title, HORIZONTAL_ALIGNMENT_LEFT, -1, 19, Color("#3b3440"))

func _draw_npc(pos: Vector2, skin: Color, shirt: Color) -> void:
	draw_circle(pos + Vector2(0, 5), 14, Color(0, 0, 0, 0.15))
	draw_rect(Rect2(pos + Vector2(-11, 0), Vector2(22, 25)), shirt)
	draw_circle(pos + Vector2(0, -8), 10, skin)
	draw_arc(pos + Vector2(0, -10), 10, PI, TAU, 20, Color("#49352b"), 5.0)

func _build_hud() -> void:
	hud_canvas = CanvasLayer.new()
	add_child(hud_canvas)
	var canvas := hud_canvas
	var panel := PanelContainer.new()
	panel.position = Vector2(14, 12)
	panel.custom_minimum_size = Vector2(260, 64)
	canvas.add_child(panel)
	var box := VBoxContainer.new()
	panel.add_child(box)
	var title := Label.new()
	title.text = "KOI WORLD  •  ALPHA"
	title.add_theme_font_size_override("font_size", 19)
	box.add_child(title)
	status_label = Label.new()
	status_label.text = "Kota Lumnia  |  Koin: %d" % coins
	box.add_child(status_label)
	proximity_label = Label.new()
	proximity_label.text = "Dekati penduduk untuk mengobrol"
	proximity_label.position = Vector2(14, 84)
	proximity_label.add_theme_color_override("font_color", Color("#ffffff"))
	proximity_label.add_theme_font_size_override("font_size", 15)
	proximity_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	canvas.add_child(proximity_label)
	_create_direction_button(canvas, "▲", "up", Vector2(100, 0))
	_create_direction_button(canvas, "▼", "down", Vector2(100, 88))
	_create_direction_button(canvas, "◀", "left", Vector2(12, 44))
	_create_direction_button(canvas, "▶", "right", Vector2(188, 44))

func _create_direction_button(canvas: CanvasLayer, caption: String, direction: String, offset: Vector2) -> void:
	var button := Button.new()
	button.text = caption
	button.size = Vector2(64, 54)
	direction_buttons[direction] = {"button": button, "offset": offset}
	button.add_theme_font_size_override("font_size", 25)
	button.button_down.connect(func(): held_directions[direction] = true)
	button.button_up.connect(func(): held_directions.erase(direction))
	canvas.add_child(button)


func _layout_ui() -> void:
	var view_size := get_viewport_rect().size
	if view_size.x <= 0.0 or view_size.y <= 0.0:
		return
	# Keep the HUD and controls usable on both portrait phones and landscape screens.
	if hud_canvas != null:
		if proximity_label != null:
			proximity_label.position = Vector2(14, 82)
			proximity_label.size = Vector2(maxf(140.0, view_size.x - 28.0), 44)
		var base := Vector2(18, view_size.y - 194)
		for key in direction_buttons:
			var item: Dictionary = direction_buttons[key]
			var button: Button = item["button"]
			var offset: Vector2 = item["offset"]
			button.position = base + offset * 0.72
			button.size = Vector2(58, 50)
	if dialogue_panel != null:
		var panel_width := minf(500.0, view_size.x - 24.0)
		dialogue_panel.position = Vector2((view_size.x - panel_width) / 2.0, maxf(90.0, view_size.y - 150.0))
		dialogue_panel.size = Vector2(panel_width, 125)
	if talk_button != null:
		talk_button.position = Vector2(maxf(12.0, view_size.x - 126.0), view_size.y - 72.0)
		talk_button.size = Vector2(112, 52)
