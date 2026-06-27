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
@onready var pile_label: Label = %PileLabel
@onready var sell_pile_button: Button = %SellPileButton
@onready var upgrades_list: VBoxContainer = %UpgradesList
@onready var continue_button: Button = %ContinueButton

var rows: Array = []

func _ready() -> void:
	visible = false
	continue_button.pressed.connect(_on_continue)
	sell_pile_button.pressed.connect(_on_sell_pile)
	GameState.day_ended.connect(_on_day_ended)
	GameState.day_started.connect(_on_day_started)
	GameState.upgrade_purchased.connect(_on_upgrade_purchased)
	GameState.money_changed.connect(_on_money_changed)
	GameState.deposited_changed.connect(_on_deposited_changed)
	_build_upgrade_rows()
	_refresh_pile_row()

func _on_day_ended(day: int, dirt_dug: float, money_earned: float) -> void:
	day_label.text = "End of Day %d" % day
	earnings_label.text = "Earned $%s" % _fmt(money_earned)
	dirt_label.text = "Dug %s dirt" % _fmt(dirt_dug)
	_refresh_rows()
	_refresh_pile_row()
	visible = true

func _on_day_started(_day: int) -> void:
	visible = false

func _on_continue() -> void:
	GameState.start_next_day()

func _on_upgrade_purchased(_id: StringName, _level: int) -> void:
	_refresh_rows()

func _on_money_changed(_v: float) -> void:
	_refresh_rows()

func _on_deposited_changed(_v: float) -> void:
	_refresh_pile_row()

func _on_sell_pile() -> void:
	GameState.sell_deposited_pile()
	_refresh_pile_row()

func _refresh_pile_row() -> void:
	var amount: float = GameState.deposited_dirt
	var money_mult: float = 1.0 + GameState._sum_effect(Upgrade.Effect.CLICK_MONEY_MULT)
	var worth: float = amount * GameState.DIRT_PRICE_PER_UNIT * money_mult
	pile_label.text = "Pile: %s dirt   ($%s)" % [_fmt(amount), _fmt(worth)]
	sell_pile_button.disabled = amount <= 0.0

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
