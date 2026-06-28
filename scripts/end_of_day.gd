extends CanvasLayer

const UpgradeRowScene := preload("res://scenes/upgrade_row.tscn")

const CATEGORY_TITLES := {
	Upgrade.Category.TOOLS: "Tools",
	Upgrade.Category.FAMILY: "Family",
	Upgrade.Category.ARYA: "Arya",
	Upgrade.Category.LAND: "Land",
}

const CATEGORY_ORDER := [
	Upgrade.Category.TOOLS,
	Upgrade.Category.FAMILY,
	Upgrade.Category.ARYA,
	Upgrade.Category.LAND,
]

@onready var day_label: Label = %DayLabel
@onready var earnings_label: Label = %EarningsLabel
@onready var dirt_label: Label = %DirtLabel
@onready var lost_label: Label = %LostLabel
@onready var pile_label: Label = %PileLabel
@onready var sell_pile_button: Button = %SellPileButton
@onready var upgrades_list: VBoxContainer = %UpgradesList
@onready var continue_button: Button = %ContinueButton

var rows: Array = []
var _helper_rows: Array = []  # [{id, button, info_label}]

func _ready() -> void:
	visible = false
	continue_button.pressed.connect(_on_continue)
	sell_pile_button.pressed.connect(_on_sell_pile)
	GameState.day_ended.connect(_on_day_ended)
	GameState.day_started.connect(_on_day_started)
	GameState.upgrade_purchased.connect(_on_upgrade_purchased)
	GameState.money_changed.connect(_on_money_changed)
	GameState.deposited_changed.connect(_on_deposited_changed)
	GameState.helper_hired.connect(_on_helper_hired)
	_build_upgrade_rows()
	_build_helper_rows()
	_refresh_pile_row()

func _on_day_ended(day: int, dirt_dug: float, money_earned: float) -> void:
	day_label.text = "End of Day %d" % day
	earnings_label.text = "Earned $%s" % _fmt(money_earned)
	dirt_label.text = "Dug %s dirt" % _fmt(dirt_dug)
	_refresh_lost_label()
	_refresh_rows()
	_refresh_helper_rows()
	_refresh_pile_row()
	visible = true

func _refresh_lost_label() -> void:
	var lost_dirt: float = GameState.last_day_lost_dirt
	var lost_ore: int = GameState.last_day_lost_ore_count
	if lost_dirt <= 0.0 and lost_ore <= 0:
		lost_label.visible = false
		lost_label.text = ""
		return
	var parts: Array = []
	if lost_dirt > 0.0:
		parts.append("%s dirt" % _fmt(lost_dirt))
	if lost_ore > 0:
		parts.append("%d ore" % lost_ore)
	lost_label.text = "Stranded in the hole: lost %s." % ", ".join(parts)
	lost_label.visible = true

func _on_day_started(_day: int) -> void:
	visible = false

func _on_continue() -> void:
	GameState.start_next_day()

func _on_upgrade_purchased(_id: StringName, _level: int) -> void:
	_refresh_rows()

func _on_money_changed(_v: float) -> void:
	_refresh_rows()
	_refresh_helper_rows()

func _on_deposited_changed(_v: float) -> void:
	_refresh_pile_row()

func _on_sell_pile() -> void:
	GameState.sell_deposited_pile()
	_refresh_pile_row()

func _refresh_pile_row() -> void:
	var dirt_amt: float = GameState.deposited_dirt
	var worth: float = GameState.deposited_pile_value()
	var parts: Array = []
	if dirt_amt > 0.0:
		parts.append("%s dirt" % _fmt(dirt_amt))
	for k in GameState.deposited_ore.keys():
		var c: int = int(GameState.deposited_ore[k])
		var name: String = String(GameState.ore_display_names.get(k, str(k)))
		parts.append("%d %s" % [c, name])
	var summary: String = ", ".join(parts) if not parts.is_empty() else "(empty)"
	pile_label.text = "Pile: %s   ($%s)" % [summary, _fmt(worth)]
	sell_pile_button.disabled = worth <= 0.0

