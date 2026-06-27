extends Node

const UPGRADE_DIR: String = "res://resources/upgrades/"
const MILESTONE_DIR: String = "res://resources/milestones/"
const SAVE_PATH: String = "user://save.json"
const SAVE_VERSION: int = 3
const DIRT_PRICE_PER_UNIT: float = 0.02
const AUTOSAVE_INTERVAL_SEC: float = 10.0
const OFFLINE_PROGRESS_CAP_SEC: float = 60.0 * 60.0 * 12.0  # 12 hours
const BASE_DAY_LENGTH_SEC: float = 30.0
const BASE_BACKPACK_CAPACITY: float = 30.0

var dirt: float = 0.0              # carried (capped at backpack_capacity)
var deposited_dirt: float = 0.0    # pile at the surface (uncapped, sells at end of day)
var money: float = 0.0
var total_dirt_dug: float = 0.0
var total_money_earned: float = 0.0

var upgrades: Array[Upgrade] = []
var upgrade_levels: Dictionary = {}  # StringName -> int

var milestones: Array[Milestone] = []
var triggered_milestones: Dictionary = {}  # StringName -> bool

var equipped_id: StringName = &"spade"

var current_day: int = 1
var time_left: float = BASE_DAY_LENGTH_SEC
var day_paused: bool = false  # true during end-of-day screen
var day_money_earned: float = 0.0
var day_dirt_dug: float = 0.0

signal world_reset_requested

var _autosave_accum: float = 0.0
var _last_saved_unix: int = 0

signal dirt_changed(new_amount: float)
signal deposited_changed(new_amount: float)
signal money_changed(new_amount: float)
signal upgrade_purchased(upgrade_id: StringName, new_level: int)
signal milestone_triggered(milestone: Milestone)
signal offline_progress(seconds: float, dirt_gained: float, money_gained: float)
signal equipped_changed(upgrade_id: StringName)
signal day_tick(time_left: float, day_length: float)
signal day_ended(day: int, dirt_dug: float, money_earned: float)
signal day_started(day: int)

func _ready() -> void:
	_load_upgrades()
	_load_milestones()
	load_game()
	time_left = day_length()
	set_process(true)
	day_started.emit(current_day)
	day_tick.emit(time_left, day_length())

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_EXIT_TREE:
		save_game()

func _process(delta: float) -> void:
	if not day_paused:
		var auto_dirt := _sum_effect(Upgrade.Effect.AUTO_DIRT_PER_SEC)
		var auto_money := _sum_effect(Upgrade.Effect.AUTO_MONEY_PER_SEC)
		if auto_dirt > 0.0:
			_add_dirt(auto_dirt * delta)
		if auto_money > 0.0:
			_add_money(auto_money * delta)
		time_left -= delta
		day_tick.emit(time_left, day_length())
		if time_left <= 0.0:
			_end_day()
	_autosave_accum += delta
	if _autosave_accum >= AUTOSAVE_INTERVAL_SEC:
		_autosave_accum = 0.0
		save_game()

func day_length() -> float:
	return BASE_DAY_LENGTH_SEC + _sum_effect(Upgrade.Effect.DAY_LENGTH_SEC)

func backpack_capacity() -> float:
	return BASE_BACKPACK_CAPACITY + _sum_effect(Upgrade.Effect.BACKPACK_CAPACITY)

func backpack_full() -> bool:
	return dirt >= backpack_capacity()

func deposit_carried() -> float:
	# Transfer everything in the backpack to the deposit pile. Returns amount moved.
	if dirt <= 0.0:
		return 0.0
	var moved := dirt
	deposited_dirt += moved
	dirt = 0.0
	dirt_changed.emit(dirt)
	deposited_changed.emit(deposited_dirt)
	return moved

