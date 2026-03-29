extends Control
## Fish-fighting minigame overlay. Player uses a virtual joystick to keep
## a swimming fish inside a circle arena for 10 seconds.

signal fish_caught
signal fish_escaped

# Arena
const ARENA_RADIUS: float = 140.0
const CATCH_DURATION: float = 10.0
const ESCAPE_DURATION: float = 2.0

# Joystick
const JOYSTICK_MAX_RADIUS: float = 80.0
const JOYSTICK_DEAD_ZONE: float = 10.0
const PULL_FORCE: float = 400.0

# Fish movement base values (scaled by difficulty and progress)
const BASE_SPEED_MIN: float = 60.0
const BASE_SPEED_MAX: float = 200.0
const DIRECTION_INTERVAL_MIN: float = 0.3
const DIRECTION_INTERVAL_MAX: float = 2.0
const TURN_RATE_MIN: float = 2.0
const TURN_RATE_MAX: float = 5.0

# Visual
const OVERLAY_COLOR := Color(0.05, 0.1, 0.2, 0.7)
const ARENA_COLOR := Color(0.1, 0.15, 0.3, 0.9)
const ARENA_BORDER_COLOR := Color(0.3, 0.4, 0.6, 0.8)
const FISH_COLOR := Color(0.9, 0.9, 0.95, 1.0)
const JOYSTICK_BASE_COLOR := Color(1.0, 1.0, 1.0, 0.15)
const JOYSTICK_KNOB_COLOR := Color(1.0, 1.0, 1.0, 0.6)
const PROGRESS_BG_COLOR := Color(1.0, 1.0, 1.0, 0.15)
const PROGRESS_FILL_COLOR := Color(0.3, 0.8, 0.4, 0.8)
const ESCAPE_WARNING_COLOR := Color(1.0, 0.3, 0.2, 0.8)

# State
var active: bool = false
var fish_pos: Vector2 = Vector2.ZERO
var fish_velocity: Vector2 = Vector2.ZERO
var fish_target_dir: Vector2 = Vector2.RIGHT
var direction_change_timer: float = 1.0
var catch_timer: float = 0.0
var escape_timer: float = 0.0
var elapsed: float = 0.0
var difficulty: float = 0.5

# Joystick state
var touch_active: bool = false
var touch_base: Vector2 = Vector2.ZERO
var touch_current: Vector2 = Vector2.ZERO
var joystick_direction: Vector2 = Vector2.ZERO

var arena_center: Vector2 = Vector2.ZERO

func start_minigame() -> void:
	active = true
	arena_center = size / 2.0
	fish_pos = Vector2.ZERO
	fish_velocity = Vector2.from_angle(randf() * TAU) * 30.0
	fish_target_dir = Vector2.from_angle(randf() * TAU)
	direction_change_timer = 1.5
	catch_timer = 0.0
	escape_timer = 0.0
	elapsed = 0.0
	difficulty = randf_range(0.2, 0.9)
	touch_active = false
	joystick_direction = Vector2.ZERO
	queue_redraw()

func _process(delta: float) -> void:
	if not active or not visible:
		return

	elapsed += delta

	# Accelerating difficulty over time
	var progress := clampf(elapsed / CATCH_DURATION, 0.0, 1.0)
	var speed := lerpf(BASE_SPEED_MIN, BASE_SPEED_MAX, progress) * lerpf(0.8, 1.3, difficulty)
	var change_interval := lerpf(DIRECTION_INTERVAL_MAX, DIRECTION_INTERVAL_MIN, progress) * lerpf(1.0, 0.6, difficulty)
	var turn_rate := lerpf(TURN_RATE_MIN, TURN_RATE_MAX, progress) * lerpf(0.8, 1.2, difficulty)

	# Steer fish toward target direction
	var target_velocity := fish_target_dir * speed
	fish_velocity = fish_velocity.lerp(target_velocity, turn_rate * delta)

	# Apply joystick pull force
	if touch_active and joystick_direction.length_squared() > 0.0:
		fish_velocity += joystick_direction * PULL_FORCE * delta

	# Update position
	fish_pos += fish_velocity * delta

	# Soft boundary — gentle push back when fish is very far out
	var dist := fish_pos.length()
	if dist > ARENA_RADIUS * 1.8:
		var push_back := -fish_pos.normalized() * 50.0 * delta
		fish_velocity += push_back

	# Boundary checks for win/lose
	if dist <= ARENA_RADIUS:
		catch_timer += delta
		escape_timer = 0.0
	else:
		escape_timer += delta

	# Direction changes on timer
	direction_change_timer -= delta
	if direction_change_timer <= 0.0:
		fish_target_dir = Vector2.from_angle(randf() * TAU)
		direction_change_timer = change_interval

	# Win/lose conditions
	if catch_timer >= CATCH_DURATION:
		active = false
		fish_caught.emit()
		return
	if escape_timer >= ESCAPE_DURATION:
		active = false
		fish_escaped.emit()
		return

	queue_redraw()

