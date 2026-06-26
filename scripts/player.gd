class_name Player
extends CharacterBody2D

const SIZE: Vector2 = Vector2(36, 44)

@export var move_speed: float = 220.0
@export var ground_accel: float = 2200.0      # px/s^2
@export var ground_decel: float = 3000.0      # px/s^2 (stops on a dime)
@export var air_accel: float = 1400.0
@export var air_decel: float = 800.0
@export var jump_velocity: float = -460.0
@export var gravity: float = 1200.0
@export var max_fall_speed: float = 900.0
@export var coyote_time: float = 0.10
@export var jump_buffer_time: float = 0.10

@onready var sprite: Sprite2D = $Sprite
@onready var fallback_rect: ColorRect = $FallbackRect

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _facing: int = 1  # 1 = right, -1 = left

signal facing_changed(direction: int)

func _ready() -> void:
	_apply_visuals()

func _apply_visuals() -> void:
	if sprite.texture != null:
		sprite.visible = true
		fallback_rect.visible = false
	else:
		sprite.visible = false
		fallback_rect.visible = true
		fallback_rect.size = SIZE
		fallback_rect.position = -SIZE * 0.5

func _physics_process(delta: float) -> void:
	# --- horizontal ---
	var input_x := Input.get_axis("move_left", "move_right")
	if input_x != 0.0:
		var new_facing := 1 if input_x > 0.0 else -1
		if new_facing != _facing:
			_facing = new_facing
			facing_changed.emit(_facing)
	var on_floor := is_on_floor()
	var target_x := input_x * move_speed
	var rate := 0.0
	if input_x != 0.0:
		rate = ground_accel if on_floor else air_accel
	else:
		rate = ground_decel if on_floor else air_decel
	velocity.x = move_toward(velocity.x, target_x, rate * delta)

	# --- gravity ---
	if not is_on_floor():
		velocity.y += gravity * delta
		velocity.y = min(velocity.y, max_fall_speed)

	# --- coyote timer ---
	if is_on_floor():
		_coyote_timer = coyote_time
	else:
		_coyote_timer = max(0.0, _coyote_timer - delta)

	# --- jump buffer ---
	if Input.is_action_just_pressed("jump"):
		_jump_buffer_timer = jump_buffer_time
	else:
		_jump_buffer_timer = max(0.0, _jump_buffer_timer - delta)

	# --- jump ---
	if _jump_buffer_timer > 0.0 and _coyote_timer > 0.0:
		velocity.y = jump_velocity
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0

	# Variable jump height: cut upward velocity if jump released early.
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.45

	move_and_slide()

	# --- dig action ---
	if Input.is_action_just_pressed("dig"):
		_try_dig()

func _try_dig() -> void:
	var world := get_parent()
	if world == null or not world.has_method("try_dig_at"):
		Logger.wrn("player.dig: no world parent (parent=%s)" % str(get_parent()))
		return
	Logger.dbg("player.dig pos=%s facing=%d down=%s up=%s" % [
		str(global_position), _facing,
		str(Input.is_action_pressed("move_down")),
		str(Input.is_action_pressed("move_up")),
	])
	var candidates := _dig_candidates()
	Logger.dbg("  candidates: %s" % str(candidates))
	for target in candidates:
		var ok: bool = world.try_dig_at(target)
		Logger.dbg("    target=%s ok=%s" % [str(target), str(ok)])
		if ok:
			return

func _dig_candidates() -> Array:
	var world := get_parent()
	# Sample points at the player's feet, head, and at chest-height in front.
	# All three are nudged slightly so they land *inside* the target grid cell.
	var feet := global_position + Vector2(0, SIZE.y * 0.5 + 4)
	var head := global_position - Vector2(0, SIZE.y * 0.5 + 4)
	var fwd_low := global_position + Vector2(float(_facing) * (SIZE.x * 0.5 + 4), SIZE.y * 0.25)
	var fwd_at_floor := Vector2(global_position.x + float(_facing) * (SIZE.x * 0.5 + 4), max(global_position.y + SIZE.y * 0.4, 4.0))
	if Input.is_action_pressed("move_down"):
		return [world.world_pos_to_grid(feet)]
	if Input.is_action_pressed("move_up"):
		return [world.world_pos_to_grid(head)]
	# Default: forward (chest-high), then forward-at-floor, then straight down.
	return [
		world.world_pos_to_grid(fwd_low),
		world.world_pos_to_grid(fwd_at_floor),
		world.world_pos_to_grid(feet),
	]

func facing_dir() -> int:
	return _facing

func reset_to(pos: Vector2) -> void:
	position = pos
	velocity = Vector2.ZERO
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
