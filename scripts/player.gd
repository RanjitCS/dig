class_name Player
extends CharacterBody2D

const SIZE: Vector2 = Vector2(36, 44)

@export var move_speed: float = 220.0
@export var jump_velocity: float = -460.0
@export var gravity: float = 1200.0
@export var max_fall_speed: float = 900.0
@export var coyote_time: float = 0.10
@export var jump_buffer_time: float = 0.10
@export var air_control: float = 0.85  # 1.0 = full control in air

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
	var accel: float = move_speed if is_on_floor() else move_speed * air_control
	if input_x != 0.0:
		velocity.x = lerp(velocity.x, input_x * move_speed, accel * delta / move_speed)
	else:
		velocity.x = lerp(velocity.x, 0.0, accel * delta / move_speed)

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

func facing_dir() -> int:
	return _facing

func reset_to(pos: Vector2) -> void:
	position = pos
	velocity = Vector2.ZERO
	_coyote_timer = 0.0
	_jump_buffer_timer = 0.0
