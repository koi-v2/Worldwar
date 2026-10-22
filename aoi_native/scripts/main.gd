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
var image_dialog: FileDialog
var crop_panel: PanelContainer
var crop_preview: TextureRect
var crop_status: Label
var crop_image: Image
var crop_drag_start := Vector2.ZERO
var crop_drag_end := Vector2.ZERO
var crop_dragging := false
var crop_selection := Rect2()
var cropper_open := false
var map_editor_enabled := false
var selected_asset_texture: Texture2D
var placed_assets: Array[Dictionary] = []
var map_assets_dir := "user://map_assets"
var map_layout_path := "user://koi_map_layout.json"
var editor_button: Button
var import_button: Button

func _ready() -> void:
	if ResourceLoader.exists(KOI_TEXTURE_PATH):
		koi_texture = load(KOI_TEXTURE_PATH) as Texture2D
	if ResourceLoader.exists(TILESET_PATH):
		tileset_texture = load(TILESET_PATH) as Texture2D
	_load_game()
	_build_hud()
	_build_dialogue_ui()
	_build_image_editor()
	_load_placed_assets()
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
	# Clean village layout: solid grass base avoids the ugly atlas grid seams.
	draw_rect(Rect2(Vector2.ZERO, WORLD_SIZE), Color("#70ad55"))
	# Soft irregular grass patches add texture without making a checkerboard.
	for patch in [
		Rect2(70, 70, 220, 150), Rect2(390, 90, 190, 130), Rect2(1050, 70, 250, 170),
		Rect2(1450, 250, 180, 190), Rect2(80, 850, 260, 180), Rect2(1030, 950, 270, 150)
	]:
		draw_rect(patch, Color("#79b95d"))

	# Main horizontal road uses the actual long dirt strip from the atlas.
	_draw_atlas_tile(Rect2(0, 490, WORLD_SIZE.x, 92), Rect2(8, 94, 344, 60))
	# Vertical road: same road strip rotated around the road centre.
	draw_set_transform(Vector2(826, 536), PI / 2.0)
	_draw_atlas_tile(Rect2(-46, -826, 92, 1652), Rect2(8, 94, 344, 60))
	draw_set_transform(Vector2.ZERO, 0.0)
	# Road edges give the paths a neat border.
	draw_rect(Rect2(0, 487, WORLD_SIZE.x, 3), Color("#b18b5e"))
	draw_rect(Rect2(0, 582, WORLD_SIZE.x, 3), Color("#b18b5e"))
	draw_rect(Rect2(780, 0, 3, WORLD_SIZE.y), Color("#b18b5e"))
	draw_rect(Rect2(872, 0, 3, WORLD_SIZE.y), Color("#b18b5e"))

	# Central paved plaza at the road intersection.
	draw_rect(Rect2(735, 445, 182, 183), Color("#d7c69d"))
	draw_rect(Rect2(746, 456, 160, 161), Color("#c7b58d"))
	if tileset_texture != null:
		_draw_atlas_tile(Rect2(775, 485, 100, 100), Rect2(1078, 250, 80, 52))

	# Pond in the southwest, outside the road and building footprints.
	draw_circle(Vector2(520, 862), 155, Color("#527f45"))
	draw_circle(Vector2(520, 855), 137, Color("#35a9bd"))
	draw_arc(Vector2(520, 855), 124, PI, TAU, 48, Color("#77dbe0"), 5.0)
	draw_circle(Vector2(465, 820), 7, Color("#a5edf0"))
	draw_circle(Vector2(568, 885), 5, Color("#a5edf0"))

	# Buildings sit on clear lots away from the main paths.
	_draw_building(Vector2(170, 205), Vector2(190, 150), Color("#e8d5ae"), "RUMAH")
	_draw_building(Vector2(1120, 205), Vector2(210, 160), Color("#ead1a0"), "TOKO")
	_draw_building(Vector2(190, 700), Vector2(205, 160), Color("#d9e1bd"), "RUMAH")
	_draw_building(Vector2(1120, 700), Vector2(220, 165), Color("#e4c5a5"), "KAFE")

	# Decorative trees are arranged in park-like clusters along the map edges.
	for tree in [
		Vector2(90, 150), Vector2(145, 150), Vector2(420, 175), Vector2(480, 175),
		Vector2(1040, 145), Vector2(1400, 155), Vector2(1470, 155), Vector2(1580, 230),
		Vector2(1510, 680), Vector2(1580, 720), Vector2(1000, 1010), Vector2(1080, 1010),
		Vector2(700, 1050), Vector2(770, 1050), Vector2(100, 930), Vector2(320, 970),
		Vector2(1450, 1000), Vector2(1390, 1000), Vector2(630, 330), Vector2(990, 350)
	]:
		_draw_tree(tree)

	# Small flower beds placed as groups in the green areas.
	for bed in [Rect2(390, 350, 110, 38), Rect2(1000, 365, 110, 38), Rect2(690, 680, 110, 38), Rect2(900, 920, 110, 38)]:
		draw_rect(bed, Color("#4f8c45"))
		for i in range(5):
			var flower := Vector2(bed.position.x + 12 + i * 21, bed.position.y + 15)
			draw_circle(flower, 5, Color("#f4d75f"))
			draw_circle(flower + Vector2(6, 3), 4, Color("#ef91b4"))
			draw_circle(flower + Vector2(-5, 4), 4, Color("#f7e9c9"))

	# Cropped assets imported by the player.
	for placed in placed_assets:
		var texture: Texture2D = placed.get("texture") as Texture2D
		if texture != null:
			var p: Vector2 = placed.get("position", Vector2.ZERO)
			var size: Vector2 = placed.get("size", Vector2(96, 96))
			draw_texture_rect(texture, Rect2(p - size * 0.5, size), false)

	# Existing residents and player.
	_draw_npc(Vector2(730, 450), Color("#e8c0a0"), Color("#8657b7"))
	_draw_npc(Vector2(1040, 670), Color("#f1d1b1"), Color("#e06c75"))
	_draw_npc(Vector2(580, 690), Color("#bd8a67"), Color("#4f7fc2"))
	_draw_player()

