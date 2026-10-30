extends Node
## Prueba automática de los controles táctiles (no es parte del juego).
## Uso:  godot --path . -- --test=touch
## Simula dedos con InputEventScreenTouch/Drag y revisa: joystick, multitouch, input buffering,
## coyote time y dash con botones táctiles, y giro de cámara. Deja capturas en .godot/test_shots/.

const SHOTS := "res://.godot/test_shots"
var results := []
var player: CharacterBody3D
var world: Node3D


func _ready() -> void:
	Game.touch_mode = "on"  # solo en memoria: no toca settings.cfg
	Game.slot = 99          # nunca escribe sobre las partidas del jugador
	Game.settings_changed.emit()
	DirAccess.make_dir_recursive_absolute(ProjectSettings.globalize_path(SHOTS))
	get_tree().change_scene_to_node(Node3D.new())  # escena vacía (fuera del menú)
	await get_tree().process_frame
	await get_tree().process_frame
	await _gameplay_tests()
	await _screenshot_tutorial()
	var ok := results.all(func(r): return r.ok)
	for r in results:
		print(("PASS  " if r.ok else "FAIL  ") + r.name + "  " + r.info)
	print("RESULT: ", "ALL PASS" if ok else "FAILURES")
	var f := FileAccess.open(SHOTS + "/results.txt", FileAccess.WRITE)
	for r in results:
		f.store_line(("PASS  " if r.ok else "FAIL  ") + r.name + "  " + r.info)
	f.close()
	get_tree().quit(0 if ok else 1)


func _check(name: String, ok: bool, info := "") -> void:
	results.append({"name": name, "ok": ok, "info": info})


func _touch(index: int, pos: Vector2, pressed: bool) -> void:
	var e := InputEventScreenTouch.new()
	e.index = index
	e.position = pos
	e.pressed = pressed
	Input.parse_input_event(e)


func _drag(index: int, pos: Vector2, rel: Vector2) -> void:
	var e := InputEventScreenDrag.new()
	e.index = index
	e.position = pos
	e.relative = rel
	Input.parse_input_event(e)


func _frames(n: int) -> void:
	for i in n:
		await get_tree().physics_frame


func _btn(action: String) -> Vector2:
	return Touch.buttons[action].slot.position


# ---------------------------------------------------------------- mundo de prueba

func _build_world() -> void:
	world = Node3D.new()
	get_tree().root.add_child(world)
	# Piso de z = -10 a z = 10 y x de -10 a 10; más allá hay vacío (para el coyote time).
	var floor_body := StaticBody3D.new()
	var cs := CollisionShape3D.new()
	var box := BoxShape3D.new()
	box.size = Vector3(20, 1, 20)
	cs.shape = box
	floor_body.add_child(cs)
	floor_body.position = Vector3(0, -0.5, 0)
	world.add_child(floor_body)
	var cam_light := DirectionalLight3D.new()
	world.add_child(cam_light)
	player = CharacterBody3D.new()
	player.set_script(load("res://scripts/player.gd"))
	player.position = Vector3(0, 0.1, 0)
	world.add_child(player)
	await _frames(10)