func _build_upgrade_rows() -> void:
	for c in upgrades_list.get_children():
		c.queue_free()
	rows.clear()
	for cat in CATEGORY_ORDER:
		var ups := _upgrades_in_category(cat)
		if ups.is_empty():
			continue
		var header := _make_header(CATEGORY_TITLES[cat])
		upgrades_list.add_child(header)
		for u in ups:
			var row := UpgradeRowScene.instantiate()
			upgrades_list.add_child(row)
			row.setup(u)
			rows.append(row)

func _upgrades_in_category(cat: int) -> Array:
	var out: Array = []
	for u in GameState.upgrades:
		if u.category == cat:
			out.append(u)
	return out

func _make_header(text: String) -> Label:
	var l := Label.new()
	l.text = text
	l.add_theme_font_size_override("font_size", 14)
	l.modulate = Color(0.7, 0.65, 0.6, 1)
	return l

func _refresh_rows() -> void:
	for r in rows:
		r.refresh()

# --- Helpers section ------------------------------------------------------

func _build_helper_rows() -> void:
	for hr in _helper_rows:
		if is_instance_valid(hr.row):
			hr.row.queue_free()
	_helper_rows.clear()
	if GameState.helpers.is_empty():
		return
	# Only build the section if at least one helper is unlockable ever.
	var header := _make_header("Workers (Arya's company)")
	header.name = "HelpersHeader"
	upgrades_list.add_child(header)
	_helper_rows.append({"id": &"__header", "row": header, "button": null, "info": null})
	for h in GameState.helpers:
		var row := HBoxContainer.new()
		row.add_theme_constant_override("separation", 12)
		var info := Label.new()
		info.size_flags_horizontal = Control.SIZE_EXPAND_FILL
		info.add_theme_font_size_override("font_size", 12)
		var btn := Button.new()
		btn.focus_mode = Control.FOCUS_NONE
		btn.custom_minimum_size = Vector2(150, 32)
		btn.pressed.connect(_on_hire.bind(h.id))
		row.add_child(info)
		row.add_child(btn)
		upgrades_list.add_child(row)
		_helper_rows.append({"id": h.id, "row": row, "button": btn, "info": info})
	_refresh_helper_rows()

func _refresh_helper_rows() -> void:
	for hr in _helper_rows:
		if hr.id == &"__header":
			continue
		var h := GameState.get_helper(hr.id)
		if h == null:
			continue
		var unlocked: bool = GameState.helper_unlocked(hr.id)
		hr.row.visible = unlocked
		if not unlocked:
			continue
		var lvl: int = GameState.helper_level(hr.id)
		# Per-day production preview (full day length, full rate while present).
		var day_len: float = GameState.day_length()
		var prod_parts: Array = []
		if h.dirt_per_sec > 0.0:
			prod_parts.append("%s dirt/day" % _fmt(h.dirt_per_sec * float(lvl) * day_len))
		if h.ore_id != &"" and h.ore_per_sec > 0.0:
			var ore_name: String = String(GameState.ore_display_names.get(h.ore_id, str(h.ore_id)))
			prod_parts.append("%s %s/day" % [_fmt(h.ore_per_sec * float(lvl) * day_len), ore_name])
		var prod: String = ", ".join(prod_parts) if lvl > 0 else "not yet helping"
		hr.info.text = "%s (x%d) — %s" % [h.display_name, lvl, prod]
		if h.is_maxed(lvl):
			hr.button.text = "Maxed"
			hr.button.disabled = true
		else:
			var verb: String = "Hire" if lvl == 0 else "Add"
			hr.button.text = "%s  •  $%s" % [verb, _fmt(GameState.helper_cost(hr.id))]
			hr.button.disabled = not GameState.can_afford_helper(hr.id)

func _on_hire(helper_id: StringName) -> void:
	GameState.hire_helper(helper_id)

func _on_helper_hired(_id: StringName, _lvl: int) -> void:
	_refresh_helper_rows()

func _fmt(value: float) -> String:
	if value < 1000.0:
		if value == floor(value):
			return "%.0f" % value
		return "%.2f" % value
	var units := ["", "K", "M", "B", "T", "Qa", "Qi"]
	var tier := 0
	var v := value
	while v >= 1000.0 and tier < units.size() - 1:
		v /= 1000.0
		tier += 1
	return "%.2f%s" % [v, units[tier]]