func _draw_atlas_tile(destination: Rect2, source: Rect2) -> void:
	if tileset_texture != null:
		draw_texture_rect_region(tileset_texture, destination, source, Color.WHITE, false, true)
func _draw_tree(pos: Vector2) -> void:
	if tileset_texture != null:
		# Atlas's round broadleaf tree row.
		_draw_atlas_tile(Rect2(pos - Vector2(48, 58), Vector2(96, 116)), Rect2(205, 455, 112, 120))
	else:
		draw_circle(pos + Vector2(0, 22), 22, Color("#3f8543"))
		draw_rect(Rect2(pos + Vector2(-5, 8), Vector2(10, 25)), Color("#79533a"))
		draw_circle(pos + Vector2(0, -8), 28, Color("#4f9b4e"))
		draw_circle(pos + Vector2(-8, -15), 17, Color("#68ad55"))

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
	if editor_button != null:
		editor_button.position = Vector2(maxf(150.0, view_size.x - 300.0), 14)
		editor_button.size = Vector2(130, 48)
	if import_button != null:
		import_button.position = Vector2(maxf(150.0, view_size.x - 160.0), 14)
		import_button.size = Vector2(145, 48)
	if crop_panel != null:
		var crop_width := minf(620.0, view_size.x - 24.0)
		var crop_height := minf(430.0, view_size.y - 100.0)
		crop_panel.position = Vector2((view_size.x - crop_width) / 2.0, (view_size.y - crop_height) / 2.0)
		crop_panel.size = Vector2(crop_width, crop_height)
	if dialogue_panel != null:
		var panel_width := minf(500.0, view_size.x - 24.0)
		dialogue_panel.position = Vector2((view_size.x - panel_width) / 2.0, maxf(90.0, view_size.y - 150.0))
		dialogue_panel.size = Vector2(panel_width, 125)
	if talk_button != null:
		talk_button.position = Vector2(maxf(12.0, view_size.x - 126.0), view_size.y - 72.0)
		talk_button.size = Vector2(112, 52)

