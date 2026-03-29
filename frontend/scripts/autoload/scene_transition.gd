extends CanvasLayer
## Iris wipe scene transition (Animal Crossing style).
## Call SceneTransition.iris_to("res://scenes/...") from anywhere.

var _color_rect: ColorRect
var _shader_material: ShaderMaterial

func _ready() -> void:
	layer = 100
	_setup_overlay()

func _setup_overlay() -> void:
	_color_rect = ColorRect.new()
	_color_rect.color = Color.WHITE
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_color_rect.visible = false

	var shader := Shader.new()
	shader.code = "
shader_type canvas_item;

uniform float radius : hint_range(0.0, 1.5) = 1.5;
uniform vec2 center = vec2(0.5, 0.5);
uniform float smoothness : hint_range(0.0, 0.05) = 0.015;

void fragment() {
	// Correct for aspect ratio so the circle is round, not elliptical.
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 uv = SCREEN_UV;
	uv.x *= aspect;
	vec2 c = center;
	c.x *= aspect;

	float dist = distance(uv, c);

	// Outside the radius = black, inside = transparent.
	float alpha = smoothstep(radius - smoothness, radius + smoothness, dist);
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
"

	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	_shader_material.set_shader_parameter("radius", 1.5)
	_color_rect.material = _shader_material
	add_child(_color_rect)

	# Set anchors to fill the screen after adding to the tree.
	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_color_rect.size = get_viewport().get_visible_rect().size

func _process(_delta: float) -> void:
	# Keep the overlay sized to the viewport.
	if _color_rect:
		_color_rect.size = get_viewport().get_visible_rect().size

## Transition to a scene with iris close -> scene change -> iris open.
## focus_uv: the screen-space UV point to close the iris onto (default: center).
func iris_to(scene_path: String, focus_uv: Vector2 = Vector2(0.5, 0.5), close_duration: float = 0.6, open_duration: float = 0.5) -> void:
	_color_rect.visible = true
	_color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_shader_material.set_shader_parameter("center", focus_uv)
	_shader_material.set_shader_parameter("radius", 1.5)

	# Close iris: shrink circle from fully open to zero.
	var close_tween := create_tween()
	close_tween.tween_property(_shader_material, "shader_parameter/radius", 0.0, close_duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_CUBIC)
	await close_tween.finished

	# Brief pause at full black.
	await get_tree().create_timer(0.15).timeout

	# Change scene.
	get_tree().change_scene_to_file(scene_path)

	# Wait a frame for the new scene to initialize.
	await get_tree().process_frame

	# Open iris: expand circle from zero to fully open, centered on new scene.
	_shader_material.set_shader_parameter("center", Vector2(0.5, 0.5))
	_shader_material.set_shader_parameter("radius", 0.0)
	var open_tween := create_tween()
	open_tween.tween_property(_shader_material, "shader_parameter/radius", 1.5, open_duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_CUBIC)
	await open_tween.finished

	_color_rect.visible = false
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE
