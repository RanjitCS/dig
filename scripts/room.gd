class_name Room
extends Node2D

# Generic Room base. Each placeholder room scene uses this as its root script.
# The bedroom has its own specialized script (bedroom.gd) that does the same
# activate/deactivate pattern plus tool-wall + bed interactions.

const CharacterFigureScene := preload("res://scenes/character_figure.tscn")

@export var room_id: StringName = &""
@export var default_spawn_x: float = 200.0

@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera2D

var _figures: Array = []  # spawned CharacterFigure instances for today's occupants

func _ready() -> void:
	if room_id == &"":
		push_warning("Room scene '%s' has no room_id" % name)
	GameState.room_changed.connect(_on_room_changed)
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.placements_changed.connect(_on_placements_changed)
	call_deferred("_initial_check")

func _on_placements_changed() -> void:
	# Rebuild occupants if we're the active room (otherwise they rebuild on activate).
	if visible:
		_spawn_occupants()

func _initial_check() -> void:
	_apply_visibility()

func _apply_visibility() -> void:
	# Visible if the house phase AND this is the active room.
	var should_show: bool = (
		GameState.phase == GameState.Phase.HOUSE_INTERIOR
		and GameState.current_room == room_id
	)
	if should_show:
		_activate()
	else:
		_deactivate()

func _on_room_changed(new_room: StringName, spawn_x: float) -> void:
	if GameState.phase != GameState.Phase.HOUSE_INTERIOR:
		return
	if new_room == room_id:
		_activate(spawn_x)
	else:
		_deactivate()

func _on_phase_changed(_p: int) -> void:
	_apply_visibility()

func _activate(spawn_x: float = NAN) -> void:
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	var x: float = default_spawn_x if is_nan(spawn_x) else spawn_x
	if player != null:
		player.reset_to(Vector2(x, -24))
	if camera != null:
		camera.make_current()
	_spawn_occupants()

func _deactivate() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED
	_clear_occupants()

# Spawn a CharacterFigure for each character the daily placement puts in this room.
func _spawn_occupants() -> void:
	_clear_occupants()
	var occupants: Array = GameState.characters_in_room(room_id)
	if occupants.is_empty():
		return
	# Spread them across the room floor, avoiding the door/edges. Rooms are ~1400 wide.
	var span_lo := 260.0
	var span_hi := 1140.0
	var n := occupants.size()
	for i in n:
		var fig := CharacterFigureScene.instantiate()
		add_child(fig)
		fig.configure(occupants[i])
		var t: float = 0.5 if n == 1 else float(i) / float(n - 1)
		var fx: float = lerp(span_lo, span_hi, t)
		fig.position = Vector2(fx, -8)
		_figures.append(fig)

func _clear_occupants() -> void:
	for f in _figures:
		if is_instance_valid(f):
			f.queue_free()
	_figures.clear()