func _build_image_editor() -> void:
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(map_assets_dir))
	image_dialog = FileDialog.new()
	image_dialog.name = "MapImagePicker"
	image_dialog.title = "Pilih gambar untuk map"
	image_dialog.file_mode = FileDialog.FILE_MODE_OPEN_FILE
	image_dialog.access = FileDialog.ACCESS_FILESYSTEM
	image_dialog.filters = PackedStringArray(["*.png ; PNG", "*.jpg, *.jpeg ; JPEG", "*.webp ; WebP"])
	image_dialog.file_selected.connect(_on_map_image_selected)
	add_child(image_dialog)

	editor_button = Button.new()
	editor_button.text = "EDITOR MAP"
	editor_button.custom_minimum_size = Vector2(120, 48)
	editor_button.pressed.connect(_toggle_map_editor)
	hud_canvas.add_child(editor_button)

	import_button = Button.new()
	import_button.text = "PILIH GAMBAR"
	import_button.custom_minimum_size = Vector2(130, 48)
	import_button.visible = false
	import_button.pressed.connect(_open_image_picker)
	hud_canvas.add_child(import_button)

	crop_panel = PanelContainer.new()
	crop_panel.name = "CropPanel"
	crop_panel.visible = false
	crop_panel.z_index = 20
	hud_canvas.add_child(crop_panel)
	var column := VBoxContainer.new()
	crop_panel.add_child(column)
	var heading := Label.new()
	heading.text = "POTONG GAMBAR — tarik jari di gambar"
	column.add_child(heading)
	crop_preview = TextureRect.new()
	crop_preview.custom_minimum_size = Vector2(320, 220)
	crop_preview.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	crop_preview.size_flags_vertical = Control.SIZE_EXPAND_FILL
	crop_preview.expand_mode = TextureRect.EXPAND_IGNORE_SIZE
	crop_preview.stretch_mode = TextureRect.STRETCH_KEEP_ASPECT_CENTERED
	crop_preview.gui_input.connect(_on_crop_preview_input)
	column.add_child(crop_preview)
	crop_status = Label.new()
	crop_status.text = "Pilih gambar, lalu tarik area yang ingin dipotong."
	crop_status.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	column.add_child(crop_status)
	var row := HBoxContainer.new()
	column.add_child(row)
	var save_crop := Button.new()
	save_crop.text = "POTONG & PAKAI"
	save_crop.pressed.connect(_save_crop_asset)
	row.add_child(save_crop)
	var cancel := Button.new()
	cancel.text = "TUTUP"
	cancel.pressed.connect(_close_crop_panel)
	row.add_child(cancel)

func _close_crop_panel() -> void:
	crop_panel.visible = false
	cropper_open = false

func _toggle_map_editor() -> void:
	map_editor_enabled = not map_editor_enabled
	import_button.visible = map_editor_enabled
	editor_button.text = "TUTUP EDITOR" if map_editor_enabled else "EDITOR MAP"
	if map_editor_enabled:
		crop_status.text = "Pilih gambar untuk dipotong. Setelah disimpan, ketuk map untuk menaruh objek."
	else:
		crop_panel.visible = false
		cropper_open = false

func _open_image_picker() -> void:
	image_dialog.popup_centered_ratio(0.9)

func _on_map_image_selected(path: String) -> void:
	var loaded_image := Image.new()
	var err := loaded_image.load(path)
	if err != OK:
		crop_status.text = "Gagal membuka gambar. Coba PNG, JPG, atau WebP."
		crop_panel.visible = true
		return
	crop_image = loaded_image
	crop_preview.texture = ImageTexture.create_from_image(crop_image)
	crop_selection = Rect2()
	crop_dragging = false
	cropper_open = true
	crop_panel.visible = true
	crop_status.text = "Gambar %d×%d. Tarik jari untuk memilih bagian gambar." % [crop_image.get_width(), crop_image.get_height()]
	_layout_ui()

func _on_crop_preview_input(event: InputEvent) -> void:
	if crop_image == null:
		return
	if event is InputEventScreenTouch:
		if event.pressed:
			crop_drag_start = _crop_preview_to_image(event.position)
			crop_drag_end = crop_drag_start
			crop_dragging = true
		else:
			if crop_dragging:
				crop_drag_end = _crop_preview_to_image(event.position)
				crop_dragging = false
				_update_crop_selection()
	elif event is InputEventScreenDrag and crop_dragging:
		crop_drag_end = _crop_preview_to_image(event.position)
		_update_crop_selection()
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			crop_drag_start = _crop_preview_to_image(event.position)
			crop_drag_end = crop_drag_start
			crop_dragging = true
		else:
			if crop_dragging:
				crop_drag_end = _crop_preview_to_image(event.position)
				crop_dragging = false
				_update_crop_selection()
	elif event is InputEventMouseMotion and crop_dragging:
		crop_drag_end = _crop_preview_to_image(event.position)
		_update_crop_selection()

func _crop_preview_to_image(local_pos: Vector2) -> Vector2:
	if crop_image == null or crop_preview.size.x <= 0 or crop_preview.size.y <= 0:
		return Vector2.ZERO
	var image_size := Vector2(crop_image.get_size())
	var scale_factor := minf(crop_preview.size.x / image_size.x, crop_preview.size.y / image_size.y)
	var displayed_size := image_size * scale_factor
	var image_origin := (crop_preview.size - displayed_size) * 0.5
	return ((local_pos - image_origin) / scale_factor).clamp(Vector2.ZERO, image_size)

