extends Node
## Capturas automáticas de la interfaz móvil (no es parte del juego).
## Uso:  godot --path . --resolution 1600x720 -- --test=shots
## Simula un celular 20:9 con controles táctiles y guarda PNG en .godot/test_shots/.

const SHOTS := "res://.godot/test_shots"


func _ready() -> void:
	Game.touch_mode = "on"
	Game.slot = 99
	Game.settings_changed.emit()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	await _wait(60)
	await _shot("menu")
	var menu := get_tree().current_scene
	menu._show_settings()
	await _wait(10)
	await _shot("ajustes")
	menu._close_modal()
	Game.level_index = 2
	get_tree().change_scene_to_file("res://scenes/level.tscn")
	await _wait(120)
	var lvl := get_tree().current_scene
	lvl.hud.toast("¡Bellota dorada! 1/3", 3.0)
	var screen := get_viewport().get_visible_rect().size
	var e := InputEventScreenTouch.new()
	e.index = 0
	e.position = Vector2(240, screen.y - 220)
	e.pressed = true
	Input.parse_input_event(e)
	var d := InputEventScreenDrag.new()
	d.index = 0
	d.position = e.position + Vector2(40, -60)
	d.relative = Vector2(40, -60)
	Input.parse_input_event(d)
	await _wait(20)
	await _shot("hud_nivel")
	e.pressed = false
	Input.parse_input_event(e)
	await _wait(5)
	lvl.pause_menu.open()
	await _wait(5)
	lvl.pause_menu._show_settings()
	await _wait(5)
	await _shot("pausa_ajustes")
	get_tree().paused = false
	print("SHOTS DONE")
	get_tree().quit()


func _wait(n: int) -> void:
	for i in n:
		await get_tree().process_frame


func _shot(name: String) -> void:
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(SHOTS + "/%s.png" % name)
