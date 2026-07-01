class_name CharacterFigure
extends Interactable

# A placeholder family/Arya figure the player can walk up to and talk to (E).
# Flavor-only for now: pressing E shows a placeholder line. This is the hook the
# gift/heart-event system will build on later. Spawned per-room by room.gd based
# on GameState's daily placement roll.

# Per-character placeholder look + name + a couple of throwaway lines.
# (All copy is placeholder pending the writing pass.)
const CHARACTER_INFO: Dictionary = {
	"mom": {
		"name": "Mom",
		"color": Color(0.62, 0.35, 0.42),
		"lines": ["\"There's food if you want it.\"", "\"You look tired. Sit a minute.\""],
	},
	"dad": {
		"name": "Dad",
		"color": Color(0.30, 0.40, 0.52),
		"lines": ["He nods at you. Keeps working.", "\"...\" He turns the part over in his hands."],
	},
	"sister": {
		"name": "Sister",
		"color": Color(0.45, 0.52, 0.35),
		"lines": ["\"The numbers are fine. You're fine.\"", "\"Don't spend it all on shovels.\""],
	},
	"arya": {
		"name": "Arya",
		"color": Color(0.70, 0.55, 0.30),
		"lines": ["\"Oh — you're up. I lost track of time.\"", "\"I had an idea. Tell you later.\""],
	},
}

var character_id: StringName = &""
var _body: ColorRect
var _line_label: Label
var _line_index: int = 0

func configure(char_id: StringName) -> void:
	character_id = char_id
	if is_node_ready():
		_apply()

func _ready() -> void:
	super._ready()
	# Build the placeholder body + line label as children so we don't need a
	# per-character scene. (48x64-ish figure matching the interact shape.)
	_body = ColorRect.new()
	_body.size = Vector2(32, 56)
	_body.position = Vector2(-16, -56)
	_body.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(_body)
	_line_label = Label.new()
	_line_label.position = Vector2(-90, -104)
	_line_label.size = Vector2(180, 40)
	_line_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_line_label.add_theme_font_size_override("font_size", 12)
	_line_label.add_theme_color_override("font_color", Color(1, 0.97, 0.88))
	_line_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_line_label.visible = false
	add_child(_line_label)
	interacted.connect(_on_talk)
	_apply()

func _apply() -> void:
	var info: Dictionary = CHARACTER_INFO.get(String(character_id), {})
	var display: String = info.get("name", String(character_id).capitalize())
	if _body != null:
		_body.color = info.get("color", Color(0.6, 0.5, 0.4))
	set_prompt("[E] %s" % display)

func _on_talk() -> void:
	var info: Dictionary = CHARACTER_INFO.get(String(character_id), {})
	var lines: Array = info.get("lines", ["..."])
	if lines.is_empty():
		return
	_line_label.text = String(lines[_line_index % lines.size()])
	_line_index += 1
	_line_label.visible = true
	# Auto-hide the line after a beat.
	var t := get_tree().create_timer(2.5)
	t.timeout.connect(func(): if is_instance_valid(_line_label): _line_label.visible = false)
