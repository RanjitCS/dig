extends Node

const UPGRADE_DIR: String = "res://resources/upgrades/"
const MILESTONE_DIR: String = "res://resources/milestones/"
const BLOCK_DIR: String = "res://resources/blocks/"
const CUTSCENE_DIR: String = "res://resources/cutscenes/"
const HELPER_DIR: String = "res://resources/helpers/"
const DAY_EVENT_DIR: String = "res://resources/day_events/"
const SAVE_PATH: String = "user://save.json"
const SAVE_VERSION: int = 9

# Odds that any given new day (after day 1) is a "special day". Rare on purpose.
const SPECIAL_DAY_CHANCE: float = 1.0 / 13.0
const DEFAULT_ROOM: StringName = &"bedroom"

enum Phase { HOUSE_INTERIOR, DIGGING, END_OF_DAY }
const DIRT_PRICE_PER_UNIT: float = 0.10
const AUTOSAVE_INTERVAL_SEC: float = 10.0
const OFFLINE_PROGRESS_CAP_SEC: float = 60.0 * 60.0 * 12.0  # 12 hours
const BASE_DAY_LENGTH_SEC: float = 30.0
const BASE_BACKPACK_CAPACITY: float = 20.0

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

var cutscenes: Array[Cutscene] = []
var triggered_cutscenes: Dictionary = {}  # StringName -> bool

var helpers: Array[Helper] = []
var helper_levels: Dictionary = {}  # StringName helper_id -> int (count hired)
var _helper_ore_accum: Dictionary = {}  # StringName ore_id -> float (fractional carryover)

# "Special day" events. Rolled rarely at day-start; applied for the whole day.
var day_events: Array[DayEvent] = []
var today_event: DayEvent = null  # the active special day, or null for an ordinary day

# Region progression. Helpers (Arya's labor company) unlock only once the
# village has grown into a city. Until the full region system exists this is a
# simple flag, toggled by reaching City (or by the debug panel).
var city_unlocked: bool = false

var equipped_id: StringName = &"spade"

var current_day: int = 1
var time_left: float = BASE_DAY_LENGTH_SEC
var day_paused: bool = false  # true during end-of-day screen
var phase: Phase = Phase.HOUSE_INTERIOR
var current_room: StringName = DEFAULT_ROOM

# Last-day loss summary, read by the end-of-day modal.
var last_day_lost_dirt: float = 0.0
var last_day_lost_ore_count: int = 0
var day_money_earned: float = 0.0
var day_dirt_dug: float = 0.0

signal world_reset_requested
signal phase_changed(new_phase: Phase)
signal cutscene_triggered(scene: Cutscene)
signal room_changed(new_room: StringName, spawn_x: float)

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
signal helper_hired(helper_id: StringName, new_level: int)
# Fired when a new day rolls a special event. The announce modal listens.
signal day_event_started(event: DayEvent)

func _ready() -> void:
	_load_upgrades()
	_load_milestones()
	_load_cutscenes()
	_load_helpers()
	_load_day_events()
	_load_ore_prices()
	load_game()
	time_left = day_length()
	set_process(true)
	phase_changed.emit(phase)
	day_started.emit(current_day)
	day_tick.emit(time_left, day_length())
	# Note: do NOT call _check_cutscenes() here. The modal isn't connected yet
	# during autoload _ready. The modal calls check_pending_cutscenes() itself
	# after it's set up its listener.

func check_pending_cutscenes() -> void:
	_check_cutscenes()

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
		_run_helpers(delta)
		time_left -= delta
		day_tick.emit(time_left, day_length())
		if time_left <= 0.0:
			_end_day()
	_autosave_accum += delta
	if _autosave_accum >= AUTOSAVE_INTERVAL_SEC:
		_autosave_accum = 0.0
		save_game()

# Helpers dig straight into the deposit PILE (not the backpack) — they haul
# their own. Runs during active DIGGING; offline accrual handled separately.
func _run_helpers(delta: float) -> void:
	var d := helper_dirt_per_sec() * delta
	if d > 0.0:
		_deposit_dirt_directly(d)
	var ore := helper_ore_per_sec_all()  # Dict ore_id -> per-sec
	for ore_id in ore.keys():
		var amount: float = float(ore[ore_id]) * delta
		_helper_ore_accum[ore_id] = float(_helper_ore_accum.get(ore_id, 0.0)) + amount
		# Whole units drop into the pile; fractional carries over.
		var whole: int = int(floor(_helper_ore_accum[ore_id]))
		if whole > 0:
			_helper_ore_accum[ore_id] -= float(whole)
			deposited_ore[ore_id] = int(deposited_ore.get(ore_id, 0)) + whole
			deposited_changed.emit(deposited_dirt)

