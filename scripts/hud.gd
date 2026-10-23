extends CanvasLayer
## HUD: dinero, nivel, protección, indicación de interacción y avisos.

var money_label: Label
var info_label: Label
var prompt_label: Label
var toast_label: Label
var toast_timer := 0.0
var acorn_label: Label
var level_acorns := 0        # bellotas recogidas en este nivel
var level_acorns_total := 0  # bellotas que hay en este nivel (0 = no mostrar)
var zone_name := ""  # si se define (p. ej. "Tutorial"), reemplaza el nombre del nivel


func _ready() -> void:
	layer = 5
	money_label = _label(Vector2(20, 14), 30, Color(1, 0.85, 0.3))
	info_label = _label(Vector2(20, 56), 18, Color.WHITE)
	acorn_label = _label(Vector2(20, 82), 18, Color(1.0, 0.72, 0.3))
	prompt_label = Label.new()
	prompt_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_BOTTOM)
	prompt_label.offset_top = -120
	prompt_label.offset_left = -300
	prompt_label.offset_right = 300
	prompt_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	prompt_label.add_theme_font_size_override("font_size", 24)
	prompt_label.add_theme_color_override("font_outline_color", Color.BLACK)
	prompt_label.add_theme_constant_override("outline_size", 6)
	add_child(prompt_label)
	toast_label = Label.new()
	toast_label.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	toast_label.offset_top = 120
	toast_label.offset_left = -400
	toast_label.offset_right = 400
	toast_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	toast_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	toast_label.add_theme_font_size_override("font_size", 26)
	toast_label.add_theme_color_override("font_outline_color", Color.BLACK)
	toast_label.add_theme_constant_override("outline_size", 8)
	add_child(toast_label)
	Game.money_changed.connect(refresh)
	refresh()


func _label(pos: Vector2, size: int, color: Color) -> Label:
	var l := Label.new()
	l.position = pos
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.add_theme_color_override("font_outline_color", Color.BLACK)
	l.add_theme_constant_override("outline_size", 6)
	add_child(l)
	return l


func refresh() -> void:
	money_label.text = "$ %d" % Game.money
	info_label.text = "%s  |  Protección: %s" % [
		zone_name if zone_name != "" else Game.LEVELS[Game.level_index].name, Game.PROT_NAMES[Game.protection]]
	if level_acorns_total > 0:
		acorn_label.text = "Bellotas doradas: %d/%d   ·   Monedas: %d" % [level_acorns, level_acorns_total, Game.coins]
	else:
		acorn_label.text = ""


func set_prompt(t: String) -> void:
	prompt_label.text = t


func toast(t: String, secs := 3.5) -> void:
	toast_label.text = t
	toast_timer = secs


func _process(delta: float) -> void:
	if toast_timer > 0:
		toast_timer -= delta
		if toast_timer <= 0:
			toast_label.text = ""
