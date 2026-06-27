extends Control

@onready var dirt_label: Label = %DirtLabel
@onready var pile_label: Label = %PileLabel
@onready var money_label: Label = %MoneyLabel
@onready var depth_label: Label = %DepthLabel
@onready var day_label: Label = %DayLabel
@onready var time_left_label: Label = %TimeLeftLabel
@onready var time_bar: ProgressBar = %TimeBar
@onready var toast_label: Label = %ToastLabel
@onready var toast_timer: Timer = %ToastTimer
@onready var reset_button: Button = %ResetButton
@onready var sell_button: Button = %SellButton
@onready var dig_world: Node2D = %DigWorld

var deepest_dug: int = 0
var _last_pile: float = 0.0

func _ready() -> void:
	reset_button.pressed.connect(_on_reset_pressed)
	sell_button.pressed.connect(_on_sell_pressed)
	GameState.dirt_changed.connect(_on_dirt_changed)
	GameState.money_changed.connect(_on_money_changed)
	GameState.upgrade_purchased.connect(_on_upgrade_purchased)
	GameState.milestone_triggered.connect(_on_milestone_triggered)
	GameState.offline_progress.connect(_on_offline_progress)
	GameState.day_tick.connect(_on_day_tick)
	GameState.day_started.connect(_on_day_started)
	GameState.day_ended.connect(_on_day_ended_for_sell)
	GameState.deposited_changed.connect(_on_deposited_changed)
	GameState.carried_changed.connect(_on_carried_changed)
	dig_world.deepest_changed.connect(_on_deepest_changed)
	toast_timer.timeout.connect(_hide_toast)
	toast_label.visible = false
	_last_pile = GameState.deposited_dirt
	_refresh_all()
	_refresh_sell_button()

func _on_dirt_changed(_v: float) -> void:
	_refresh_dirt()
	_refresh_sell_button()

func _on_carried_changed() -> void:
	_refresh_dirt()
	_refresh_sell_button()

func _on_deposited_changed(v: float) -> void:
	var diff: float = v - _last_pile
	_last_pile = v
	_refresh_pile()
	if diff > 0.0 and not GameState.day_paused:
		# Only toast on mid-day deposits, not on end-of-day auto-dump or sell.
		_show_toast("Deposited %s dirt." % _fmt(diff))

func _on_money_changed(_v: float) -> void:
	_refresh_money()

func _on_upgrade_purchased(_id: StringName, _lvl: int) -> void:
	_refresh_dirt()  # capacity may have changed
	_refresh_day_bar_max()

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

func _on_sell_pressed() -> void:
	if not GameState.day_paused:
		return
	var earned := GameState.sell_all_dirt()
	if earned > 0.0:
		_show_toast("Sold dirt. +$%s" % _fmt(earned))
	_refresh_sell_button()

func _on_day_ended_for_sell(_day: int, _dirt_dug: float, _money: float) -> void:
	_refresh_sell_button()

func _refresh_sell_button() -> void:
	var can_sell := GameState.day_paused and GameState.dirt > 0.0
	sell_button.disabled = not can_sell
	sell_button.modulate = Color(1, 1, 1, 1) if can_sell else Color(1, 1, 1, 0.35)

func _on_deepest_changed(row: int) -> void:
	if row > deepest_dug:
		deepest_dug = row
		_refresh_depth()

func _on_day_tick(left: float, length: float) -> void:
	if time_bar.max_value != length:
		time_bar.max_value = length
	time_bar.value = max(0.0, left)
	time_left_label.text = "%ds" % int(ceil(max(0.0, left)))

func _on_day_started(day: int) -> void:
	day_label.text = "Day %d" % day
	_refresh_day_bar_max()
	_refresh_sell_button()

func _refresh_all() -> void:
	_refresh_dirt()
	_refresh_pile()
	_refresh_money()
	_refresh_depth()
	_refresh_day_bar_max()
	day_label.text = "Day %d" % GameState.current_day

func _refresh_dirt() -> void:
	var carried: float = GameState.carried_total()
	var cap: float = GameState.backpack_capacity()
	var ore_n: int = GameState.carried_ore_count()
	if ore_n > 0:
		dirt_label.text = "Pack: %s / %s  (%s dirt + %d ore)" % [_fmt(carried), _fmt(cap), _fmt(GameState.dirt), ore_n]
	else:
		dirt_label.text = "Pack: %s / %s" % [_fmt(carried), _fmt(cap)]

func _refresh_pile() -> void:
	var dirt_amt: float = GameState.deposited_dirt
	var ore_n: int = 0
	for k in GameState.deposited_ore.keys():
		ore_n += int(GameState.deposited_ore[k])
	if ore_n > 0:
		pile_label.text = "Pile: %s dirt + %d ore" % [_fmt(dirt_amt), ore_n]
	else:
		pile_label.text = "Pile: %s" % _fmt(dirt_amt)

func _refresh_money() -> void:
	money_label.text = "$%s" % _fmt(GameState.money)

func _refresh_depth() -> void:
	depth_label.text = "Depth: %d" % deepest_dug

func _refresh_day_bar_max() -> void:
	var length := GameState.day_length()
	time_bar.max_value = length
	time_bar.value = max(0.0, GameState.time_left)
	time_left_label.text = "%ds" % int(ceil(max(0.0, GameState.time_left)))

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
