extends PanelContainer

@onready var name_label: Label = %NameLabel
@onready var flavor_label: Label = %FlavorLabel
@onready var level_label: Label = %LevelLabel
@onready var buy_button: Button = %BuyButton

var upgrade: Upgrade

func setup(u: Upgrade) -> void:
	upgrade = u
	if is_node_ready():
		_apply()

func _ready() -> void:
	buy_button.pressed.connect(_on_buy)
	if upgrade != null:
		_apply()

func _apply() -> void:
	name_label.text = upgrade.display_name
	flavor_label.text = upgrade.flavor
	refresh()

func refresh() -> void:
	if upgrade == null:
		return
	var lvl := GameState.level_of(upgrade.id)
	var cost := GameState.cost_of(upgrade.id)
	var currency := "$" if upgrade.cost_currency == &"money" else "dirt"
	level_label.text = "Lv %d" % lvl
	buy_button.text = "Buy  •  %s%s" % [currency, _fmt(cost)]
	buy_button.disabled = not GameState.can_afford(upgrade.id)
	visible = GameState.is_unlocked(upgrade.id)

func _on_buy() -> void:
	if upgrade != null:
		GameState.buy_upgrade(upgrade.id)

func _fmt(value: float) -> String:
	if value < 1000.0:
		return "%.0f" % value
	var units := ["", "K", "M", "B", "T", "Qa", "Qi"]
	var tier := 0
	var v := value
	while v >= 1000.0 and tier < units.size() - 1:
		v /= 1000.0
		tier += 1
	return "%.2f%s" % [v, units[tier]]
