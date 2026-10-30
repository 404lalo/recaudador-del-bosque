class_name SettingsUI
## Menú de Ajustes (controles táctiles, vibración y servidor). Lo usan el menú principal y el
## menú de pausa: SettingsUI.build(contenedor, al_volver). Cada cambio se aplica al instante y
## se guarda en user://settings.cfg (Game.set_control / Api.set_server_url).

const GOLD := Color(1.0, 0.82, 0.32)
const CREAM := Color(0.98, 0.94, 0.84)

const MODE_NAMES := {"auto": "Automático (solo celular)", "on": "Siempre (depuración en PC)", "off": "Nunca"}


static func build(parent: VBoxContainer, on_back: Callable) -> void:
	var grid := GridContainer.new()
	grid.columns = 3
	grid.add_theme_constant_override("h_separation", 16)
	grid.add_theme_constant_override("v_separation", 10)
	parent.add_child(grid)

	# Modo de controles táctiles
	_label(grid, "Controles táctiles")
	var mode := OptionButton.new()
	mode.custom_minimum_size = Vector2(300, 48)
	mode.add_theme_font_size_override("font_size", 18)
	for k in Game.TOUCH_MODES:
		mode.add_item(MODE_NAMES[k])
	mode.selected = Game.TOUCH_MODES.find(Game.touch_mode)
	mode.item_selected.connect(func(i: int):
		Game.set_control("touch_mode", Game.TOUCH_MODES[i])
		Game.capture_mouse(false))
	grid.add_child(mode)
	_label(grid, "F3 en PC", 14, Color(CREAM, 0.6))

	_slider(grid, "Opacidad", "touch_opacity", 0.2, 1.0, 0.05, func(v): return "%d %%" % int(round(v * 100)))
	_slider(grid, "Tamaño", "touch_scale", 0.6, 1.6, 0.05,
		func(v): return "%d px" % int(round(140.0 * v)))  # tamaño del botón SALTAR
	_slider(grid, "Zona muerta", "deadzone", 0.0, 0.5, 0.01, func(v): return "%.2f" % v)
	_slider(grid, "Sensibilidad cámara", "look_sensitivity", 0.3, 3.0, 0.1, func(v): return "x%.1f" % v)

	# Vibración
	_label(grid, "Vibración")
	var vib := CheckButton.new()
	vib.text = "Activada"
	vib.button_pressed = Game.vibration
	vib.custom_minimum_size = Vector2(0, 48)
	vib.add_theme_font_size_override("font_size", 18)
	vib.toggled.connect(func(on: bool):
		Game.set_control("vibration", on)
		if on:
			Game.vibrate(Game.VIBRATION_MS.media))
	grid.add_child(vib)
	_label(grid, "Android", 14, Color(CREAM, 0.6))

	# Servidor (en el celular hay que poner la IP de la PC que corre server/run.py)
	_label(grid, "Servidor")
	var url := LineEdit.new()
	url.text = Api.base_url
	url.custom_minimum_size = Vector2(300, 48)
	url.add_theme_font_size_override("font_size", 16)
	url.placeholder_text = "http://192.168.1.50:8000"
	grid.add_child(url)
	var test := Button.new()
	test.text = "Probar"
	test.custom_minimum_size = Vector2(110, 48)
	grid.add_child(test)
	var status := _label(parent, "", 15, Color(CREAM, 0.75))
	status.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	var probe := func():
		Api.set_server_url(url.text)
		url.text = Api.base_url
		status.text = "Conectando con %s ..." % Api.base_url
		Api.ping(func(ok: bool):
			if is_instance_valid(status):
				status.text = "✓ Servidor en línea" if ok else "✗ Sin conexión (los datos se guardan y se envían después)")
	test.pressed.connect(probe)
	url.text_submitted.connect(func(_t): probe.call())

	var back := Button.new()
	back.text = "Volver"
	back.custom_minimum_size = Vector2(360, 54)
	back.add_theme_font_size_override("font_size", 22)
	back.pressed.connect(func():
		if url.text.strip_edges() != Api.base_url:
			Api.set_server_url(url.text)
		on_back.call())
	var row := CenterContainer.new()
	row.add_child(back)
	parent.add_child(row)
	back.grab_focus.call_deferred()


static func _label(parent: Node, t: String, size := 19, color := CREAM) -> Label:
	var l := Label.new()
	l.text = t
	l.add_theme_font_size_override("font_size", size)
	l.add_theme_color_override("font_color", color)
	l.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	parent.add_child(l)
	return l


static func _slider(grid: GridContainer, title: String, key: String, lo: float, hi: float, step: float,
		fmt: Callable) -> void:
	_label(grid, title)
	var s := HSlider.new()
	s.min_value = lo
	s.max_value = hi
	s.step = step
	s.value = float(Game.get(key))
	s.custom_minimum_size = Vector2(300, 48)
	grid.add_child(s)
	var val := _label(grid, fmt.call(s.value), 18, GOLD)
	val.custom_minimum_size = Vector2(110, 0)
	s.value_changed.connect(func(v: float):
		val.text = fmt.call(v)
		Game.set_control(key, v))