func set_phase(new_phase: Phase) -> void:
	if phase == new_phase:
		return
	phase = new_phase
	phase_changed.emit(phase)

func set_room(room_id: StringName, spawn_x: float = NAN) -> void:
	# Switches the active house room. spawn_x = NAN means "use the room's default spawn".
	# Special case: "backyard" is not a house room — it triggers a phase transition
	# into DIGGING (handled by DigWorld via phase_changed).
	if room_id == &"backyard":
		set_phase(Phase.DIGGING)
		return
	current_room = room_id
	room_changed.emit(current_room, spawn_x)

func start_digging() -> void:
	# Called when the player leaves the house. If we were paused (end-of-day),
	# unpause + advance day. Otherwise just transition into DIGGING.
	if day_paused:
		# coming from end-of-day modal flow if it was active; usually start_next_day handles that
		pass
	set_phase(Phase.DIGGING)

func day_length() -> float:
	var base := BASE_DAY_LENGTH_SEC + _sum_effect(Upgrade.Effect.DAY_LENGTH_SEC)
	return base * today_event_day_length_mult()

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
	var money_mult := (1.0 + _sum_effect(Upgrade.Effect.CLICK_MONEY_MULT)) * today_event_money_mult()
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
	var money_mult := (1.0 + _sum_effect(Upgrade.Effect.CLICK_MONEY_MULT)) * today_event_money_mult()
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
	# Stash the amounts for the end-of-day modal to display.
	last_day_lost_dirt = dirt
	last_day_lost_ore_count = carried_ore_count()
	if last_day_lost_dirt > 0.0 or last_day_lost_ore_count > 0:
		dirt = 0.0
		carried_ore.clear()
		dirt_changed.emit(dirt)
		carried_changed.emit()
		carried_lost.emit(last_day_lost_dirt, last_day_lost_ore_count)
	set_phase(Phase.END_OF_DAY)
	day_ended.emit(current_day, day_dirt_dug, day_money_earned)

