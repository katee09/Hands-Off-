# === script/stalker.gd (DROP-IN) ===
# Node2D with children: Sprite2D, Hitbox:Area2D(+CollisionShape2D)

extends Node2D

@export var hover_y: float = -120.0
@export var slam_y:  float =  130.0
@export var min_x:  float = -450.0
@export var max_x:  float =  450.0

@export var base_follow_speed: float = 240.0
@export var base_drop_speed:  float = 900.0
@export var telegraph_time: float = 0.45
@export var align_threshold: float = 36.0
@export var cooldown_time: float = 0.60

@export var hover_tex: Texture2D
@export var drop_tex:  Texture2D

# adaptive speed per slam
@export var mult_init: float = 1.0
@export var mult_min:  float = 0.6
@export var mult_max:  float = 3.0
@export var miss_step: float = 0.08
@export var hit_step:  float = 0.12

enum { STALK, TELEGRAPH, SLAM, RETURN }
var _state: int = STALK
var _target_x: float = 0.0
var _tele_left: float = 0.0
var _cool_until: float = 0.0
var _mult: float = 1.0
var _hit_this_slam: bool = false

@onready var sprite: Sprite2D = $Sprite2D
@onready var hitbox: Area2D   = $Hitbox
var _shadow_rect: ColorRect
var _stun_timer: Timer

func set_difficulty(mult: float) -> void: _mult = clampf(mult, mult_min, mult_max)
func sleep(stop: bool) -> void: set_physics_process(not stop)

func _ready() -> void:
	_mult = mult_init
	sprite.z_index = 20
	sprite.z_as_relative = false
	global_position.y = hover_y

	hitbox.collision_layer = 0
	hitbox.collision_mask  = 1
	hitbox.monitoring = false
	if not hitbox.body_entered.is_connected(_on_hit): hitbox.body_entered.connect(_on_hit)

	_stun_timer = Timer.new(); _stun_timer.one_shot = true; add_child(_stun_timer)

	_make_shadow()
	_update_shadow(false)
	_set_hover_tex()

func _physics_process(delta: float) -> void:
	var t := float(Time.get_ticks_msec()) / 1000.0
	var fs := base_follow_speed * _mult
	var ds := base_drop_speed  * _mult

	match _state:
		STALK:
			var p := get_tree().get_first_node_in_group("player_group") as Node2D
			if p:
				_target_x = clampf(p.global_position.x, min_x, max_x)
			global_position.x = move_toward(global_position.x, _target_x, fs * delta)
			_update_shadow(true)

			if absf(global_position.x - _target_x) <= align_threshold and t >= _cool_until:
				_state = TELEGRAPH
				_hit_this_slam = false
				_tele_left = telegraph_time

		TELEGRAPH:
			_tele_left -= delta
			_update_shadow(true)
			if _tele_left <= 0.0:
				_state = SLAM
				_set_drop_tex()
				hitbox.set_deferred("monitoring", true)

		SLAM:
			global_position.y = move_toward(global_position.y, slam_y, ds * delta)
			_update_shadow(true)
			if is_equal_approx(global_position.y, slam_y):
				# adjust multiplier
				if _hit_this_slam: _on_hit_adjust() 
				else: _on_miss_adjust()
				_state = RETURN
				_cool_until = t + cooldown_time
				hitbox.set_deferred("monitoring", false)
				_update_shadow(false)

		RETURN:
			global_position.y = move_toward(global_position.y, hover_y, ds * delta)
			_update_shadow(false)
			if is_equal_approx(global_position.y, hover_y):
				_state = STALK
				_set_hover_tex()

func _on_hit(body: Node) -> void:
	if _state != SLAM: return
	# parry support
	if body.has_method("is_parrying") and body.is_parrying():
		await _stun_for(0.6); return
	# normal crush
	if body.has_method("on_crushed"):
		body.on_crushed()
		_hit_this_slam = true

# adjusters
func _on_hit_adjust() -> void:  _mult = clampf(_mult * (1.0 - hit_step),  mult_min, mult_max)
func _on_miss_adjust() -> void: _mult = clampf(_mult * (1.0 + miss_step), mult_min, mult_max)

# stun feedback (red)
func _stun_for(sec: float) -> void:
	hitbox.set_deferred("monitoring", false)
	_state = RETURN
	var old := sprite.modulate
	sprite.modulate = Color(1,0.3,0.3,1)
	_stun_timer.start(sec)
	await get_tree().create_timer(sec).timeout
	sprite.modulate = old

# constant bigger shadow
func _make_shadow() -> void:
	if _shadow_rect: return
	_shadow_rect = ColorRect.new()
	_shadow_rect.color = Color(0,0,0,0.55)
	_shadow_rect.size  = Vector2(64, 22)
	_shadow_rect.pivot_offset = _shadow_rect.size * 0.5
	_shadow_rect.z_as_relative = false
	_shadow_rect.z_index = -1
	add_child(_shadow_rect)

func _update_shadow(active: bool) -> void:
	if not _shadow_rect: return
	_shadow_rect.visible = active
	_shadow_rect.global_position = Vector2(_target_x, slam_y + 10.0)

func _set_hover_tex() -> void: if hover_tex: sprite.texture = hover_tex
func _set_drop_tex()  -> void: if drop_tex:  sprite.texture = drop_tex