func sell_deposited_pile() -> float:
	# Convert deposit pile to money. End-of-day moment.
	if deposited_dirt <= 0.0:
		return 0.0
	var money_mult := 1.0 + _sum_effect(Upgrade.Effect.CLICK_MONEY_MULT)
	var earned := deposited_dirt * DIRT_PRICE_PER_UNIT * money_mult
	deposited_dirt = 0.0
	deposited_changed.emit(deposited_dirt)
	_add_money(earned)
	return earned

# Legacy helper kept for the debug Sell button — sells whatever you carry,
# bypassing the deposit pile.
func sell_all_dirt() -> float:
	if dirt <= 0.0:
		return 0.0
	var money_mult := 1.0 + _sum_effect(Upgrade.Effect.CLICK_MONEY_MULT)
	var earned := dirt * DIRT_PRICE_PER_UNIT * money_mult
	dirt = 0.0
	dirt_changed.emit(dirt)
	_add_money(earned)
	return earned

func _end_day() -> void:
	day_paused = true
	time_left = 0.0
	# Anything still in the backpack gets dumped on the pile — no waste.
	if dirt > 0.0:
		deposit_carried()
	day_ended.emit(current_day, day_dirt_dug, day_money_earned)

func start_next_day() -> void:
	current_day += 1
	day_dirt_dug = 0.0
	day_money_earned = 0.0
	time_left = day_length()
	day_paused = false
	day_started.emit(current_day)
	day_tick.emit(time_left, day_length())

# --- Public actions -------------------------------------------------------

func dig() -> void:
	var base_dirt := 1.0 + _sum_effect(Upgrade.Effect.CLICK_DIRT)
	var crit_chance := _sum_effect(Upgrade.Effect.CRIT_CHANCE)
	var crit_mult := 1.0
	if crit_chance > 0.0 and randf() < crit_chance:
		crit_mult = 5.0
	var amount := base_dirt * crit_mult
	_add_dirt(amount)
	var money_mult := 1.0 + _sum_effect(Upgrade.Effect.CLICK_MONEY_MULT)
	_add_money(amount * DIRT_PRICE_PER_UNIT * money_mult)

func buy_upgrade(upgrade_id: StringName) -> bool:
	var up := get_upgrade(upgrade_id)
	if up == null:
		return false
	if up.is_maxed(level_of(upgrade_id)):
		return false
	var cost := cost_of(upgrade_id)
	if not can_afford(upgrade_id):
		return false
	if up.cost_currency == &"money":
		money -= cost
		money_changed.emit(money)
	else:
		dirt -= cost
		dirt_changed.emit(dirt)
	var current: int = upgrade_levels.get(upgrade_id, 0)
	upgrade_levels[upgrade_id] = current + 1
	upgrade_purchased.emit(upgrade_id, current + 1)
	_check_milestones()
	return true

func reset_game() -> void:
	dirt = 0.0
	deposited_dirt = 0.0
	money = 0.0
	total_dirt_dug = 0.0
	total_money_earned = 0.0
	upgrade_levels.clear()
	triggered_milestones.clear()
	current_day = 1
	day_dirt_dug = 0.0
	day_money_earned = 0.0
	time_left = day_length()
	day_paused = false
	equipped_id = &"spade"
	_last_saved_unix = 0
	dirt_changed.emit(dirt)
	money_changed.emit(money)
	equipped_changed.emit(equipped_id)
	deposited_changed.emit(deposited_dirt)
	world_reset_requested.emit()
	day_started.emit(current_day)
	day_tick.emit(time_left, day_length())
	save_game()

# --- Queries --------------------------------------------------------------

func level_of(upgrade_id: StringName) -> int:
	return upgrade_levels.get(upgrade_id, 0)

func cost_of(upgrade_id: StringName) -> float:
	var up := get_upgrade(upgrade_id)
	if up == null:
		return INF
	if up.is_maxed(level_of(upgrade_id)):
		return INF
	return up.cost_at(level_of(upgrade_id))