func start_next_day() -> void:
	current_day += 1
	day_dirt_dug = 0.0
	day_money_earned = 0.0
	last_day_lost_dirt = 0.0
	last_day_lost_ore_count = 0
	# Roll the special-day event BEFORE computing day length (storm/still-air
	# scale it) so time_left reflects today's modifier.
	_roll_day_event()
	# A cozy morning gift (Mom's lunch money, etc.) lands right at day start.
	if today_event != null and today_event.morning_gift_money > 0.0:
		_add_money(today_event.morning_gift_money)
	time_left = day_length()
	day_paused = false
	# Day begins in the bedroom; player must walk out the door to begin digging.
	set_phase(Phase.HOUSE_INTERIOR)
	set_room(DEFAULT_ROOM, NAN)
	day_started.emit(current_day)
	day_tick.emit(time_left, day_length())
	# A scripted cutscene takes priority over the special-day announce on the rare
	# day both would fire (the modal shows one at a time).
	var fired_cutscene := _check_cutscenes()
	if not fired_cutscene and today_event != null:
		day_event_started.emit(today_event)

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
	triggered_cutscenes.clear()
	helper_levels.clear()
	_helper_ore_accum.clear()
	today_event = null
	city_unlocked = false
	current_day = 1
	day_dirt_dug = 0.0
	day_money_earned = 0.0
	time_left = day_length()
	day_paused = false
	equipped_id = &"spade"
	phase = Phase.HOUSE_INTERIOR
	current_room = DEFAULT_ROOM
	_last_saved_unix = 0
	dirt_changed.emit(dirt)
	money_changed.emit(money)
	equipped_changed.emit(equipped_id)
	carried_changed.emit()
	deposited_changed.emit(deposited_dirt)
	phase_changed.emit(phase)
	room_changed.emit(current_room, NAN)
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
	var cutscenes_plain: Dictionary = {}
	for k in triggered_cutscenes.keys():
		cutscenes_plain[String(k)] = triggered_cutscenes[k]
	var helpers_plain: Dictionary = {}
	for k in helper_levels.keys():
		helpers_plain[String(k)] = helper_levels[k]
	var data := {
		"city_unlocked": city_unlocked,
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
		"triggered_cutscenes": cutscenes_plain,
		"helper_levels": helpers_plain,
		"equipped_id": String(equipped_id),
		"phase": int(phase),
		"current_room": String(current_room),
		"current_day": current_day,
		"time_left": time_left,
		"day_dirt_dug": day_dirt_dug,
		"day_money_earned": day_money_earned,
		"today_event_id": String(today_event.id) if today_event != null else "",
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
	triggered_cutscenes.clear()
	var cs_plain: Dictionary = data.get("triggered_cutscenes", {})
	for k in cs_plain.keys():
		triggered_cutscenes[StringName(k)] = bool(cs_plain[k])
	helper_levels.clear()
	var hl_plain: Dictionary = data.get("helper_levels", {})
	for k in hl_plain.keys():
		helper_levels[StringName(k)] = int(hl_plain[k])
	city_unlocked = bool(data.get("city_unlocked", false))
	_last_saved_unix = int(data.get("saved_at", 0))
	var saved_equipped := String(data.get("equipped_id", "spade"))
	equipped_id = StringName(saved_equipped)
	phase = data.get("phase", Phase.HOUSE_INTERIOR) as Phase
	current_room = StringName(String(data.get("current_room", String(DEFAULT_ROOM))))
	current_day = int(data.get("current_day", 1))
	var saved_event_id := String(data.get("today_event_id", ""))
	today_event = get_day_event(StringName(saved_event_id)) if saved_event_id != "" else null
	time_left = float(data.get("time_left", day_length()))
	day_dirt_dug = float(data.get("day_dirt_dug", 0.0))
	day_money_earned = float(data.get("day_money_earned", 0.0))
	dirt_changed.emit(dirt)
	carried_changed.emit()
	deposited_changed.emit(deposited_dirt)
	money_changed.emit(money)
	equipped_changed.emit(equipped_id)
	_apply_offline_progress()
	# (Helper offline accrual removed 2026-06-28 — helpers only produce during the active dig day.)

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
	# Achievement-style permanent buffs from triggered milestones.
	for m in milestones:
		if m.reward_amount == 0.0:
			continue
		if m.reward_effect != effect:
			continue
		if not triggered_milestones.get(m.id, false):
			continue
		total += m.reward_amount
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

func _load_cutscenes() -> void:
	cutscenes.clear()
	var dir := DirAccess.open(CUTSCENE_DIR)
	if dir == null:
		print("[cutscene] could not open dir: ", CUTSCENE_DIR)
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres") or file.ends_with(".res"):
			var path := CUTSCENE_DIR + file
			var res := load(path)
			if res is Cutscene:
				cutscenes.append(res)
				print("[cutscene] loaded: ", res.id, " (", path, ")")
			else:
				print("[cutscene] not a Cutscene: ", path, " got=", res)
		file = dir.get_next()
	dir.list_dir_end()
	print("[cutscene] total loaded: ", cutscenes.size())

# --- Helpers (automation) -------------------------------------------------

func _load_helpers() -> void:
	helpers.clear()
	var dir := DirAccess.open(HELPER_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres") or file.ends_with(".res"):
			var res := load(HELPER_DIR + file)
			if res is Helper:
				helpers.append(res)
		file = dir.get_next()
	dir.list_dir_end()
	helpers.sort_custom(func(a: Helper, b: Helper) -> bool:
		return a.unlock_money < b.unlock_money
	)

func _load_day_events() -> void:
	day_events.clear()
	var dir := DirAccess.open(DAY_EVENT_DIR)
	if dir == null:
		return
	dir.list_dir_begin()
	var file := dir.get_next()
	while file != "":
		if file.ends_with(".tres") or file.ends_with(".res"):
			var res := load(DAY_EVENT_DIR + file)
			if res is DayEvent:
				day_events.append(res)
		file = dir.get_next()
	dir.list_dir_end()

func get_day_event(event_id: StringName) -> DayEvent:
	for e in day_events:
		if e.id == event_id:
			return e
	return null

# Debug: force a specific event (or force "none") on the NEXT start_next_day(),
# bypassing the random roll. Empty StringName = no override.
var _forced_event_id: StringName = &""
var _force_event_active: bool = false

func force_next_event(event_id: StringName) -> void:
	_forced_event_id = event_id
	_force_event_active = true

# Roll for a special day. Sets today_event (or null) and announces it. Called from
# start_next_day(). Never fires on day 1 (that day is scripted).
func _roll_day_event() -> void:
	today_event = null
	# Debug override consumes one roll: force a specific event or force none.
	if _force_event_active:
		_force_event_active = false
		today_event = get_day_event(_forced_event_id) if _forced_event_id != &"" else null
		_forced_event_id = &""
		return
	if current_day <= 1 or day_events.is_empty():
		return
	if randf() >= SPECIAL_DAY_CHANCE:
		return
	today_event = _pick_weighted_event()

func _pick_weighted_event() -> DayEvent:
	var total := 0.0
	for e in day_events:
		total += e.weight
	if total <= 0.0:
		return null
	var roll := randf() * total
	var accum := 0.0
	for e in day_events:
		accum += e.weight
		if roll <= accum:
			return e
	return day_events[day_events.size() - 1]

# Day-event multipliers (neutral 1.0 when there's no special day).
func today_event_money_mult() -> float:
	return today_event.money_mult if today_event != null else 1.0

func today_event_day_length_mult() -> float:
	return today_event.day_length_mult if today_event != null else 1.0

# Ore-spawn weight multiplier for money-bearing blocks (rich-vein day). 1.0 normally.
func today_event_ore_weight_mult() -> float:
	return today_event.ore_weight_mult if today_event != null else 1.0

# Cave-in crumble-chance override for the day, or <0 when there's no override.
func today_event_crumble_chance() -> float:
	return today_event.crumble_chance if today_event != null else -1.0

# Dig-speed multiplier for the day (>1 faster, <1 slower). 1.0 normally.
func today_event_dig_speed_mult() -> float:
	return today_event.dig_speed_mult if today_event != null else 1.0

# The one ore flooded today ("" if none) and its extra weight multiplier.
func today_event_flood_ore_id() -> StringName:
	return today_event.flood_ore_id if today_event != null else &""

func today_event_flood_ore_mult() -> float:
	return today_event.flood_ore_mult if today_event != null else 1.0

func get_helper(helper_id: StringName) -> Helper:
	for h in helpers:
		if h.id == helper_id:
			return h
	return null

func helper_level(helper_id: StringName) -> int:
	return helper_levels.get(helper_id, 0)

func helper_cost(helper_id: StringName) -> float:
	var h := get_helper(helper_id)
	if h == null:
		return INF
	if h.is_maxed(helper_level(helper_id)):
		return INF
	return h.cost_at(helper_level(helper_id))

func helper_unlocked(helper_id: StringName) -> bool:
	# Helpers only exist once the city has grown (Arya's labor company).
	if not city_unlocked:
		return false
	var h := get_helper(helper_id)
	if h == null:
		return false
	return total_money_earned >= h.unlock_money

func can_afford_helper(helper_id: StringName) -> bool:
	var h := get_helper(helper_id)
	if h == null or h.is_maxed(helper_level(helper_id)):
		return false
	return money >= helper_cost(helper_id)

func hire_helper(helper_id: StringName) -> bool:
	var h := get_helper(helper_id)
	if h == null or h.is_maxed(helper_level(helper_id)):
		return false
	var cost := helper_cost(helper_id)
	if money < cost:
		return false
	money -= cost
	money_changed.emit(money)
	var lvl: int = helper_levels.get(helper_id, 0) + 1
	helper_levels[helper_id] = lvl
	helper_hired.emit(helper_id, lvl)
	return true

# Total passive dirt/sec across all hired helpers.
func helper_dirt_per_sec() -> float:
	var total := 0.0
	for h in helpers:
		var lvl: int = helper_levels.get(h.id, 0)
		if lvl > 0 and h.dirt_per_sec > 0.0:
			total += h.dirt_per_sec * float(lvl)
	return total

# Total passive ore/sec per ore type across all hired helpers.
func helper_ore_per_sec_all() -> Dictionary:
	var out: Dictionary = {}
	for h in helpers:
		var lvl: int = helper_levels.get(h.id, 0)
		if lvl > 0 and h.ore_id != &"" and h.ore_per_sec > 0.0:
			out[h.ore_id] = float(out.get(h.ore_id, 0.0)) + h.ore_per_sec * float(lvl)
	return out

func has_any_helpers() -> bool:
	for k in helper_levels.keys():
		if int(helper_levels[k]) > 0:
			return true
	return false

# Drop dirt straight into the deposit pile (helpers bypass the backpack).
func _deposit_dirt_directly(amount: float) -> void:
	if amount <= 0.0:
		return
	deposited_dirt += amount
	total_dirt_dug += amount
	deposited_changed.emit(deposited_dirt)

func _check_cutscenes() -> bool:
	print("[cutscene] check: day=", current_day, " money_earned=", total_money_earned, " loaded=", cutscenes.size())
	for c in cutscenes:
		var already: bool = triggered_cutscenes.get(c.id, false)
		if c.run_once and already:
			print("  skip (already triggered): ", c.id)
			continue
		var fired := false
		match c.trigger:
			Cutscene.Trigger.FIRST_LAUNCH:
				fired = current_day == 1 and total_money_earned == 0.0 \
					and not already
			Cutscene.Trigger.DAY_NUMBER:
				fired = current_day == int(c.threshold)
			Cutscene.Trigger.MONEY_TOTAL_EARNED:
				fired = total_money_earned >= c.threshold
		print("  ", c.id, " trigger=", c.trigger, " threshold=", c.threshold, " fired=", fired)
		if fired:
			if c.run_once:
				triggered_cutscenes[c.id] = true
			cutscene_triggered.emit(c)
			return true
	return false