func _update_crop_selection() -> void:
	var top_left := Vector2(minf(crop_drag_start.x, crop_drag_end.x), minf(crop_drag_start.y, crop_drag_end.y))
	var bottom_right := Vector2(maxf(crop_drag_start.x, crop_drag_end.x), maxf(crop_drag_start.y, crop_drag_end.y))
	crop_selection = Rect2(top_left, bottom_right - top_left)
	crop_status.text = "Area dipilih: %d×%d px. Tekan POTONG & PAKAI." % [int(crop_selection.size.x), int(crop_selection.size.y)]

func _save_crop_asset() -> void:
	if crop_image == null or crop_selection.size.x < 4 or crop_selection.size.y < 4:
		crop_status.text = "Pilih area yang lebih besar dengan menarik jari di gambar."
		return
	var region := Rect2i(Vector2i(crop_selection.position), Vector2i(crop_selection.size))
	region.position.x = clampi(region.position.x, 0, crop_image.get_width() - 1)
	region.position.y = clampi(region.position.y, 0, crop_image.get_height() - 1)
	region.size.x = clampi(region.size.x, 1, crop_image.get_width() - region.position.x)
	region.size.y = clampi(region.size.y, 1, crop_image.get_height() - region.position.y)
	var cropped := crop_image.get_region(region)
	var filename := "crop_%d.png" % int(Time.get_unix_time_from_system())
	var save_path := map_assets_dir.path_join(filename)
	if cropped.save_png(save_path) != OK:
		crop_status.text = "Gagal menyimpan potongan gambar."
		return
	selected_asset_texture = ImageTexture.create_from_image(cropped)
	placed_assets.append({"texture": selected_asset_texture, "path": save_path, "position": Vector2(900, 600), "size": Vector2(96, 96)})
	_save_map_layout()
	crop_status.text = "Potongan tersimpan! Tutup panel, lalu ketuk lokasi map untuk menaruhnya."
	crop_panel.visible = false
	cropper_open = false
	queue_redraw()

func _input(event: InputEvent) -> void:
	if not map_editor_enabled or cropper_open or selected_asset_texture == null:
		return
	var screen_pos := Vector2.ZERO
	var pressed := false
	if event is InputEventScreenTouch and event.pressed:
		screen_pos = event.position
		pressed = true
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT and event.pressed:
		screen_pos = event.position
		pressed = true
	if pressed:
		var world_pos := screen_pos - position
		if world_pos.y > 95 and world_pos.x > 0 and world_pos.x < WORLD_SIZE.x and world_pos.y < WORLD_SIZE.y:
			placed_assets.append({"texture": selected_asset_texture, "path": _selected_asset_path(), "position": world_pos, "size": Vector2(96, 96)})
			_save_map_layout()
			queue_redraw()
			get_viewport().set_input_as_handled()

func _selected_asset_path() -> String:
	for placed in placed_assets:
		if placed.get("texture") == selected_asset_texture:
			var path := str(placed.get("path", ""))
			if not path.is_empty():
				return path
	return ""

func _save_map_layout() -> void:
	var records: Array[Dictionary] = []
	for placed in placed_assets:
		records.append({"path": str(placed.get("path", "")), "x": (placed.get("position", Vector2.ZERO) as Vector2).x, "y": (placed.get("position", Vector2.ZERO) as Vector2).y, "w": (placed.get("size", Vector2(96, 96)) as Vector2).x, "h": (placed.get("size", Vector2(96, 96)) as Vector2).y})
	var file := FileAccess.open(map_layout_path, FileAccess.WRITE)
	if file != null:
		file.store_string(JSON.stringify(records))

func _load_placed_assets() -> void:
	if not FileAccess.file_exists(map_layout_path):
		return
	var file := FileAccess.open(map_layout_path, FileAccess.READ)
	if file == null:
		return
	var parsed = JSON.parse_string(file.get_as_text())
	if not parsed is Array:
		return
	for record in parsed:
		if not record is Dictionary:
			continue
		var path := str(record.get("path", ""))
		if path.is_empty() or not FileAccess.file_exists(path):
			continue
		var img := Image.new()
		if img.load(path) != OK:
			continue
		var texture := ImageTexture.create_from_image(img)
		placed_assets.append({"texture": texture, "path": path, "position": Vector2(float(record.get("x", 900)), float(record.get("y", 600))), "size": Vector2(float(record.get("w", 96)), float(record.get("h", 96)))})
		selected_asset_texture = texture
