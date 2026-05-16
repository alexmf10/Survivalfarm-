class_name BossSpriteSetup
extends AnimatedSprite2D

const FRAME_SIZE: Vector2i = Vector2i(48, 96)
const FRAMES_PER_DIRECTION: int = 6

const DIRECTIONS: Array[String] = ["right", "up", "left", "down"]
const SHEETS: Dictionary = {
	"idle": "res://assets/sprites/boss/idle.png",
	"walk": "res://assets/sprites/boss/walk.png",
	"attack": "res://assets/sprites/boss/punch.png",
	"hurt": "res://assets/sprites/boss/hit.png",
}
const SPEEDS: Dictionary = {
	"idle": 8.0,
	"walk": 9.0,
	"attack": 10.0,
	"hurt": 8.0,
}


func _enter_tree() -> void:
	sprite_frames = _build_sprite_frames()
	animation = &"idle_down"


func _ready() -> void:
	play(&"idle_down")


func _build_sprite_frames() -> SpriteFrames:
	var frames := SpriteFrames.new()
	frames.remove_animation(&"default")

	for prefix in SHEETS.keys():
		var sheet_path: String = SHEETS[prefix]
		var texture: Texture2D = load(sheet_path) as Texture2D
		if texture == null:
			push_error("BossSpriteSetup: could not load %s" % sheet_path)
			continue

		for direction_index in range(DIRECTIONS.size()):
			var direction: String = DIRECTIONS[direction_index]
			var anim_name := "%s_%s" % [prefix, direction]
			frames.add_animation(anim_name)
			frames.set_animation_speed(anim_name, float(SPEEDS[prefix]))
			frames.set_animation_loop(anim_name, prefix == "idle" or prefix == "walk")

			for frame_index in range(FRAMES_PER_DIRECTION):
				var atlas := AtlasTexture.new()
				atlas.atlas = texture
				atlas.region = Rect2(
					(direction_index * FRAMES_PER_DIRECTION + frame_index) * FRAME_SIZE.x,
					0,
					FRAME_SIZE.x,
					FRAME_SIZE.y
				)
				frames.add_frame(anim_name, atlas)

	return frames
