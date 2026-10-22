extends Node2D

const WORLD_SIZE := Vector2(1800, 1200)
const PLAYER_SPEED := 230.0

var player_position := Vector2(900, 600)
var held_directions: Dictionary = {}
var status_label: Label
var move_buttons: Dictionary = {}

func _ready() -> void:
	_build_hud()
	queue_redraw()

func _process(delta: float) -> void:
	var direction := Vector2.ZERO
	if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A) or held_directions.has("left"):
		direction.x -= 1.0
	if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D) or held_directions.has("right"):
		direction.x += 1.0
	if Input.is_key_pressed(KEY_UP) or Input.is_key_pressed(KEY_W) or held_directions.has("up"):
		direction.y -= 1.0
	if Input.is_key_pressed(KEY_DOWN) or Input.is_key_pressed(KEY_S) or held_directions.has("down"):
		direction.y += 1.0
	if direction != Vector2.ZERO:
		player_position += direction.normalized() * PLAYER_SPEED * delta
	player_position.x = clampf(player_position.x, 30.0, WORLD_SIZE.x - 30.0)
	player_position.y = clampf(player_position.y, 70.0, WORLD_SIZE.y - 30.0)
	queue_redraw()

func _draw() -> void:
	# Grass base and simple walkable town blocks.
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#6fae69"))
	for x in range(0, int(WORLD_SIZE.x), 96):
		for y in range(0, int(WORLD_SIZE.y), 96):
			if ((x / 96) + (y / 96)) % 2 == 0:
				draw_rect(Rect2(x, y, 96, 96), Color(0.43, 0.67, 0.39, 0.28))
	# Main roads.
	draw_rect(Rect2(0, 500, WORLD_SIZE.x, 120), Color("#c8b99a"))
	draw_rect(Rect2(820, 0, 150, WORLD_SIZE.y), Color("#c8b99a"))
	draw_rect(Rect2(0, 548, WORLD_SIZE.x, 5), Color("#eee0b8"))
	draw_rect(Rect2(892, 0, 5, WORLD_SIZE.y), Color("#eee0b8"))
	# Buildings, parks and a pond.
	_draw_building(Vector2(250, 250), Vector2(210, 150), Color("#e8a36c"), "TOKO")
	_draw_building(Vector2(1190, 240), Vector2(240, 170), Color("#d98787"), "RUMAH")
	_draw_building(Vector2(300, 760), Vector2(260, 180), Color("#7fa8dc"), "KAFE")
	_draw_building(Vector2(1210, 780), Vector2(220, 160), Color("#d8bf73"), "TOKO BAJU")
	draw_circle(Vector2(620, 870), 105, Color("#5eb9d4"))
	draw_arc(Vector2(620, 870), 105, 0, TAU, 64, Color("#d3f4f6"), 5.0)
	# Decorative trees.
	for tree in [Vector2(130, 130), Vector2(500, 360), Vector2(680, 260), Vector2(1500, 180), Vector2(1510, 650), Vector2(1080, 980), Vector2(420, 1030), Vector2(1650, 1040)]:
		draw_circle(tree + Vector2(3, 8), 23, Color(0, 0, 0, 0.16))
		draw_circle(tree, 23, Color("#2f7545"))
		draw_circle(tree + Vector2(-6, -6), 13, Color("#4e9a57"))
	# Local NPCs.
	_draw_npc(Vector2(730, 450), Color("#e8c0a0"), Color("#8657b7"))
	_draw_npc(Vector2(1040, 670), Color("#f1d1b1"), Color("#e06c75"))
	_draw_npc(Vector2(580, 690), Color("#bd8a67"), Color("#4f7fc2"))
	# Player and nameplate.
	draw_circle(player_position + Vector2(0, 8), 18, Color(0, 0, 0, 0.2))
	draw_circle(player_position, 16, Color("#f5cda7"))
	draw_circle(player_position + Vector2(0, -4), 11, Color("#f5cda7"))
	draw_rect(Rect2(player_position + Vector2(-13, 4), Vector2(26, 25)), Color("#6555cf"))
	draw_circle(player_position + Vector2(0, -7), 12, Color("#4c342a"))
	draw_rect(Rect2(player_position + Vector2(-24, -48), Vector2(48, 19)), Color("#26354a"))
	draw_string(ThemeDB.fallback_font, player_position + Vector2(-19, -35), "Koi", HORIZONTAL_ALIGNMENT_LEFT, -1, 13, Color.WHITE)

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
	var base := Control.new()
	base.position = Vector2(24, 360)
	base.size = Vector2(220, 140)
	base.mouse_filter = Control.MOUSE_FILTER_IGNORE
	canvas.add_child(base)

func _create_direction_button(canvas: CanvasLayer, caption: String, direction: String, offset: Vector2) -> void:
	var button := Button.new()
	button.text = caption
	button.position = Vector2(24, 350) + offset
	button.size = Vector2(74, 58)
	button.add_theme_font_size_override("font_size", 25)
	button.button_down.connect(func(): held_directions[direction] = true)
	button.button_up.connect(func(): held_directions.erase(direction))
	canvas.add_child(button)