func can_afford(upgrade_id: StringName) -> bool:
	var up := get_upgrade(upgrade_id)
	if up == null:
		return false
	if up.is_maxed(level_of(upgrade_id)):
		return false
	var cost := cost_of(upgrade_id)
	if up.cost_currency == &"money":
		return money >= cost
	return dirt >= cost

func is_maxed(upgrade_id: StringName) -> bool:
	var up := get_upgrade(upgrade_id)
	if up == null:
		return false
	return up.is_maxed(level_of(upgrade_id))

func get_upgrade(upgrade_id: StringName) -> Upgrade:
	for u in upgrades:
		if u.id == upgrade_id:
			return u
	return null

func is_unlocked(upgrade_id: StringName) -> bool:
	var up := get_upgrade(upgrade_id)
	if up == null:
		return false
	return total_money_earned >= up.unlock_money

func equip(upgrade_id: StringName) -> bool:
	var up := get_upgrade(upgrade_id)
	if up == null or not up.is_equippable:
		return false
	if not is_unlocked(upgrade_id):
		return false
	equipped_id = upgrade_id
	equipped_changed.emit(equipped_id)
	return true

func equipped_upgrade() -> Upgrade:
	return get_upgrade(equipped_id)

func equipped_reach() -> int:
	var up := equipped_upgrade()
	if up == null:
		return Upgrade.Reach.CARDINAL_4
	return up.reach

# --- Persistence ----------------------------------------------------------

func save_game() -> void:
	_last_saved_unix = int(Time.get_unix_time_from_system())
	var levels_plain: Dictionary = {}
	for k in upgrade_levels.keys():
		levels_plain[String(k)] = upgrade_levels[k]
	var milestones_plain: Dictionary = {}
	for k in triggered_milestones.keys():
		milestones_plain[String(k)] = triggered_milestones[k]
	var data := {
		"version": SAVE_VERSION,
		"saved_at": _last_saved_unix,
		"dirt": dirt,
		"deposited_dirt": deposited_dirt,
		"money": money,
		"total_dirt_dug": total_dirt_dug,
		"total_money_earned": total_money_earned,
		"upgrade_levels": levels_plain,
		"triggered_milestones": milestones_plain,
		"equipped_id": String(equipped_id),
		"current_day": current_day,
		"time_left": time_left,
		"day_dirt_dug": day_dirt_dug,
		"day_money_earned": day_money_earned,
	}
	var f := FileAccess.open(SAVE_PATH, FileAccess.WRITE)
	if f == null:
		push_error("Could not open save file for writing: %s" % SAVE_PATH)
		return
	f.store_string(JSON.stringify(data))
	f.close()

func load_game() -> void:
	if not FileAccess.file_exists(SAVE_PATH):
		return
	var f := FileAccess.open(SAVE_PATH, FileAccess.READ)
	if f == null:
		push_error("Could not open save file for reading: %s" % SAVE_PATH)
		return
	var text := f.get_as_text()
	f.close()
	var parsed: Variant = JSON.parse_string(text)
	if typeof(parsed) != TYPE_DICTIONARY:
		push_warning("Save file unreadable; starting fresh.")
		return
	var data: Dictionary = parsed
	if int(data.get("version", 0)) != SAVE_VERSION:
		push_warning("Save version mismatch (%d != %d); starting fresh." % [int(data.get("version", 0)), SAVE_VERSION])
		return
	dirt = float(data.get("dirt", 0.0))
	deposited_dirt = float(data.get("deposited_dirt", 0.0))
	money = float(data.get("money", 0.0))
	total_dirt_dug = float(data.get("total_dirt_dug", 0.0))
	total_money_earned = float(data.get("total_money_earned", 0.0))
	upgrade_levels.clear()
	var levels_plain: Dictionary = data.get("upgrade_levels", {})
	for k in levels_plain.keys():
		upgrade_levels[StringName(k)] = int(levels_plain[k])
	triggered_milestones.clear()
	var ms_plain: Dictionary = data.get("triggered_milestones", {})
	for k in ms_plain.keys():
		triggered_milestones[StringName(k)] = bool(ms_plain[k])
	_last_saved_unix = int(data.get("saved_at", 0))
	var saved_equipped := String(data.get("equipped_id", "spade"))
	equipped_id = StringName(saved_equipped)
	current_day = int(data.get("current_day", 1))
	time_left = float(data.get("time_left", day_length()))
	day_dirt_dug = float(data.get("day_dirt_dug", 0.0))
	day_money_earned = float(data.get("day_money_earned", 0.0))
	dirt_changed.emit(dirt)
	deposited_changed.emit(deposited_dirt)
	money_changed.emit(money)
	equipped_changed.emit(equipped_id)
	_apply_offline_progress()

