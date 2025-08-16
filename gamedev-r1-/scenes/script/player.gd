# === player.gd (DROP-IN) ===
# Attach to: Player (CharacterBody2D)

extends CharacterBody2D

# --- movement & bounds ---
@export var speed: float = 500.0
@export var min_x: float = -450.0
@export var max_x: float =  450.0

# --- dash ---
@export var dash_speed: float = 1100.0
@export var dash_time: float = 0.18
@export var dash_cooldown: float = 0.35

# --- parry ---
@export var parry_window: float = 0.16
@export var parry_cooldown: float = 0.70

# --- lives ---
@export var max_hits: int = 3
@export var invuln_time: float = 0.60
var hits_left: int = 0

# --- costumes (use only right_tex & flip for left) ---
@export var idle_tex:  Texture2D
@export var right_tex: Texture2D
@export var catch_tex: Texture2D
@onready var sprite: Sprite2D = $Sprite2D

# state
var _lane_y: float = 0.0
var _is_grabbed: bool = false
var _invuln_until: float = 0.0

# dash state
var _dash_until: float = 0.0
var _dash_cd_until: float = 0.0
var _dash_dir_cached: float = 1.0

# parry state
var _parry_until: float = 0.0
var _parry_cd_until: float = 0.0

signal hit(remaining: int)
signal died

func _ready() -> void:
	add_to_group("player_group")
	_lane_y = global_position.y
	hits_left = max_hits
	_set_idle()

	# Ensure actions exist (you can still remap in Input Map)
	if not InputMap.has_action("dash"):
		InputMap.add_action("dash")
		var ev := InputEventKey.new(); ev.physical_keycode = KEY_SHIFT
		InputMap.action_add_event("dash", ev)
	if not InputMap.has_action("parry"):
		InputMap.add_action("parry")
		var ev2 := InputEventKey.new(); ev2.physical_keycode = KEY_E
		InputMap.action_add_event("parry", ev2)

func _unhandled_input(event: InputEvent) -> void:
	# ---- QUICK LOGS ----
	if event.is_action_pressed("dash"):  print("[Input] DASH pressed")
	if event.is_action_pressed("parry"): print("[Input] PARRY pressed")
	# --------------------

	var t: float = float(Time.get_ticks_msec()) / 1000.0

	# Start dash
	if event.is_action_pressed("dash") and not _is_grabbed and t >= _dash_cd_until:
		_dash_until = t + dash_time
		_dash_cd_until = t + dash_cooldown
		var axis: float = Input.get_axis("ui_left", "ui_right")
		if axis != 0.0:
			_dash_dir_cached = signf(axis)
		elif velocity.x != 0.0:
			_dash_dir_cached = signf(velocity.x)
		else:
			_dash_dir_cached = 1.0
		print("[Dash] start dir=", _dash_dir_cached)

	# Start parry
	if event.is_action_pressed("parry") and not _is_grabbed and t >= _parry_cd_until:
		_parry_until = t + parry_window
		_parry_cd_until = t + parry_cooldown
		# small visual ping
		sprite.modulate = Color(0.75, 1.0, 1.0, 1.0)
		await get_tree().create_timer(0.08).timeout
		sprite.modulate = Color(1, 1, 1, 1)
		print("[Parry] window until=", _parry_until)

func _physics_process(_dt: float) -> void:
	var t: float = float(Time.get_ticks_msec()) / 1000.0
	var axis: float = Input.get_axis("ui_left", "ui_right")

	if _is_grabbed:
		velocity.x = 0.0
	else:
		if t < _dash_until:
			var dir_for_dash: float = 0.0
			if velocity.x != 0.0:
				dir_for_dash = signf(velocity.x)
			elif axis != 0.0:
				dir_for_dash = signf(axis)
			else:
				dir_for_dash = _dash_dir_cached
			if dir_for_dash == 0.0:
				dir_for_dash = 1.0
			velocity.x = dir_for_dash * dash_speed
		else:
			velocity.x = axis * speed

	# lane lock & bounds
	global_position.y = _lane_y
	global_position.x = clampf(global_position.x, min_x, max_x)
	move_and_slide()

	# costumes (RIGHT only; flip for left)
	if _is_grabbed:
		_set_catch()
	elif absf(velocity.x) < 1.0:
		_set_idle()
	elif velocity.x > 0.0:
		_set_face_right()
	else:
		_set_face_left()

# ===== public hooks for hands =====
func is_parrying() -> bool:
	return float(Time.get_ticks_msec()) / 1000.0 < _parry_until

func on_crushed() -> void:
	var now: float = float(Time.get_ticks_msec()) / 1000.0
	if now < _invuln_until:
		return
	# If hands forgot to check parry, still allow cancel here
	if is_parrying():
		print("[Parry] Crush negated (late-check)")
		return

	hits_left -= 1
	emit_signal("hit", hits_left)
	print("[Hit] remaining lives=", hits_left)

	# red flash
	sprite.modulate = Color(1, 0.35, 0.35, 1)
	await get_tree().create_timer(0.2).timeout
	sprite.modulate = Color(1, 1, 1, 1)

	_invuln_until = now + invuln_time
	if hits_left <= 0:
		print("[Death] player died")
		emit_signal("died")

func on_grabbed() -> void:
	_is_grabbed = true
	velocity.x = 0.0
	_set_catch()
	print("[Grab] grabbed")

func on_released() -> void:
	_is_grabbed = false
	if absf(velocity.x) < 1.0: _set_idle()
	elif velocity.x > 0.0:     _set_face_right()
	else:                      _set_face_left()
	print("[Grab] released")

# ===== costume helpers =====
func _set_idle() -> void:
	if idle_tex: sprite.texture = idle_tex
	sprite.flip_h = false

func _set_face_right() -> void:
	if right_tex: sprite.texture = right_tex
	sprite.flip_h = false

func _set_face_left() -> void:
	if right_tex: sprite.texture = right_tex
	sprite.flip_h = true

func _set_catch() -> void:
	if catch_tex: sprite.texture = catch_tex
	sprite.flip_h = false
