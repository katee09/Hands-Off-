# =========================
# script/timer.gd  (attach to: CanvasLayer/Panel that holds Minutes/Seconds/MSec labels)
# Pins the timer to top-right and ensures labels exist.
# =========================
extends Control

@export var run_when_paused := false
var elapsed := 0.0

@onready var minutes_lbl: Label = get_node_or_null("Minutes")
@onready var seconds_lbl: Label = get_node_or_null("Seconds")
@onready var msec_lbl:    Label = get_node_or_null("MSec")   # NOTE: capital S

func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS if run_when_paused else Node.PROCESS_MODE_INHERIT
	# anchor to top-right with small margin
	set_anchors_preset(Control.PRESET_TOP_RIGHT)
	offset_right = -10
	offset_top   = 10
	custom_minimum_size = Vector2(180, 30)

	_ensure_labels()
	_update_labels()

func _process(delta: float) -> void:
	elapsed += delta
	_update_labels()

func reset() -> void:
	elapsed = 0.0
	_update_labels()

func _ensure_labels() -> void:
	if minutes_lbl == null:
		minutes_lbl = Label.new(); minutes_lbl.name = "Minutes"; add_child(minutes_lbl)
	if seconds_lbl == null:
		seconds_lbl = Label.new(); seconds_lbl.name = "Seconds"; add_child(seconds_lbl)
	if msec_lbl == null:
		msec_lbl = Label.new();    msec_lbl.name = "MSec";     add_child(msec_lbl)

	for l in [minutes_lbl, seconds_lbl, msec_lbl]:
		l.add_theme_color_override("font_color", Color.WHITE)
		l.add_theme_font_size_override("font_size", 28)

	# relative positions inside the small panel
	minutes_lbl.position = Vector2(0, 0)
	seconds_lbl.position = Vector2(60, 0)
	msec_lbl.position    = Vector2(120, 0)

func _update_labels() -> void:
	var total_ms := int(round(elapsed * 1000.0))
	var m := (total_ms / 1000) / 60
	var s := (total_ms / 1000) % 60
	var ms := total_ms % 1000

	minutes_lbl.text = "%02d:" % m
	seconds_lbl.text = "%02d." % s
	msec_lbl.text    = "%03d" % ms
