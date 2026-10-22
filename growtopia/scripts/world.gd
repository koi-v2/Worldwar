extends Node2D

const TILE := 32
const WORLD_WIDTH := 180
const GROUND_Y := 15
const PLAYER_SIZE := Vector2(22, 42)

var blocks: Dictionary = {}
var player_pos := Vector2(6 * TILE, 10 * TILE)
var velocity := Vector2.ZERO
var facing := 1
var move_dir := 0
var jump_requested := false
var selected_block := 0
var inventory := {"Grass": 200, "Dirt": 200, "Wood": 50, "Stone": 50}
var block_names := ["Grass", "Dirt", "Wood", "Stone"]
var block_colors := {
    "Grass": Color("#66c94c"),
    "Dirt": Color("#99603d"),
    "Wood": Color("#bd8247"),
    "Stone": Color("#84929b")
}
var breaking_target := Vector2i(-999, -999)
var toast := ""
var toast_time := 0.0
var touch_start := Vector2.ZERO
var hold_action := ""
var punch_requested := false

func _ready() -> void:
    _generate_world()
    _load_world()
    queue_redraw()

func _notification(what: int) -> void:
    if what == NOTIFICATION_WM_CLOSE_REQUEST:
        _save_world()

func _save_world() -> void:
    var saved_blocks: Array = []
    for pos in blocks.keys():
        saved_blocks.append({"x": pos.x, "y": pos.y, "kind": blocks[pos]})
    var data := {"blocks": saved_blocks, "inventory": inventory, "player_x": player_pos.x, "player_y": player_pos.y}
    var file := FileAccess.open("user://growworld_save.json", FileAccess.WRITE)
    if file:
        file.store_string(JSON.stringify(data))

func _load_world() -> void:
    if not FileAccess.file_exists("user://growworld_save.json"):
        return
    var file := FileAccess.open("user://growworld_save.json", FileAccess.READ)
    if file == null:
        return
    var parsed = JSON.parse_string(file.get_as_text())
    if typeof(parsed) != TYPE_DICTIONARY or not parsed.has("blocks"):
        return
    blocks.clear()
    for item in parsed["blocks"]:
        if typeof(item) == TYPE_DICTIONARY and item.has("x") and item.has("y") and item.has("kind"):
            blocks[Vector2i(int(item["x"]), int(item["y"]))] = str(item["kind"])
    if parsed.has("inventory") and typeof(parsed["inventory"]) == TYPE_DICTIONARY:
        for key in parsed["inventory"].keys():
            inventory[str(key)] = int(parsed["inventory"][key])
    player_pos = Vector2(float(parsed.get("player_x", player_pos.x)), float(parsed.get("player_y", player_pos.y)))

func _generate_world() -> void:
    for x in range(WORLD_WIDTH):
        var surface := GROUND_Y + int(sin(float(x) * 0.13) * 1.3)
        for y in range(surface, 40):
            blocks[Vector2i(x, y)] = "Grass" if y == surface else ("Dirt" if y < surface + 5 else "Stone")
    for x in range(4, 9):
        for y in range(GROUND_Y - 4, GROUND_Y):
            blocks.erase(Vector2i(x, y))
    # Decorative tree made from destructible wood/grass blocks.
    for y in range(GROUND_Y - 4, GROUND_Y):
        blocks[Vector2i(18, y)] = "Wood"
    for x in range(15, 22):
        for y in range(GROUND_Y - 7, GROUND_Y - 3):
            if abs(x - 18) + abs(y - (GROUND_Y - 5)) < 5:
                blocks[Vector2i(x, y)] = "Grass"