func _apply_offline_progress() -> void:
	if _last_saved_unix <= 0:
		return
	var now := int(Time.get_unix_time_from_system())
	var elapsed := float(now - _last_saved_unix)
	if elapsed <= 0.0:
		return
	elapsed = min(elapsed, OFFLINE_PROGRESS_CAP_SEC)
	var auto_dirt := _sum_effect(Upgrade.Effect.AUTO_DIRT_PER_SEC)
	var auto_money := _sum_effect(Upgrade.Effect.AUTO_MONEY_PER_SEC)
	var dirt_gained := auto_dirt * elapsed
	var money_gained := auto_money * elapsed
	if dirt_gained <= 0.0 and money_gained <= 0.0:
		return
	if dirt_gained > 0.0:
		_add_dirt(dirt_gained)
	if money_gained > 0.0:
		_add_money(money_gained)
	offline_progress.emit(elapsed, dirt_gained, money_gained)

# --- Internals ------------------------------------------------------------

func _add_dirt(amount: float) -> void:
	if amount <= 0.0:
		return
	var cap := backpack_capacity()
	var room: float = max(0.0, cap - dirt)
	var added: float = min(amount, room)
	dirt += added
	total_dirt_dug += added
	day_dirt_dug += added
	dirt_changed.emit(dirt)
	_check_milestones()

func _add_money(amount: float) -> void:
	if amount <= 0.0:
		return
	money += amount
	total_money_earned += amount
	day_money_earned += amount
	money_changed.emit(money)
	_check_milestones()

func _sum_effect(effect: Upgrade.Effect) -> float:
	var total := 0.0
	for u in upgrades:
		if u.effect == effect:
			total += u.effect_per_level * float(level_of(u.id))
	return total

func _load_upgrades() -> void:
	upgrades.clear()
	var dir := DirAccess.open(UPGRADE_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres") or file.ends_with(".res"):
			var path := UPGRADE_DIR + file
			var res := load(path)
			if res is Upgrade:
				upgrades.append(res)
		file = dir.get_next()
	dir.list_dir_end()
	upgrades.sort_custom(func(a: Upgrade, b: Upgrade) -> bool:
		return a.unlock_money < b.unlock_money
	)

func _load_milestones() -> void:
	milestones.clear()
	var dir := DirAccess.open(MILESTONE_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres") or file.ends_with(".res"):
			var path := MILESTONE_DIR + file
			var res := load(path)
			if res is Milestone:
				milestones.append(res)
		file = dir.get_next()
	dir.list_dir_end()
	milestones.sort_custom(func(a: Milestone, b: Milestone) -> bool:
		return a.threshold < b.threshold
	)

func _check_milestones() -> void:
	for m in milestones:
		if triggered_milestones.get(m.id, false):
			continue
		var fired := false
		match m.trigger:
			Milestone.Trigger.MONEY_TOTAL_EARNED:
				fired = total_money_earned >= m.threshold
			Milestone.Trigger.DIRT_TOTAL_DUG:
				fired = total_dirt_dug >= m.threshold
			Milestone.Trigger.UPGRADE_LEVEL:
				fired = level_of(m.upgrade_id) >= int(m.threshold)
		if fired:
			triggered_milestones[m.id] = true
			milestone_triggered.emit(m)
