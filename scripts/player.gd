class_name Player
extends CharacterBody2D

const SIZE: Vector2 = Vector2(36, 44)

@export var move_speed: float = 220.0
@export var ground_accel: float = 2200.0      # px/s^2
@export var ground_decel: float = 3000.0      # px/s^2 (stops on a dime)
@export var air_accel: float = 1400.0
@export var air_decel: float = 800.0
@export var jump_velocity: float = -400.0  # base; clears ~1 block (apex ~67px at g=1200). Spring Boots adds to this.
@export var gravity: float = 1200.0
@export var max_fall_speed: float = 900.0
@export var coyote_time: float = 0.10
@export var jump_buffer_time: float = 0.10

@onready var sprite: Sprite2D = $Sprite
@onready var fallback_rect: ColorRect = $FallbackRect

var _coyote_timer: float = 0.0
var _jump_buffer_timer: float = 0.0
var _facing: int = 1  # 1 = right, -1 = left
var _dig_cooldown: float = 0.0  # seconds until next swing allowed

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
		velocity.y = _jump_speed()
		_jump_buffer_timer = 0.0
		_coyote_timer = 0.0

	# Variable jump height: cut upward velocity if jump released early.
	if Input.is_action_just_released("jump") and velocity.y < 0.0:
		velocity.y *= 0.45

	move_and_slide()

	# --- dig action (hold to dig; per-tool cooldown gates each swing) ---
	_dig_cooldown = max(0.0, _dig_cooldown - delta)
	if Input.is_action_pressed("dig") and _dig_cooldown <= 0.0:
		var tool := GameState.equipped_upgrade()
		var cooldown: float = _tool_cooldown(tool)
		if _try_dig(tool):
			_dig_cooldown = cooldown

func _tool_level(tool: Upgrade) -> int:
	if tool == null:
		return 0
	return GameState.level_of(tool.id)

func _tool_damage(tool: Upgrade) -> int:
	if tool == null:
		return 1
	return tool.damage_at(_tool_level(tool))

# Jump speed = base + any rocket-boots bonus. Both are "upward", and upward is
# negative in Godot 2D, so a positive bonus is subtracted to jump higher.
func _jump_speed() -> float:
	var bonus := GameState._sum_effect(Upgrade.Effect.JUMP_VELOCITY_BONUS)
	return jump_velocity - bonus

func _tool_cooldown(tool: Upgrade) -> float:
	var base := 0.20 if tool == null else tool.cooldown_at(_tool_level(tool))
	# A special day can speed up (Dad sharpened the spade) or slow down (groundwater)
	# the swing. dig_speed_mult > 1 = faster = shorter cooldown.
	var speed := GameState.today_event_dig_speed_mult()
	if speed > 0.0:
		base /= speed
	return base

# Returns true if a dig actually landed (block existed in the targeted cell(s)).
func _try_dig(tool: Upgrade) -> bool:
	var world := get_parent()
	if world == null or not world.has_method("try_dig_at"):
		return false
	var damage: int = _tool_damage(tool)
	var column_only: bool = tool != null and tool.tool_column_only
	if column_only:
		var feet_cell: Vector2i = world.world_pos_to_grid(global_position + Vector2(0, SIZE.y * 0.5 + 4))
		return world.try_dig_at(feet_cell, damage, false)
	var aoe_capable: bool = tool != null and tool.tool_aoe
	var aoe_this_swing: bool = aoe_capable and Input.is_action_pressed("move_down")
	for target in _dig_candidates():
		if world.try_dig_at(target, damage, aoe_this_swing):
			return true
	return false

func _dig_candidates() -> Array:
	var world := get_parent()
	var feet := global_position + Vector2(0, SIZE.y * 0.5 + 4)
	var head := global_position - Vector2(0, SIZE.y * 0.5 + 4)
	var fwd_low := global_position + Vector2(float(_facing) * (SIZE.x * 0.5 + 4), SIZE.y * 0.25)
	var fwd_at_floor := Vector2(global_position.x + float(_facing) * (SIZE.x * 0.5 + 4), max(global_position.y + SIZE.y * 0.4, 4.0))
	if Input.is_action_pressed("move_down"):
		return [world.world_pos_to_grid(feet)]
	if Input.is_action_pressed("move_up"):
		return [world.world_pos_to_grid(head)]
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
