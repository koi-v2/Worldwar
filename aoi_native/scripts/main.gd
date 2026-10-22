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
var koi_texture: Texture2D
var walk_time := 0.0
var walk_frame := 0
var facing := "down"
var is_player_moving := false
var dialogue_label: Label
var nearby_npc_name := ""
var dialogue_open := false

func _ready() -> void:
	if ResourceLoader.exists(KOI_TEXTURE_PATH):
		koi_texture = load(KOI_TEXTURE_PATH) as Texture2D
	_build_hud()
	_build_dialogue_ui()
	_update_camera(1.0)
	queue_redraw()

func _process(delta: float) -> void:
	if Input.is_key_pressed(KEY_E) or Input.is_key_pressed(KEY_ENTER):
		if nearby_npc_name != "" and not dialogue_open:
			_open_npc_dialogue()
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
	_update_camera(delta)
	queue_redraw()

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
	if dialogue_label != null and not dialogue_open:
		dialogue_label.text = "Tekan BICARA untuk ngobrol dengan %s" % nearby_npc_name if nearby_npc_name != "" else "Dekati penduduk untuk mengobrol"

func _build_dialogue_ui() -> void:
	var canvas := get_node_or_null("DialogueLayer") as CanvasLayer
	if canvas == null:
		canvas = CanvasLayer.new()
		canvas.name = "DialogueLayer"
		add_child(canvas)
	var panel := PanelContainer.new()
	panel.name = "DialoguePanel"
	panel.position = Vector2(230, 365)
	panel.size = Vector2(500, 105)
	panel.visible = false
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
	var talk_button := Button.new()
	talk_button.text = "BICARA"
	talk_button.position = Vector2(750, 410)
	talk_button.size = Vector2(150, 62)
	talk_button.pressed.connect(_open_npc_dialogue)
	canvas.add_child(talk_button)

func _open_npc_dialogue() -> void:
	if nearby_npc_name == "":
		if dialogue_label != null:
			dialogue_label.text = "Dekati penduduk terlebih dahulu."
		return
	dialogue_open = true
	var canvas := get_node_or_null("DialogueLayer") as CanvasLayer
	if canvas != null:
		var panel := canvas.get_node_or_null("DialoguePanel") as PanelContainer
		if panel != null:
			panel.visible = true
	if dialogue_label != null:
		dialogue_label.text = "%s: Hai! Senang bertemu denganmu di Lumnia. Semoga harimu menyenangkan!" % nearby_npc_name

func _close_npc_dialogue() -> void:
	dialogue_open = false
	var canvas := get_node_or_null("DialogueLayer") as CanvasLayer
	if canvas != null:
		var panel := canvas.get_node_or_null("DialoguePanel") as PanelContainer
		if panel != null:
			panel.visible = false

func _draw() -> void:
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#6fae69"))
	for x in range(0, int(WORLD_SIZE.x), 96):
		for y in range(0, int(WORLD_SIZE.y), 96):
			if ((x / 96) + (y / 96)) % 2 == 0:
				draw_rect(Rect2(x, y, 96, 96), Color(0.43, 0.67, 0.39, 0.18))
	draw_rect(Rect2(0, 500, WORLD_SIZE.x, 120), Color("#c8b99a"))
	draw_rect(Rect2(820, 0, 150, WORLD_SIZE.y), Color("#c8b99a"))
	draw_rect(Rect2(0, 548, WORLD_SIZE.x, 5), Color("#eee0b8"))
	draw_rect(Rect2(892, 0, 5, WORLD_SIZE.y), Color("#eee0b8"))
	_draw_building(Vector2(250, 250), Vector2(210, 150), Color("#e8a36c"), "TOKO")
	_draw_building(Vector2(1190, 240), Vector2(240, 170), Color("#d98787"), "RUMAH")
	_draw_building(Vector2(300, 760), Vector2(260, 180), Color("#7fa8dc"), "KAFE")
	_draw_building(Vector2(1210, 780), Vector2(220, 160), Color("#d8bf73"), "TOKO BAJU")
	draw_circle(Vector2(620, 870), 105, Color("#5eb9d4"))
	draw_arc(Vector2(620, 870), 105, 0, TAU, 64, Color("#d3f4f6"), 5.0)
	for tree in [Vector2(130, 130), Vector2(500, 360), Vector2(680, 260), Vector2(1500, 180), Vector2(1510, 650), Vector2(1080, 980), Vector2(420, 1030), Vector2(1650, 1040)]:
		draw_circle(tree + Vector2(3, 8), 23, Color(0, 0, 0, 0.16))
		draw_circle(tree, 23, Color("#2f7545"))
		draw_circle(tree + Vector2(-6, -6), 13, Color("#4e9a57"))
	_draw_npc(Vector2(730, 450), Color("#e8c0a0"), Color("#8657b7"))
	_draw_npc(Vector2(1040, 670), Color("#f1d1b1"), Color("#e06c75"))
	_draw_npc(Vector2(580, 690), Color("#bd8a67"), Color("#4f7fc2"))
	_draw_player()

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
	var canvas := CanvasLayer.new()
	add_child(canvas)
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
	status_label.text = "Kota Lumnia  |  Koin: 100"
	box.add_child(status_label)
	var hint := Label.new()
	hint.text = "Jelajahi kota • Prototype offline"
	hint.position = Vector2(14, 84)
	hint.add_theme_color_override("font_color", Color("#ffffff"))
	hint.add_theme_font_size_override("font_size", 15)
	canvas.add_child(hint)
	_create_direction_button(canvas, "▲", "up", Vector2(100, 0))
	_create_direction_button(canvas, "▼", "down", Vector2(100, 88))
	_create_direction_button(canvas, "◀", "left", Vector2(12, 44))
	_create_direction_button(canvas, "▶", "right", Vector2(188, 44))

func _create_direction_button(canvas: CanvasLayer, caption: String, direction: String, offset: Vector2) -> void:
	var button := Button.new()
	button.text = caption
	button.position = Vector2(24, 350) + offset
	button.size = Vector2(74, 58)
	button.add_theme_font_size_override("font_size", 25)
	button.button_down.connect(func(): held_directions[direction] = true)
	button.button_up.connect(func(): held_directions.erase(direction))
	canvas.add_child(button)
