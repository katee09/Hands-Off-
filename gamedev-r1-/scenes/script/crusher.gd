# === script/crusher.gd (DROP-IN) ===
# Node2D with children: Sprite2D, Hitbox:Area2D(+CollisionShape2D), optional Think:Timer

extends Node2D

@export var hover_y: float = -180.0
@export var crush_y: float =   40.0
@export var min_x:  float = -450.0
@export var max_x:  float =  450.0
@export var base_hover_speed: float = 220.0
@export var base_drop_speed:  float = 900.0
@export var wait_between_attacks: Vector2 = Vector2(0.8, 1.6)

@export var hover_tex: Texture2D
@export var drop_tex:  Texture2D

# === adaptive speed per attempt ===
@export var mult_init: float = 1.0
@export var mult_min:  float = 0.6
@export var mult_max:  float = 3.0
@export var miss_step: float = 0.08   # +8% speed on MISS (no crush)
@export var hit_step:  float = 0.12   # -12% speed on HIT (crush)

enum { HOVER, DROPPING, RETURNING }
var _state: int = HOVER
var _target_x: float = 0.0
var _mult: float = 1.0
var _hit_this_drop: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D   = get_node_or_null("Hitbox")
@onready var think:  Timer    = get_node_or_null("Think")
var _stun_timer: Timer

func set_difficulty(mult: float) -> void: _mult = clampf(mult, mult_min, mult_max)
func sleep(stop: bool) -> void:
	if think:
		if stop: think.stop() 
		else: _arm_think()

func _ready() -> void:
	_mult = mult_init
	if hitbox:
		hitbox.collision_layer = 0
		hitbox.collision_mask  = 1
		hitbox.monitoring = false
		if not hitbox.body_entered.is_connected(_on_body): hitbox.body_entered.connect(_on_body)
	if think == null:
		think = Timer.new(); think.name = "Think"; think.one_shot = true; add_child(think)
	if not think.timeout.is_connected(_decide): think.timeout.connect(_decide)
	_stun_timer = Timer.new(); _stun_timer.one_shot = true; add_child(_stun_timer)
	_stun_timer.timeout.connect(func(): _arm_think())

	global_position.y = hover_y
	_set_hover_tex()
	_pick_new_target()
	_arm_think()

func _physics_process(delta: float) -> void:
	var hs := base_hover_speed * _mult
	var ds := base_drop_speed  * _mult

	match _state:
		HOVER:
			global_position.x = move_toward(global_position.x, _target_x, hs * delta)

		DROPPING:
			global_position.y = move_toward(global_position.y, crush_y, ds * delta)
			if is_equal_approx(global_position.y, crush_y):
				# adjust speed based on hit/miss
				if _hit_this_drop: _on_hit_adjust() 
				else: _on_miss_adjust()
				_state = RETURNING
				if hitbox: hitbox.set_deferred("monitoring", false)

		RETURNING:
			global_position.y = move_toward(global_position.y, hover_y, ds * delta)
			if is_equal_approx(global_position.y, hover_y):
				_state = HOVER
				_set_hover_tex()
				_pick_new_target()
				_arm_think()

func _decide() -> void:
	if _state == HOVER and absf(global_position.x - _target_x) <= 0.5:
		_state = DROPPING
		_set_drop_tex()
		_hit_this_drop = false
		if hitbox: hitbox.set_deferred("monitoring", true)
	_arm_think()

func _arm_think() -> void:
	var wait := randf_range(wait_between_attacks.x, wait_between_attacks.y)
	think.start(maxf(0.05, wait / maxf(_mult, 0.01)))

func _pick_new_target() -> void:
	_target_x = randf_range(min_x, max_x)

func _on_body(body: Node) -> void:
	if _state != DROPPING: return
	# Parry support
	if body.has_method("is_parrying") and body.is_parrying():
		await _stun_for(0.6); return
	if body.has_method("on_crushed"):
		body.on_crushed()
		_hit_this_drop = true

func _on_hit_adjust() -> void:
	_mult = clampf(_mult * (1.0 - hit_step), mult_min, mult_max)

func _on_miss_adjust() -> void:
	_mult = clampf(_mult * (1.0 + miss_step), mult_min, mult_max)

# Parry stun (turn red briefly)
func _stun_for(sec: float) -> void:
	if hitbox: hitbox.set_deferred("monitoring", false)
	_state = RETURNING
	var old := sprite.modulate
	sprite.modulate = Color(1,0.3,0.3,1)
	_stun_timer.start(sec)
	await get_tree().create_timer(sec).timeout
	sprite.modulate = old

func _set_hover_tex() -> void: if hover_tex: sprite.texture = hover_tex
func _set_drop_tex()  -> void: if drop_tex:  sprite.texture = drop_tex
