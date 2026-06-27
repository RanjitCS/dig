extends Node2D

# Bedroom (currently the only room). Owns the player while phase == HOUSE_INTERIOR.
# Future rooms will hook into a room-switch system via doors.

@onready var player: Player = $Player
@onready var bed: Interactable = $Bed
@onready var door: Interactable = $Door
@onready var tool_hooks: Node2D = $ToolHooks
@onready var equipped_label: Label = $EquippedLabel

var _hook_for_tool: Dictionary = {}

func _ready() -> void:
	bed.interacted.connect(_on_bed_used)
	door.interacted.connect(_on_door_used)
	# Each ToolHook child is named like "Spade", "Pickaxe" — id derived from name.
	for child in tool_hooks.get_children():
		if not (child is Interactable):
			continue
		var hook: Interactable = child
		var tool_id := StringName(hook.name.to_snake_case())
		var up := GameState.get_upgrade(tool_id)
		if up == null:
			hook.queue_free()
			continue
		_hook_for_tool[tool_id] = hook
		hook.set_prompt("[E] %s" % up.display_name)
		hook.interacted.connect(_on_tool_hook_used.bind(tool_id))
	GameState.equipped_changed.connect(_on_equipped_changed)
	GameState.phase_changed.connect(_on_phase_changed)
	_refresh_equipped_label()
	_reset_player_to_bed_spawn()

func activate() -> void:
	_reset_player_to_bed_spawn()
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT

func deactivate() -> void:
	visible = false
	process_mode = Node.PROCESS_MODE_DISABLED

func _reset_player_to_bed_spawn() -> void:
	player.reset_to(Vector2(160, -24))

func _on_bed_used() -> void:
	GameState.skip_to_end_of_day()

func _on_door_used() -> void:
	GameState.set_phase(GameState.Phase.DIGGING)

func _on_tool_hook_used(tool_id: StringName) -> void:
	GameState.equip(tool_id)

func _on_equipped_changed(_id: StringName) -> void:
	_refresh_equipped_label()

func _on_phase_changed(p: int) -> void:
	if p == GameState.Phase.HOUSE_INTERIOR:
		activate()
	else:
		deactivate()

func _refresh_equipped_label() -> void:
	var up := GameState.equipped_upgrade()
	if up != null:
		equipped_label.text = "Equipped: %s" % up.display_name
	else:
		equipped_label.text = "Equipped: (none)"