func _physics_process(delta: float) -> void:
    var dir := move_dir
    if Input.is_key_pressed(KEY_LEFT) or Input.is_key_pressed(KEY_A): dir -= 1
    if Input.is_key_pressed(KEY_RIGHT) or Input.is_key_pressed(KEY_D): dir += 1
    dir = clampi(dir, -1, 1)
    if dir != 0: facing = dir
    velocity.x = move_toward(velocity.x, dir * 220.0, 1400.0 * delta)
    velocity.y = min(velocity.y + 1000.0 * delta, 700.0)
    if jump_requested and _is_on_ground():
        velocity.y = -430.0
    jump_requested = false
    if punch_requested:
        _punch_block_in_front()
    punch_requested = false
    _move_player(Vector2(velocity.x * delta, 0))
    _move_player(Vector2(0, velocity.y * delta))
    if player_pos.y > 1300:
        player_pos = Vector2(6 * TILE, 10 * TILE)
        velocity = Vector2.ZERO
    if toast_time > 0:
        toast_time -= delta
    queue_redraw()

func _move_player(amount: Vector2) -> void:
    var steps := maxi(1, int(ceil(amount.length() / 5.0)))
    var step := amount / steps
    for i in range(steps):
        var next := player_pos + step
        if _rect_hits_blocks(Rect2(next - Vector2(PLAYER_SIZE.x/2, PLAYER_SIZE.y), PLAYER_SIZE)):
            if amount.x != 0: velocity.x = 0
            if amount.y != 0: velocity.y = 0
            break
        player_pos = next

func _is_on_ground() -> bool:
    return _rect_hits_blocks(Rect2(player_pos + Vector2(-PLAYER_SIZE.x/2, 0), Vector2(PLAYER_SIZE.x, 3)), true)

func _rect_hits_blocks(rect: Rect2, ground_probe := false) -> bool:
    var left := floori(rect.position.x / TILE)
    var right := floori((rect.position.x + rect.size.x - 1) / TILE)
    var top := floori(rect.position.y / TILE)
    var bottom := floori((rect.position.y + rect.size.y - 1) / TILE)
    for y in range(top, bottom + 1):
        for x in range(left, right + 1):
            if blocks.has(Vector2i(x, y)): return true
    return false

func _draw() -> void:
    var screen := get_viewport_rect().size
    var camera := Vector2(player_pos.x - screen.x * 0.42, player_pos.y - screen.y * 0.57)
    camera.x = clampf(camera.x, 0, WORLD_WIDTH * TILE - screen.x)
    camera.y = clampf(camera.y, 0, 40 * TILE - screen.y)
    draw_rect(Rect2(Vector2.ZERO, screen), Color("#64b7f5"))
    # Distant soft pixel-art hills
    for i in range(8):
        var hx := fposmod(i * 230.0 - camera.x * 0.22, screen.x + 280.0) - 140.0
        var hill := PackedVector2Array([Vector2(hx, 430-camera.y*0.04), Vector2(hx+130, 235-camera.y*0.04), Vector2(hx+280, 430-camera.y*0.04)])
        draw_colored_polygon(hill, Color("#8bc5e7"))
    var min_x := maxi(0, floori(camera.x / TILE))
    var max_x := mini(WORLD_WIDTH-1, floori((camera.x + screen.x) / TILE)+1)
    var min_y := maxi(0, floori(camera.y / TILE))
    var max_y := mini(39, floori((camera.y + screen.y) / TILE)+1)
    for y in range(min_y, max_y+1):
        for x in range(min_x, max_x+1):
            var pos := Vector2(x*TILE, y*TILE) - camera
            var kind = blocks.get(Vector2i(x,y), "")
            if kind == "": continue
            var col: Color = block_colors.get(kind, Color.GRAY)
            draw_rect(Rect2(pos+Vector2(1,1), Vector2(TILE-2,TILE-2)), col)
            draw_rect(Rect2(pos+Vector2(2,2), Vector2(TILE-4,4)), col.lightened(0.18))
            if kind == "Dirt" or kind == "Stone":
                draw_rect(Rect2(pos+Vector2(5,12), Vector2(5,4)), col.darkened(0.14))
                draw_rect(Rect2(pos+Vector2(20,23), Vector2(7,4)), col.darkened(0.12))
    _draw_player(player_pos-camera)
    _draw_hud(screen)

