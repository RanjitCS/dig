extends Node

const UPGRADE_DIR: String = "res://resources/upgrades/"
const MILESTONE_DIR: String = "res://resources/milestones/"
const BLOCK_DIR: String = "res://resources/blocks/"
const SAVE_PATH: String = "user://save.json"
const SAVE_VERSION: int = 5

enum Phase { HOUSE_INTERIOR, DIGGING, END_OF_DAY }
const DIRT_PRICE_PER_UNIT: float = 0.10
const AUTOSAVE_INTERVAL_SEC: float = 10.0
const OFFLINE_PROGRESS_CAP_SEC: float = 60.0 * 60.0 * 12.0  # 12 hours
const BASE_DAY_LENGTH_SEC: float = 30.0
const BASE_BACKPACK_CAPACITY: float = 30.0

var dirt: float = 0.0              # carried (capped at backpack_capacity with ore)
var deposited_dirt: float = 0.0    # pile at the surface (uncapped)
var carried_ore: Dictionary = {}   # StringName ore_id -> int count (carried)
var deposited_ore: Dictionary = {} # StringName ore_id -> int count (pile)
var ore_prices: Dictionary = {}    # StringName ore_id -> float price per unit
var ore_display_names: Dictionary = {} # StringName -> String
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
var phase: Phase = Phase.HOUSE_INTERIOR
var day_money_earned: float = 0.0
var day_dirt_dug: float = 0.0

signal world_reset_requested
signal phase_changed(new_phase: Phase)

var _autosave_accum: float = 0.0
var _last_saved_unix: int = 0

signal dirt_changed(new_amount: float)
signal carried_changed  # fires when dirt or carried_ore changes
signal carried_lost(lost_dirt: float, lost_ore_count: int)  # day ended with stuff in pack
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
	_load_ore_prices()
	load_game()
	time_left = day_length()
	set_process(true)
	phase_changed.emit(phase)
	day_started.emit(current_day)
	day_tick.emit(time_left, day_length())

