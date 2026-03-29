extends CanvasLayer
## Iris wipe scene transition (Animal Crossing style).

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
	float aspect = SCREEN_PIXEL_SIZE.y / SCREEN_PIXEL_SIZE.x;
	vec2 uv = SCREEN_UV;
	uv.x *= aspect;
	vec2 c = center;
	c.x *= aspect;

	float dist = distance(uv, c);

	float alpha = smoothstep(radius - smoothness, radius + smoothness, dist);
	COLOR = vec4(0.0, 0.0, 0.0, alpha);
}
"

	_shader_material = ShaderMaterial.new()
	_shader_material.shader = shader
	_shader_material.set_shader_parameter("radius", 1.5)
	_color_rect.material = _shader_material
	add_child(_color_rect)

	_color_rect.set_anchors_preset(Control.PRESET_FULL_RECT)
	_color_rect.size = get_viewport().get_visible_rect().size

func _process(_delta: float) -> void:
	if _color_rect:
		_color_rect.size = get_viewport().get_visible_rect().size

## Prepare the iris overlay (call before the close tween to avoid a 1-frame gap).
func prepare_close(focus_uv: Vector2 = Vector2(0.5, 0.5)) -> void:
	_color_rect.visible = true
	_color_rect.mouse_filter = Control.MOUSE_FILTER_STOP
	_shader_material.set_shader_parameter("center", focus_uv)
	_shader_material.set_shader_parameter("radius", 1.5)

## Close the iris (black creeps in from borders).
## If prepare_close() was already called, skips re-preparation.
func iris_close(focus_uv: Vector2 = Vector2(0.5, 0.5), duration: float = 0.6) -> void:
	if not _color_rect.visible:
		prepare_close(focus_uv)

	var tween := create_tween()
	tween.tween_property(_shader_material, "shader_parameter/radius", 0.0, duration) \
		.set_ease(Tween.EASE_IN).set_trans(Tween.TRANS_SINE)
	await tween.finished

## Change scene while fully black, then open the iris.
func iris_open_with_scene(scene_path: String, duration: float = 0.5) -> void:
	get_tree().change_scene_to_file(scene_path)
	await get_tree().process_frame

	_shader_material.set_shader_parameter("center", Vector2(0.5, 0.5))
	_shader_material.set_shader_parameter("radius", 0.0)
	var tween := create_tween()
	tween.tween_property(_shader_material, "shader_parameter/radius", 1.5, duration) \
		.set_ease(Tween.EASE_OUT).set_trans(Tween.TRANS_SINE)
	await tween.finished

	_color_rect.visible = false
	_color_rect.mouse_filter = Control.MOUSE_FILTER_IGNORE

## Convenience: full transition in one call.
func iris_to(scene_path: String, focus_uv: Vector2 = Vector2(0.5, 0.5), close_duration: float = 0.5, open_duration: float = 0.4) -> void:
	await iris_close(focus_uv, close_duration)
	await get_tree().create_timer(0.1).timeout
	await iris_open_with_scene(scene_path, open_duration)