func _draw_player(pos: Vector2) -> void:
    # Placeholder pixel character; replace with sprite sheets later.
    draw_rect(Rect2(pos+Vector2(-11,-42),Vector2(22,18)),Color("#f4c9a0"))
    draw_rect(Rect2(pos+Vector2(-12,-45),Vector2(24,7)),Color("#e9edf4"))
    draw_rect(Rect2(pos+Vector2(-13,-24),Vector2(26,18)),Color("#344d83"))
    draw_rect(Rect2(pos+Vector2(-10,-6),Vector2(8,6)),Color("#272c3c"))
    draw_rect(Rect2(pos+Vector2(2,-6),Vector2(8,6)),Color("#272c3c"))
    draw_rect(Rect2(pos+Vector2(5 if facing > 0 else -8,-35),Vector2(3,3)),Color("#222b39"))

func _draw_hud(screen: Vector2) -> void:
    draw_rect(Rect2(14,14,250,48),Color(0.05,0.1,0.18,0.78))
    draw_string(ThemeDB.fallback_font,Vector2(28,44),"GROWWORLD  •  GODOT",HORIZONTAL_ALIGNMENT_LEFT,-1,22,Color.WHITE)
    # Inventory hotbar sits above the controls.
    var slot_w := minf(76.0, (screen.x - 32.0) / 4.0)
    var bar_w := slot_w * 4.0
    var bx := (screen.x-bar_w)/2
    draw_rect(Rect2(bx-6,screen.y-166,bar_w+12,54),Color(0.05,0.1,0.18,0.86))
    for i in range(4):
        var r := Rect2(bx+i*slot_w,screen.y-160,slot_w-4,42)
        draw_rect(r,Color("#e8cb58") if i==selected_block else Color("#5287ad"))
        draw_rect(r.grow(-3),Color("#263e5b"))
        draw_rect(Rect2(r.position+Vector2(7,5),Vector2(18,18)),block_colors[block_names[i]])
        draw_string(ThemeDB.fallback_font,r.position+Vector2(5,36),str(inventory.get(block_names[i],0)),HORIZONTAL_ALIGNMENT_LEFT,-1,12,Color.WHITE)
    # Growtopia-style touch controls: move, jump, and punch.
    _button(Rect2(20,screen.y-102,72,72),"◀")
    _button(Rect2(98,screen.y-102,72,72),"▶")
    _button(Rect2(screen.x-174,screen.y-102,72,72),"↑")
    _button(Rect2(screen.x-94,screen.y-102,72,72),"✊")
    if toast_time > 0:
        var tw := 360.0
        draw_rect(Rect2((screen.x-tw)/2,screen.y*0.2,tw,44),Color(0.04,0.1,0.17,0.9))
        draw_string(ThemeDB.fallback_font,Vector2((screen.x-tw)/2+16,screen.y*0.2+28),toast,HORIZONTAL_ALIGNMENT_LEFT,-1,18,Color.WHITE)

func _button(rect: Rect2, label: String) -> void:
    draw_circle(rect.get_center(),rect.size.x/2,Color(0.08,0.17,0.28,0.78))
    draw_arc(rect.get_center(),rect.size.x/2,0,TAU,48,Color("#91cfff"),3)
    draw_string(ThemeDB.fallback_font,rect.get_center()+Vector2(-14,8),label,HORIZONTAL_ALIGNMENT_LEFT,-1,30,Color.WHITE)

func _screen_to_world(pos: Vector2) -> Vector2:
    var screen := get_viewport_rect().size
    var camera := Vector2(player_pos.x - screen.x*0.42, player_pos.y - screen.y*0.57)
    camera.x = clampf(camera.x,0,WORLD_WIDTH*TILE-screen.x)
    camera.y = clampf(camera.y,0,40*TILE-screen.y)
    return pos + camera

