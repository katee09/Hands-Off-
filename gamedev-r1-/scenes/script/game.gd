# === script/game.gd (DROP-IN) ===
# Attach to your root "game" (Node2D). Press Enter to restart after death.

extends Node2D

@onready var player  := get_node_or_null("player")
@onready var crusher := get_node_or_null("crusher")
@onready var grabber := get_node_or_null("grabber")
@onready var stalker := get_node_or_null("stalker")  # optional

var _dead := false
var _canvas: CanvasLayer
var _death_overlay: Control
var _death_label: Label

func _ready() -> void:
	# Connect player signals
	if player:
		if not player.hit.is_connected(_on_player_hit):  player.hit.connect(_on_player_hit)
		if not player.died.is_connected(_on_player_died): player.died.connect(_on_player_died)
	# Simple UI overlay (auto-created)
	_make_death_overlay()

func _unhandled_input(e: InputEvent) -> void:
	# Restart on Enter after death
	if _dead and e.is_action_pressed("ui_accept"):
		get_tree().paused = false
		get_tree().reload_current_scene()

func _on_player_hit(_remaining: int) -> void:
	# nothing special here; hands self-adjust
	pass

func _on_player_died() -> void:
	_dead = true
	get_tree().paused = true
	_show_death("You Died — press Enter")

func _make_death_overlay() -> void:
	_canvas = get_node_or_null("CanvasLayer")
	if _canvas == null:
		_canvas = CanvasLayer.new()
		_canvas.name = "CanvasLayer"
		add_child(_canvas)

	_death_overlay = _canvas.get_node_or_null("DeathOverlay") as Control
	if _death_overlay == null:
		_death_overlay = Control.new()
		_death_overlay.name = "DeathOverlay"
		_death_overlay.set_anchors_preset(Control.PRESET_FULL_RECT)
		_death_overlay.visible = false
		_death_overlay.process_mode = Node.PROCESS_MODE_ALWAYS
		_canvas.add_child(_death_overlay)
		var dim := ColorRect.new()
		dim.color = Color(0,0,0,0.6)
		dim.set_anchors_preset(Control.PRESET_FULL_RECT)
		_death_overlay.add_child(dim)
		_death_label = Label.new()
		_death_label.name = "DeathLabel"
		_death_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
		_death_label.vertical_alignment   = VERTICAL_ALIGNMENT_CENTER
		_death_label.add_theme_color_override("font_color", Color(1,0.3,0.3,1))
		_death_label.add_theme_font_size_override("font_size", 72)
		_death_label.set_anchors_preset(Control.PRESET_FULL_RECT)
		_death_overlay.add_child(_death_label)
	else:
		_death_label = _death_overlay.get_node_or_null("DeathLabel") as Label

func _show_death(text: String) -> void:
	if _death_label: _death_label.text = text
	if _death_overlay:
		_death_overlay.visible = true
		_death_overlay.raise()
