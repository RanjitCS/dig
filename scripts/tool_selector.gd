extends HBoxContainer

var buttons: Dictionary = {}  # StringName -> Button

func _ready() -> void:
	GameState.upgrade_purchased.connect(_on_upgrade_purchased)
	GameState.equipped_changed.connect(_on_equipped_changed)
	_build()

func _build() -> void:
	for child in get_children():
		child.queue_free()
	buttons.clear()
	for up in GameState.upgrades:
		if not up.is_equippable:
			continue
		if not _can_show(up):
			continue
		var btn := Button.new()
		btn.text = up.tier_name_at(GameState.level_of(up.id))
		btn.toggle_mode = true
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(120, 36)
		btn.pressed.connect(_on_button_pressed.bind(up.id))
		add_child(btn)
		buttons[up.id] = btn
	_refresh_pressed()

func _can_show(up: Upgrade) -> bool:
	# Always show spade (starter tool). Others show once unlocked and owned (Lv >= 1).
	if up.id == &"spade":
		return true
	if GameState.is_unlocked(up.id) and GameState.level_of(up.id) >= 1:
		return true
	return false

func _on_button_pressed(id: StringName) -> void:
	GameState.equip(id)

func _on_upgrade_purchased(_id: StringName, _level: int) -> void:
	_build()

func _on_equipped_changed(_id: StringName) -> void:
	_refresh_pressed()

func _refresh_pressed() -> void:
	for id in buttons.keys():
		var btn: Button = buttons[id]
		btn.button_pressed = (id == GameState.equipped_id)
