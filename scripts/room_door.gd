class_name RoomDoor
extends Interactable

# A door that transitions the player to a target room when E is pressed.

@export var target_room_id: StringName = &""
@export var spawn_x: float = NAN  # NAN = use the target room's default spawn

func _ready() -> void:
	super._ready()
	interacted.connect(_on_door_used)

func _on_door_used() -> void:
	if target_room_id == &"":
		push_warning("RoomDoor '%s' has no target_room_id" % name)
		return
	GameState.set_room(target_room_id, spawn_x)
