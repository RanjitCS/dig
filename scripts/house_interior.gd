extends Node2D

# Bedroom (currently the only room). Owns the player while phase == HOUSE_INTERIOR.
# Future rooms will hook into a room-switch system via doors.

@onready var player: Player = $Player
@onready var camera: Camera2D = $Player/Camera2D
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
		hook.interacted.connect(_on_tool_hook_used.bind(tool_id))
	GameState.equipped_changed.connect(_on_equipped_changed)
	GameState.phase_changed.connect(_on_phase_changed)
	GameState.money_changed.connect(_on_money_changed)
	GameState.upgrade_purchased.connect(_on_upgrade_purchased)
	GameState.cutscene_triggered.connect(_on_cutscene_started)
	call_deferred("_connect_cutscene_finish")
	_refresh_equipped_label()
	_refresh_hook_visibility()
	_refresh_hook_prompts()
	_reset_player_to_bed_spawn()
	# Defer initial activation by one frame so cameras can resolve cleanly.
	call_deferred("_initial_phase_check")

func _connect_cutscene_finish() -> void:
	var modal := get_tree().root.find_child("CutsceneModal", true, false)
	if modal != null and modal.has_signal("cutscene_finished"):
		if not modal.cutscene_finished.is_connected(_on_cutscene_finished):
			modal.cutscene_finished.connect(_on_cutscene_finished)

func _on_cutscene_started(_scene) -> void:
	if player != null:
		player.process_mode = Node.PROCESS_MODE_DISABLED

func _on_cutscene_finished() -> void:
	if player != null and visible:
		player.process_mode = Node.PROCESS_MODE_INHERIT

func _on_money_changed(_v: float) -> void:
	_refresh_hook_visibility()

func _on_upgrade_purchased(_id: StringName, _level: int) -> void:
	_refresh_hook_prompts()
	_refresh_equipped_label()

func _refresh_hook_prompts() -> void:
	for tool_id in _hook_for_tool.keys():
		var hook: Interactable = _hook_for_tool[tool_id]
		var up := GameState.get_upgrade(tool_id)
		if up == null:
			continue
		var lvl: int = GameState.level_of(tool_id)
		hook.set_prompt("[E] %s" % up.tier_name_at(lvl))

func _refresh_hook_visibility() -> void:
	# Only show tool hooks for tools the player has actually unlocked.
	# (unlock gated on total money earned per Upgrade.unlock_money.)
	for tool_id in _hook_for_tool.keys():
		var hook: Interactable = _hook_for_tool[tool_id]
		var unlocked: bool = GameState.is_unlocked(tool_id)
		hook.visible = unlocked
		hook.enabled = unlocked
		# Also hide any sibling visual children that match the tool name + "Visual".
		# (Spade has a SpadeVisual sibling on tool_hooks, etc.)
		var visual_name := String(tool_id).capitalize() + "Visual"
		var v: Node = tool_hooks.get_node_or_null(visual_name)
		if v == null:
			# Visuals are children OF the hook itself in this scene tree.
			v = hook.get_node_or_null(visual_name)
		if v != null and v is CanvasItem:
			(v as CanvasItem).visible = unlocked

func _initial_phase_check() -> void:
	_on_phase_changed(GameState.phase)

func activate() -> void:
	_reset_player_to_bed_spawn()
	visible = true
	process_mode = Node.PROCESS_MODE_INHERIT
	if camera != null:
		camera.make_current()

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
		var lvl: int = GameState.level_of(up.id)
		equipped_label.text = "Equipped: %s" % up.tier_name_at(lvl)
	else:
		equipped_label.text = "Equipped: (none)"
