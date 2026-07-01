class_name CrackOverlay
extends Node2D

# Draws worsening cracks over a block as it takes damage. Two modes:
#  - If stage textures are provided (crack_1.png, crack_2.png in the blocks dir),
#    show the one for the current stage as a scaled sprite.
#  - Otherwise draw procedural crack lines in _draw(), getting denser per stage.
# Stage 0 = pristine (nothing drawn). Stage 1 = light. Stage 2 = heavy.

const SIZE: Vector2 = Vector2(48, 48)
const CRACK_COLOR: Color = Color(0.05, 0.04, 0.03, 0.85)

# Optional hand-drawn overlays; index 0 unused, [1]=light, [2]=heavy.
var stage_textures: Array[Texture2D] = []

var _stage: int = 0
var _seed: int = 0
@onready var _sprite: Sprite2D = $Sprite

func configure(stage_texs: Array[Texture2D], seed_value: int) -> void:
	stage_textures = stage_texs
	_seed = seed_value

func set_stage(stage: int) -> void:
	if stage == _stage:
		return
	_stage = stage
	_refresh()

func _ready() -> void:
	_refresh()

func _refresh() -> void:
	var tex: Texture2D = null
	if _stage > 0 and _stage < stage_textures.size():
		tex = stage_textures[_stage]
	if tex != null:
		# Hand-drawn overlay available: show it scaled to fill the cell.
		_sprite.visible = true
		_sprite.texture = tex
		_sprite.centered = true
		var ts: Vector2 = tex.get_size()
		if ts.x > 0.0 and ts.y > 0.0:
			_sprite.scale = Vector2((SIZE.x / ts.x) * 1.04, (SIZE.y / ts.y) * 1.04)
		queue_redraw()  # clear any procedural cracks
	else:
		# Procedural fallback.
		_sprite.visible = false
		queue_redraw()

func _draw() -> void:
	# Only used when no stage texture is present.
	if _stage <= 0:
		return
	if _stage < stage_textures.size() and stage_textures[_stage] != null:
		return  # texture mode handles it
	var rng := RandomNumberGenerator.new()
	rng.seed = _seed
	# Cracks fan out from the block CENTRE toward the edges so damage reads across
	# the whole face, not bunched in one corner. Each crack is long enough to reach
	# most of the way to the edge (half-diagonal ~= 34px at 48).
	var crack_count: int = 3 if _stage == 1 else 5
	var reach: float = SIZE.x * (0.55 if _stage == 1 else 0.72)
	var width: float = 1.5 if _stage == 1 else 2.5
	# Origin is the centre with only a hair of jitter, keeping the fan balanced.
	var origin := Vector2(rng.randf_range(-2.0, 2.0), rng.randf_range(-2.0, 2.0))
	# Evenly space the base angles around the circle (+ jitter) so the cracks point
	# in different directions and cover all quadrants.
	var base := rng.randf_range(0.0, TAU)
	var step := TAU / float(crack_count)
	for i in crack_count:
		var ang := base + step * float(i) + rng.randf_range(-0.35, 0.35)
		var length := reach * rng.randf_range(0.8, 1.0)
		_draw_crack(rng, origin, ang, length, width)

func _draw_crack(rng: RandomNumberGenerator, start: Vector2, angle: float, length: float, width: float) -> void:
	# A jagged polyline that walks outward from the centre toward an edge.
	var pts: PackedVector2Array = [start]
	var pos := start
	var segs: int = rng.randi_range(3, 5)
	var seg_len := length / float(segs)
	var a := angle
	for _i in segs:
		a += rng.randf_range(-0.4, 0.4)  # wander, but keep the outward heading
		pos += Vector2(cos(a), sin(a)) * seg_len
		pos.x = clampf(pos.x, -SIZE.x * 0.5 + 1.0, SIZE.x * 0.5 - 1.0)
		pos.y = clampf(pos.y, -SIZE.y * 0.5 + 1.0, SIZE.y * 0.5 - 1.0)
		pts.append(pos)
	draw_polyline(pts, CRACK_COLOR, width)
	# Heavy stage sprouts a branch partway along for a shattered look.
	if _stage >= 2 and pts.size() >= 3:
		var mid := pts[pts.size() / 2]
		var branch := mid + Vector2(cos(a + 1.1), sin(a + 1.1)) * (seg_len * 1.1)
		branch.x = clampf(branch.x, -SIZE.x * 0.5 + 1.0, SIZE.x * 0.5 - 1.0)
		branch.y = clampf(branch.y, -SIZE.y * 0.5 + 1.0, SIZE.y * 0.5 - 1.0)
		draw_line(mid, branch, CRACK_COLOR, width * 0.7)