func _input(event: InputEvent) -> void:
    if event is InputEventKey and event.pressed and not event.echo:
        if event.keycode == KEY_SPACE or event.keycode == KEY_UP: jump_requested = true
        if event.keycode == KEY_F: _punch_block_in_front()
    if event is InputEventScreenTouch:
        if event.pressed:
            touch_start = event.position
            var screen := get_viewport_rect().size
            if event.position.y > screen.y-120:
                if event.position.x < 94: move_dir = -1
                elif event.position.x < 174: move_dir = 1
                elif event.position.x > screen.x-102: punch_requested = true
                elif event.position.x > screen.x-182: jump_requested = true
            elif event.position.y > screen.y-174 and event.position.y < screen.y-110:
                _select_hotbar(event.position)
            else:
                _interact_with_world(event.position)
        else:
            move_dir = 0
    if event is InputEventScreenDrag:
        var screen := get_viewport_rect().size
        if event.position.y > screen.y-120:
            if event.position.x < 94: move_dir = -1
            elif event.position.x < 174: move_dir = 1
            else: move_dir = 0

func _select_hotbar(pos: Vector2) -> void:
    var screen := get_viewport_rect().size
    var slot_w := minf(76.0, (screen.x - 32.0) / 4.0)
    var bx := (screen.x-(slot_w*4.0))/2.0
    if pos.y > screen.y-174 and pos.y < screen.y-110 and pos.x >= bx:
        selected_block = clampi(int((pos.x-bx)/slot_w),0,3)

func _interact_with_world(screen_pos: Vector2) -> void:
    var world_pos := _screen_to_world(screen_pos)
    var tile_pos := Vector2i(floori(world_pos.x / TILE), floori(world_pos.y / TILE))
    var center := Vector2(tile_pos * TILE) + Vector2(TILE / 2.0, TILE / 2.0)
    if center.distance_to(player_pos) > TILE * 4.0:
        toast = "Dekati blok untuk berinteraksi"
        toast_time = 1.0
        return
    if blocks.has(tile_pos):
        var kind: String = blocks[tile_pos]
        blocks.erase(tile_pos)
        inventory[kind] = int(inventory.get(kind, 0)) + 1
        toast = kind + " +1"
        toast_time = 1.0
        _save_world()
    else:
        _place_block(tile_pos)

func _place_block(tile_pos: Vector2i) -> void:
    var kind: String = block_names[selected_block]
    if int(inventory.get(kind, 0)) <= 0:
        toast = "Blok " + kind + " habis"
        toast_time = 1.0
        return
    if tile_pos.x < 0 or tile_pos.x >= WORLD_WIDTH or tile_pos.y < 0 or tile_pos.y >= 40:
        return
    var center := Vector2(tile_pos * TILE) + Vector2(TILE / 2.0, TILE / 2.0)
    if center.distance_to(player_pos) > TILE * 4.0:
        toast = "Terlalu jauh untuk memasang blok"
        toast_time = 1.0
        return
    var attached := false
    for offset in [Vector2i.LEFT, Vector2i.RIGHT, Vector2i.UP, Vector2i.DOWN]:
        if blocks.has(tile_pos + offset):
            attached = true
            break
    if not attached:
        toast = "Pasang blok di sebelah blok lain"
        toast_time = 1.0
        return
    var player_rect := Rect2(player_pos - Vector2(PLAYER_SIZE.x / 2.0, PLAYER_SIZE.y), PLAYER_SIZE)
    if player_rect.intersects(Rect2(Vector2(tile_pos * TILE), Vector2(TILE, TILE))):
        toast = "Tidak bisa memasang blok di tubuh karakter"
        toast_time = 1.0
        return
    blocks[tile_pos] = kind
    inventory[kind] = int(inventory[kind]) - 1
    toast = kind + " dipasang"
    toast_time = 1.0
    _save_world()


func _punch_block_in_front() -> void:
    var target := Vector2i(floori((player_pos.x + facing * (PLAYER_SIZE.x / 2.0 + TILE * 0.65)) / TILE), floori((player_pos.y - PLAYER_SIZE.y * 0.58) / TILE))
    if not blocks.has(target):
        target.y += 1
    if blocks.has(target):
        var kind: String = blocks[target]
        blocks.erase(target)
        inventory[kind] = int(inventory.get(kind, 0)) + 1
        toast = kind + " dihancurkan +1"
        toast_time = 1.0
        _save_world()
    else:
        toast = "Tidak ada blok di depan"
        toast_time = 0.7