func _load_ore_prices() -> void:
	ore_prices.clear()
	ore_display_names.clear()
	var dir := DirAccess.open(BLOCK_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres") or file.ends_with(".res"):
			var res := load(BLOCK_DIR + file)
			if res is BlockType and res.money_yield > 0.0 and not res.indestructible:
				ore_prices[res.id] = res.money_yield
				ore_display_names[res.id] = res.display_name
		file = dir.get_next()
	dir.list_dir_end()

func _notification(what: int) -> void:
	if what == NOTIFICATION_WM_CLOSE_REQUEST or what == NOTIFICATION_WM_GO_BACK_REQUEST or what == NOTIFICATION_EXIT_TREE:
		save_game()

func _process(delta: float) -> void:
	# Day timer only ticks while actively digging.
	if phase == Phase.DIGGING and not day_paused:
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

func set_phase(new_phase: Phase) -> void:
	if phase == new_phase:
		return
	phase = new_phase
	phase_changed.emit(phase)

func start_digging() -> void:
	# Called when the player leaves the house. If we were paused (end-of-day),
	# unpause + advance day. Otherwise just transition into DIGGING.
	if day_paused:
		# coming from end-of-day modal flow if it was active; usually start_next_day handles that
		pass
	set_phase(Phase.DIGGING)

func day_length() -> float:
	return BASE_DAY_LENGTH_SEC + _sum_effect(Upgrade.Effect.DAY_LENGTH_SEC)

func backpack_capacity() -> float:
	return BASE_BACKPACK_CAPACITY + _sum_effect(Upgrade.Effect.BACKPACK_CAPACITY)

func carried_total() -> float:
	var total: float = dirt
	for k in carried_ore.keys():
		total += float(carried_ore[k])
	return total

func carried_ore_count() -> int:
	var n: int = 0
	for k in carried_ore.keys():
		n += int(carried_ore[k])
	return n

func backpack_full() -> bool:
	return carried_total() >= backpack_capacity()

func add_ore(ore_id: StringName, count: int) -> int:
	if count <= 0:
		return 0
	var room: float = backpack_capacity() - carried_total()
	if room <= 0.0:
		return 0
	var fit: int = min(count, int(floor(room)))
	if fit <= 0:
		return 0
	carried_ore[ore_id] = int(carried_ore.get(ore_id, 0)) + fit
	carried_changed.emit()
	return fit

func deposit_carried() -> float:
	var moved: float = 0.0
	if dirt > 0.0:
		deposited_dirt += dirt
		moved += dirt
		dirt = 0.0
	for k in carried_ore.keys():
		var c: int = int(carried_ore[k])
		if c > 0:
			deposited_ore[k] = int(deposited_ore.get(k, 0)) + c
			moved += float(c)
	carried_ore.clear()
	if moved <= 0.0:
		return 0.0
	dirt_changed.emit(dirt)
	carried_changed.emit()
	deposited_changed.emit(deposited_dirt)
	return moved

func sell_deposited_pile() -> float:
	# Convert deposit pile (dirt + ore) to money. End-of-day moment.
	if deposited_dirt <= 0.0 and deposited_ore.is_empty():
		return 0.0
	var money_mult := 1.0 + _sum_effect(Upgrade.Effect.CLICK_MONEY_MULT)
	var earned: float = deposited_dirt * DIRT_PRICE_PER_UNIT * money_mult
	for k in deposited_ore.keys():
		var count: int = int(deposited_ore[k])
		var price: float = float(ore_prices.get(k, 0.0))
		earned += float(count) * price * money_mult
	deposited_dirt = 0.0
	deposited_ore.clear()
	deposited_changed.emit(deposited_dirt)
	_add_money(earned)
	return earned

func deposited_pile_value() -> float:
	# Preview the total $ the pile would sell for right now (with mult applied).
	var money_mult := 1.0 + _sum_effect(Upgrade.Effect.CLICK_MONEY_MULT)
	var total: float = deposited_dirt * DIRT_PRICE_PER_UNIT * money_mult
	for k in deposited_ore.keys():
		total += float(deposited_ore[k]) * float(ore_prices.get(k, 0.0)) * money_mult
	return total

func deposited_total_units() -> float:
	var total: float = deposited_dirt
	for k in deposited_ore.keys():
		total += float(deposited_ore[k])
	return total

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
	# Carried inventory is LOST if you didn't make it back to deposit in time.
	# Real punishment for getting stuck underground when the timer runs out.
	var lost_dirt: float = dirt
	var lost_ore_count: int = carried_ore_count()
	if lost_dirt > 0.0 or lost_ore_count > 0:
		dirt = 0.0
		carried_ore.clear()
		dirt_changed.emit(dirt)
		carried_changed.emit()
		if lost_dirt > 0.0 or lost_ore_count > 0:
			carried_lost.emit(lost_dirt, lost_ore_count)
	set_phase(Phase.END_OF_DAY)
	day_ended.emit(current_day, day_dirt_dug, day_money_earned)

func start_next_day() -> void:
	current_day += 1
	day_dirt_dug = 0.0
	day_money_earned = 0.0
	time_left = day_length()
	day_paused = false
	# Day begins in the bedroom; player must walk out the door to begin digging.
	set_phase(Phase.HOUSE_INTERIOR)
	day_started.emit(current_day)
	day_tick.emit(time_left, day_length())

func skip_to_end_of_day() -> void:
	# Called when player presses E on the bed before going out.
	_end_day()

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
	carried_ore.clear()
	deposited_ore.clear()
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
	phase = Phase.HOUSE_INTERIOR
	_last_saved_unix = 0
	dirt_changed.emit(dirt)
	money_changed.emit(money)
	equipped_changed.emit(equipped_id)
	carried_changed.emit()
	deposited_changed.emit(deposited_dirt)
	phase_changed.emit(phase)
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
		"carried_ore": _ore_dict_to_plain(carried_ore),
		"deposited_ore": _ore_dict_to_plain(deposited_ore),
		"money": money,
		"total_dirt_dug": total_dirt_dug,
		"total_money_earned": total_money_earned,
		"upgrade_levels": levels_plain,
		"triggered_milestones": milestones_plain,
		"equipped_id": String(equipped_id),
		"phase": int(phase),
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
	carried_ore = _ore_plain_to_dict(data.get("carried_ore", {}))
	deposited_ore = _ore_plain_to_dict(data.get("deposited_ore", {}))
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
	phase = data.get("phase", Phase.HOUSE_INTERIOR) as Phase
	current_day = int(data.get("current_day", 1))
	time_left = float(data.get("time_left", day_length()))
	day_dirt_dug = float(data.get("day_dirt_dug", 0.0))
	day_money_earned = float(data.get("day_money_earned", 0.0))
	dirt_changed.emit(dirt)
	carried_changed.emit()
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
	var room: float = max(0.0, cap - carried_total())
	var added: float = min(amount, room)
	if added <= 0.0:
		return
	dirt += added
	total_dirt_dug += added
	day_dirt_dug += added
	dirt_changed.emit(dirt)
	carried_changed.emit()
	_check_milestones()

func _add_money(amount: float) -> void:
	if amount <= 0.0:
		return
	money += amount
	total_money_earned += amount
	day_money_earned += amount
	money_changed.emit(money)
	_check_milestones()

func _ore_dict_to_plain(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d.keys():
		out[String(k)] = int(d[k])
	return out

func _ore_plain_to_dict(d: Dictionary) -> Dictionary:
	var out: Dictionary = {}
	for k in d.keys():
		out[StringName(k)] = int(d[k])
	return out

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