func _input(event: InputEvent) -> void:
	if not active or not visible:
		return

	# Touch input
	if event is InputEventScreenTouch:
		if event.pressed:
			touch_active = true
			touch_base = event.position
			touch_current = event.position
			joystick_direction = Vector2.ZERO
		else:
			touch_active = false
			joystick_direction = Vector2.ZERO
		get_viewport().set_input_as_handled()

	elif event is InputEventScreenDrag:
		if touch_active:
			touch_current = event.position
			_update_joystick_direction()
		get_viewport().set_input_as_handled()

	# Mouse input (desktop testing)
	elif event is InputEventMouseButton and event.button_index == MOUSE_BUTTON_LEFT:
		if event.pressed:
			touch_active = true
			touch_base = event.position
			touch_current = event.position
			joystick_direction = Vector2.ZERO
		else:
			touch_active = false
			joystick_direction = Vector2.ZERO
		get_viewport().set_input_as_handled()

	elif event is InputEventMouseMotion and touch_active:
		touch_current = event.position
		_update_joystick_direction()
		get_viewport().set_input_as_handled()

func _update_joystick_direction() -> void:
	var delta_vec := touch_current - touch_base
	if delta_vec.length() > JOYSTICK_DEAD_ZONE:
		joystick_direction = delta_vec.normalized()
	else:
		joystick_direction = Vector2.ZERO

func _draw() -> void:
	if not active:
		return

	# Full-screen dark overlay
	draw_rect(Rect2(Vector2.ZERO, size), OVERLAY_COLOR)

	# Arena circle
	draw_circle(arena_center, ARENA_RADIUS + 3.0, ARENA_BORDER_COLOR)
	draw_circle(arena_center, ARENA_RADIUS, ARENA_COLOR)

	# Progress arc around arena
	_draw_progress_arc()

	# Escape warning — arena border flashes red when fish is outside
	if escape_timer > 0.0:
		var warning_alpha := (escape_timer / ESCAPE_DURATION) * 0.8
		var warning_color := Color(ESCAPE_WARNING_COLOR, warning_alpha)
		draw_arc(arena_center, ARENA_RADIUS + 5.0, 0.0, TAU, 64, warning_color, 4.0)

	# Fish
	_draw_fish()

	# Joystick
	if touch_active:
		_draw_joystick()

	# Timer text
	var remaining := maxf(0.0, CATCH_DURATION - catch_timer)
	var timer_text := "%.1fs" % remaining
	var font := ThemeDB.fallback_font
	var font_size := 18
	var text_size := font.get_string_size(timer_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size)
	var text_pos := Vector2(arena_center.x - text_size.x / 2.0, arena_center.y - ARENA_RADIUS - 20.0)
	draw_string(font, text_pos, timer_text, HORIZONTAL_ALIGNMENT_CENTER, -1, font_size, Color.WHITE)

func _draw_progress_arc() -> void:
	var progress := clampf(catch_timer / CATCH_DURATION, 0.0, 1.0)
	var arc_radius := ARENA_RADIUS + 10.0
	# Background arc
	draw_arc(arena_center, arc_radius, 0.0, TAU, 64, PROGRESS_BG_COLOR, 3.0)
	# Fill arc (from top, clockwise)
	if progress > 0.0:
		var start_angle := -PI / 2.0
		var end_angle := start_angle + TAU * progress
		draw_arc(arena_center, arc_radius, start_angle, end_angle, 64, PROGRESS_FILL_COLOR, 3.0)

func _draw_fish() -> void:
	var fish_world_pos := arena_center + fish_pos
	var angle := fish_velocity.angle() if fish_velocity.length_squared() > 1.0 else 0.0
	var fish_size := 18.0

	# Fish body — elongated diamond shape
	var points := PackedVector2Array([
		Vector2(fish_size * 1.4, 0.0),    # nose
		Vector2(-fish_size * 0.4, fish_size * 0.5),  # top fin
		Vector2(-fish_size * 0.8, 0.0),   # back
		Vector2(-fish_size * 0.4, -fish_size * 0.5), # bottom fin
	])

	# Tail
	var tail_points := PackedVector2Array([
		Vector2(-fish_size * 0.7, 0.0),
		Vector2(-fish_size * 1.3, fish_size * 0.45),
		Vector2(-fish_size * 1.3, -fish_size * 0.45),
	])

	# Rotate and translate
	var rotated_body := PackedVector2Array()
	for p in points:
		rotated_body.append(fish_world_pos + p.rotated(angle))

	var rotated_tail := PackedVector2Array()
	for p in tail_points:
		rotated_tail.append(fish_world_pos + p.rotated(angle))

	draw_colored_polygon(rotated_tail, Color(FISH_COLOR, 0.7))
	draw_colored_polygon(rotated_body, FISH_COLOR)

	# Eye
	var eye_offset := Vector2(fish_size * 0.6, -fish_size * 0.15).rotated(angle)
	draw_circle(fish_world_pos + eye_offset, 2.5, Color(0.1, 0.1, 0.2))

func _draw_joystick() -> void:
	# Base ring
	draw_arc(touch_base, JOYSTICK_MAX_RADIUS, 0.0, TAU, 32, JOYSTICK_BASE_COLOR, 2.0)
	draw_circle(touch_base, JOYSTICK_MAX_RADIUS, Color(JOYSTICK_BASE_COLOR, 0.05))

	# Knob — clamped to max radius
	var delta_vec := touch_current - touch_base
	var clamped_offset := delta_vec
	if delta_vec.length() > JOYSTICK_MAX_RADIUS:
		clamped_offset = delta_vec.normalized() * JOYSTICK_MAX_RADIUS
	var knob_pos := touch_base + clamped_offset
	draw_circle(knob_pos, 22.0, JOYSTICK_KNOB_COLOR)
