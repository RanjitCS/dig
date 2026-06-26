extends Control

const UpgradeRowScene := preload("res://scenes/upgrade_row.tscn")

@onready var dirt_label: Label = %DirtLabel
@onready var money_label: Label = %MoneyLabel
@onready var depth_label: Label = %DepthLabel
@onready var upgrades_list: VBoxContainer = %UpgradesList
@onready var toast_label: Label = %ToastLabel
@onready var toast_timer: Timer = %ToastTimer
@onready var reset_button: Button = %ResetButton
@onready var dig_world: Control = %DigWorld

var rows: Array = []
var deepest_dug: int = 0

func _ready() -> void:
	reset_button.pressed.connect(_on_reset_pressed)
	GameState.dirt_changed.connect(_on_dirt_changed)
	GameState.money_changed.connect(_on_money_changed)
	GameState.upgrade_purchased.connect(_on_upgrade_purchased)
	GameState.milestone_triggered.connect(_on_milestone_triggered)
	GameState.offline_progress.connect(_on_offline_progress)
	dig_world.deepest_changed.connect(_on_deepest_changed)
	toast_timer.timeout.connect(_hide_toast)
	toast_label.visible = false
	_build_upgrade_rows()
	_refresh_all()

func _on_dirt_changed(_v: float) -> void:
	_refresh_dirt()
	_refresh_rows()

func _on_money_changed(_v: float) -> void:
	_refresh_money()
	_refresh_rows()

func _on_upgrade_purchased(_id: StringName, _lvl: int) -> void:
	_refresh_rows()

func _on_milestone_triggered(m: Milestone) -> void:
	_show_toast("%s\n%s" % [m.title, m.body])

func _on_offline_progress(seconds: float, dirt_gained: float, money_gained: float) -> void:
	if dirt_gained <= 0.0 and money_gained <= 0.0:
		return
	var human := _fmt_duration(seconds)
	_show_toast("Welcome back.\nGone %s. Earned $%s." % [human, _fmt(money_gained)])

func _on_reset_pressed() -> void:
	GameState.reset_game()
	_show_toast("Reset. Start over.")

func _on_deepest_changed(row: int) -> void:
	if row > deepest_dug:
		deepest_dug = row
		_refresh_depth()

func _build_upgrade_rows() -> void:
	for u in GameState.upgrades:
		var row := UpgradeRowScene.instantiate()
		upgrades_list.add_child(row)
		row.setup(u)
		rows.append(row)

func _refresh_all() -> void:
	_refresh_dirt()
	_refresh_money()
	_refresh_depth()
	_refresh_rows()

func _refresh_dirt() -> void:
	dirt_label.text = "Dirt: %s" % _fmt(GameState.dirt)

func _refresh_money() -> void:
	money_label.text = "$%s" % _fmt(GameState.money)

func _refresh_depth() -> void:
	depth_label.text = "Depth: %d" % deepest_dug

func _refresh_rows() -> void:
	for r in rows:
		r.refresh()

func _show_toast(text: String) -> void:
	toast_label.text = text
	toast_label.visible = true
	toast_timer.stop()
	toast_timer.start()

func _hide_toast() -> void:
	toast_label.visible = false

func _fmt_duration(seconds: float) -> String:
	var s := int(seconds)
	if s < 60:
		return "%ds" % s
	if s < 3600:
		return "%dm" % (s / 60)
	if s < 86400:
		return "%dh %dm" % [s / 3600, (s % 3600) / 60]
	return "%dd %dh" % [s / 86400, (s % 86400) / 3600]

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