func _gameplay_tests() -> void:
	await _build_world()
	var screen := get_viewport().get_visible_rect().size
	_check("controles visibles", Touch.shown, "shown=%s" % Touch.shown)

	# 1) Joystick: dedo 0 a la izquierda, arrastrar a la derecha.
	var start := Vector2(220, screen.y - 200)
	_touch(0, start, true)
	_drag(0, start + Vector2(70, 0), Vector2(70, 0))
	await _frames(5)
	var s_right := Input.get_action_strength("move_right")
	_check("joystick -> move_right", s_right > 0.5 and player.velocity.x > 2.0,
		"fuerza=%.2f vel.x=%.2f" % [s_right, player.velocity.x])
	# Zona muerta: un desplazamiento minúsculo no mueve al personaje.
	_drag(0, start + Vector2(8, 0), Vector2(-62, 0))
	await _frames(3)
	_check("zona muerta", absf(player.velocity.x) < 0.01, "vel.x=%.3f (deadzone=%.2f)" % [player.velocity.x, Game.deadzone])
	# A fondo = correr.
	_drag(0, start + Vector2(150, 0), Vector2(142, 0))
	await _frames(3)
	_check("joystick a fondo -> sprint", Input.is_action_pressed("sprint") and player.velocity.x > 9.0,
		"vel.x=%.2f" % player.velocity.x)

	# 2) Multitouch: sin soltar el joystick, dedo 1 toca SALTAR.
	_drag(0, start + Vector2(70, 0), Vector2(-80, 0))
	await _frames(2)
	_touch(1, _btn("jump"), true)
	await _frames(2)
	var vy := player.velocity.y
	var vx := player.velocity.x
	_touch(1, _btn("jump"), false)
	_check("multitouch mover + saltar", vy > 3.0 and vx > 2.0, "vel.y=%.2f vel.x=%.2f" % [vy, vx])
	_touch(0, start, false)
	await _frames(90)  # aterriza

	# 3) Cámara: dedo 2 arrastra en la derecha.
	var yaw0: float = player.yaw
	var cpos := Vector2(screen.x * 0.6, screen.y * 0.4)
	_touch(2, cpos, true)
	_drag(2, cpos + Vector2(-100, 0), Vector2(-100, 0))
	await _frames(1)
	_touch(2, cpos + Vector2(-100, 0), false)
	_check("arrastre gira cámara", absf(player.yaw - yaw0) > 0.3, "Δyaw=%.2f" % (player.yaw - yaw0))
	player.yaw = 0.0
	await _frames(2)

	# 4) Input buffering: soltar al jugador desde lo alto y tocar SALTAR justo antes de aterrizar.
	player.position = Vector3(0, 3.0, 0)
	player.velocity = Vector3.ZERO
	await _frames(1)
	var pressed_at := -1
	var jumped := false
	for i in 120:
		await get_tree().physics_frame
		# ~0.08 s antes de tocar el piso (a ~ -7 m/s recorre ~0.5 m)
		if pressed_at == -1 and player.velocity.y < 0 and player.position.y < 0.55:
			pressed_at = i
			_touch(1, _btn("jump"), true)
			await get_tree().physics_frame
			_touch(1, _btn("jump"), false)
			_check("buffer: tocado en el aire", not player.is_on_floor(), "y=%.2f" % player.position.y)
		if pressed_at != -1 and player.velocity.y > 3.0:
			jumped = true
			break
	_check("input buffering (táctil)", jumped, "salto tras aterrizar=%s" % jumped)
	await _frames(90)

	# 5) Coyote time: caminar fuera del borde (x = 10) y saltar 0.05 s después.
	player.position = Vector3(9.0, 0.1, 0)
	player.velocity = Vector3.ZERO
	await _frames(5)
	_touch(0, start, true)
	_drag(0, start + Vector2(70, 0), Vector2(70, 0))
	var left_floor := false
	var coyote_jump := false
	for i in 90:
		await get_tree().physics_frame
		if not left_floor and not player.is_on_floor() and player.velocity.y <= 0.0:
			left_floor = true
			await _frames(3)  # 3 frames = 0.05 s en el aire
			var was_on_floor: bool = player.is_on_floor()
			_touch(1, _btn("jump"), true)
			await _frames(2)
			_touch(1, _btn("jump"), false)
			coyote_jump = player.velocity.y > 3.0 and not was_on_floor
			break
	_touch(0, start, false)
	_check("coyote time (táctil)", left_floor and coyote_jump, "salió=%s saltó=%s" % [left_floor, coyote_jump])
	await _frames(30)

	# 6) Dash con botón táctil.
	player.position = Vector3(0, 0.1, 0)
	player.velocity = Vector3.ZERO
	await _frames(20)
	_touch(1, _btn("dash"), true)
	await _frames(2)
	var hv := Vector2(player.velocity.x, player.velocity.z).length()
	_touch(1, _btn("dash"), false)
	_check("dash (táctil)", hv > 15.0, "vel. horizontal=%.1f" % hv)
	await _frames(40)

	# 7) Bloqueado (diálogo): los controles se ocultan y no quedan acciones pegadas.
	player.locked = true
	await _frames(2)
	_check("se ocultan en diálogo", not Touch.shown and not Input.is_action_pressed("move_right"))
	player.locked = false
	world.queue_free()
	await _frames(3)


func _screenshot_tutorial() -> void:
	get_tree().change_scene_to_file("res://scenes/tutorial.tscn")
	await _frames(90)
	var screen := get_viewport().get_visible_rect().size
	var start := Vector2(230, screen.y - 210)
	_touch(0, start, true)
	_drag(0, start + Vector2(50, -40), Vector2(50, -40))
	await _frames(30)
	await RenderingServer.frame_post_draw
	get_viewport().get_texture().get_image().save_png(SHOTS + "/tutorial_touch.png")
	_touch(0, start, false)
	await _frames(5)
