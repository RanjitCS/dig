extends CanvasLayer

const UpgradeRowScene := preload("res://scenes/upgrade_row.tscn")

@onready var day_label: Label = %DayLabel
@onready var earnings_label: Label = %EarningsLabel
@onready var dirt_label: Label = %DirtLabel
@onready var upgrades_list: VBoxContainer = %UpgradesList
@onready var continue_button: Button = %ContinueButton
@onready var root_panel: Control = %RootPanel

var rows: Array = []

func _ready() -> void:
	visible = false
	continue_button.pressed.connect(_on_continue)
	GameState.day_ended.connect(_on_day_ended)
	GameState.day_started.connect(_on_day_started)
	GameState.upgrade_purchased.connect(_on_upgrade_purchased)
	GameState.money_changed.connect(_on_money_changed)
	_build_upgrade_rows()

func _on_day_ended(day: int, dirt_dug: float, money_earned: float) -> void:
	day_label.text = "End of Day %d" % day
	earnings_label.text = "Earned $%s" % _fmt(money_earned)
	dirt_label.text = "Dug %s dirt" % _fmt(dirt_dug)
	_refresh_rows()
	visible = true

func _on_day_started(_day: int) -> void:
	visible = false

func _on_continue() -> void:
	GameState.start_next_day()

func _on_upgrade_purchased(_id: StringName, _level: int) -> void:
	_build_upgrade_rows()

func _on_money_changed(_v: float) -> void:
	_refresh_rows()

func _build_upgrade_rows() -> void:
	for r in rows:
		r.queue_free()
	rows.clear()
	for u in GameState.upgrades:
		var row := UpgradeRowScene.instantiate()
		upgrades_list.add_child(row)
		row.setup(u)
		rows.append(row)
	_refresh_rows()

func _refresh_rows() -> void:
	for r in rows:
		r.refresh()

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
