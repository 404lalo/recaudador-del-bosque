extends CanvasLayer
## Panel modal genérico (tienda, final de nivel, fin del juego).

var title_label: Label
var body_label: Label
var buttons: VBoxContainer


func _ready() -> void:
	layer = 20
	var dim := ColorRect.new()
	dim.color = Color(0, 0, 0, 0.6)
	dim.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(dim)
	var center := CenterContainer.new()
	center.set_anchors_preset(Control.PRESET_FULL_RECT)
	add_child(center)
	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(620, 0)
	center.add_child(panel)
	var margin := MarginContainer.new()
	for side in ["left", "right", "top", "bottom"]:
		margin.add_theme_constant_override("margin_" + side, 24)
	panel.add_child(margin)
	var vb := VBoxContainer.new()
	vb.add_theme_constant_override("separation", 14)
	margin.add_child(vb)
	title_label = Label.new()
	title_label.add_theme_font_size_override("font_size", 32)
	title_label.add_theme_color_override("font_color", Color(1, 0.85, 0.3))
	vb.add_child(title_label)
	body_label = Label.new()
	body_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	body_label.add_theme_font_size_override("font_size", 20)
	vb.add_child(body_label)
	buttons = VBoxContainer.new()
	buttons.add_theme_constant_override("separation", 8)
	vb.add_child(buttons)
	visible = false


## items: [{text, cb: Callable, disabled: bool}]
func show_panel(title: String, body: String, items: Array) -> void:
	title_label.text = title
	body_label.text = body
	for c in buttons.get_children():
		c.queue_free()
	for it in items:
		var b := Button.new()
		b.text = it.text
		b.disabled = it.get("disabled", false)
		b.add_theme_font_size_override("font_size", 20)
		b.pressed.connect(it.cb)
		buttons.add_child(b)
	visible = true
	Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
