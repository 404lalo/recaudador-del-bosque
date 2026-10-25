extends CharacterBody3D
## Recaudador en tercera persona. WASD mueve, ratón gira la cámara, Shift corre.

const WALK_SPEED := 6.0
const SPRINT_SPEED := 10.0
const JUMP_VELOCITY := 8.5
const DOUBLE_JUMP_VELOCITY := 7.5
const GRAVITY := 20.0
const COYOTE_TIME := 0.12
const JUMP_BUFFER := 0.12
const MOUSE_SENS := 0.003
const CAM_DISTANCE := 5.5
const PITCH_MIN := -1.2   # mirando hacia abajo
const PITCH_MAX := 0.35   # mirando hacia arriba
# Screenshake: "trauma" de 0 a 1 que se va desvaneciendo; la vibración es trauma².
const SHAKE_DECAY := 1.1       # cuánto trauma se pierde por segundo
const SHAKE_MAX_OFFSET := 0.9  # desplazamiento máximo de la cámara (metros)
const SHAKE_MAX_ROLL := 0.12   # inclinación máxima (radianes)
const HARD_LANDING := 10.0     # velocidad de caída a partir de la cual el aterrizaje sacude

var locked := false:
	set(v):
		locked = v
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE if v else Input.MOUSE_MODE_CAPTURED

var yaw := 0.0
var pitch := -0.25
var pivot: Node3D
var camera: Camera3D
var spring: SpringArm3D
var body_pivot: Node3D
var coyote := 0.0
var jump_buffer := 0.0
var air_jumps := 1
var was_on_floor := true
var step_timer := 0.0
var fall_speed := 0.0
var trauma := 0.0
var shake_time := 0.0
var noise := FastNoiseLite.new()


func _ready() -> void:
	add_to_group("player")
	noise.seed = randi()
	noise.frequency = 2.0
	_build_body()
	pivot = Node3D.new()
	pivot.position = Vector3(0, 1.6, 0)
	add_child(pivot)
	# Brazo con colisión: si entre el jugador y la cámara hay suelo, un árbol o una plataforma,
	# la cámara se acerca en vez de atravesarlo.
	spring = SpringArm3D.new()
	spring.spring_length = CAM_DISTANCE
	spring.margin = 0.2
	var probe := SphereShape3D.new()
	probe.radius = 0.25
	spring.shape = probe
	spring.add_excluded_object(get_rid())
	pivot.add_child(spring)
	camera = Camera3D.new()
	camera.current = true
	spring.add_child(camera)
	var shape := CollisionShape3D.new()
	var cap := CapsuleShape3D.new()
	cap.radius = 0.4
	cap.height = 1.8
	shape.shape = cap
	shape.position.y = 0.9
	add_child(shape)
	Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _build_body() -> void:
	body_pivot = Node3D.new()
	add_child(body_pivot)
	var coat := _mat(Color(0.15, 0.25, 0.55))
	var skin := _mat(Color(0.95, 0.8, 0.65))
	var hat := _mat(Color(0.08, 0.08, 0.1))
	var gold := _mat(Color(0.95, 0.75, 0.15))
	_mesh(CapsuleMesh.new(), coat, Vector3(0, 0.85, 0), Vector3(0.4, 0.8, 0.4))
	_mesh(SphereMesh.new(), skin, Vector3(0, 1.75, 0), Vector3(0.5, 0.5, 0.5))
	var brim := CylinderMesh.new()
	brim.top_radius = 0.38
	brim.bottom_radius = 0.38
	brim.height = 0.05
	_mesh(brim, hat, Vector3(0, 1.95, 0))
	var top := CylinderMesh.new()
	top.top_radius = 0.22
	top.bottom_radius = 0.22
	top.height = 0.35
	_mesh(top, hat, Vector3(0, 2.15, 0))
	var bag := SphereMesh.new()
	_mesh(bag, gold, Vector3(0.45, 0.9, 0.1), Vector3(0.3, 0.3, 0.3))


func _mat(c: Color) -> StandardMaterial3D:
	var m := StandardMaterial3D.new()
	m.albedo_color = c
	return m


func _mesh(mesh: Mesh, mat: Material, pos: Vector3, scl := Vector3.ONE) -> void:
	var mi := MeshInstance3D.new()
	mi.mesh = mesh
	mi.material_override = mat
	mi.position = pos
	mi.scale = scl
	body_pivot.add_child(mi)


func _unhandled_input(event: InputEvent) -> void:
	if locked:
		return
	if event is InputEventMouseMotion and Input.mouse_mode == Input.MOUSE_MODE_CAPTURED:
		yaw -= event.relative.x * MOUSE_SENS
		pitch = clamp(pitch - event.relative.y * MOUSE_SENS, PITCH_MIN, PITCH_MAX)
	elif event is InputEventKey and event.pressed and event.keycode == KEY_ESCAPE:
		Input.mouse_mode = Input.MOUSE_MODE_VISIBLE
	elif event is InputEventMouseButton and event.pressed:
		Input.mouse_mode = Input.MOUSE_MODE_CAPTURED


func _physics_process(delta: float) -> void:
	pivot.rotation = Vector3(pitch, yaw, 0)
	var on_floor := is_on_floor()
	if on_floor:
		coyote = COYOTE_TIME
		air_jumps = 1
		if not was_on_floor:
			Sfx.play("land", 1.0, -6.0)
			if fall_speed > HARD_LANDING:  # aterrizaje fuerte
				add_trauma(clampf((fall_speed - HARD_LANDING) / 10.0, 0.4, 0.8))
	else:
		coyote = maxf(0.0, coyote - delta)
		velocity.y -= GRAVITY * delta
		fall_speed = maxf(0.0, -velocity.y)
	jump_buffer = maxf(0.0, jump_buffer - delta)
	var dir := Vector3.ZERO
	if not locked:
		var input := Input.get_vector("move_left", "move_right", "move_forward", "move_back")
		dir = (Basis(Vector3.UP, yaw) * Vector3(input.x, 0, input.y)).normalized()
		if Input.is_action_just_pressed("jump"):
			jump_buffer = JUMP_BUFFER
		if jump_buffer > 0.0:
			if coyote > 0.0:  # salto normal (también justo después de dejar un borde)
				velocity.y = JUMP_VELOCITY
				coyote = 0.0
				jump_buffer = 0.0
				Sfx.play_varied("jump")
			elif air_jumps > 0:  # doble salto
				velocity.y = DOUBLE_JUMP_VELOCITY
				air_jumps -= 1
				jump_buffer = 0.0
				Sfx.play_varied("djump")
		# Salto variable: soltar la tecla recorta el salto.
		if Input.is_action_just_released("jump") and velocity.y > 3.0:
			velocity.y *= 0.55
	var speed := SPRINT_SPEED if Input.is_action_pressed("sprint") else WALK_SPEED
	velocity.x = dir.x * speed
	velocity.z = dir.z * speed
	if dir.length() > 0.1:
		body_pivot.rotation.y = lerp_angle(body_pivot.rotation.y, atan2(-dir.x, -dir.z) + PI, 12.0 * delta)
		if on_floor:
			step_timer -= delta
			if step_timer <= 0.0:
				Sfx.play_varied("step", -8.0)
				step_timer = 0.28 if speed == WALK_SPEED else 0.19
	else:
		step_timer = 0.0
	# Pequeño balanceo al caminar y estirarse al saltar.
	var bob := 1.0 + (0.04 * sin(Time.get_ticks_msec() * 0.018) if dir.length() > 0.1 and on_floor else 0.0)
	var stretch := clampf(1.0 + absf(velocity.y) * 0.012, 1.0, 1.15)
	body_pivot.scale = Vector3(1.0 / sqrt(stretch), stretch * bob, 1.0 / sqrt(stretch))
	was_on_floor = on_floor
	move_and_slide()


## Agrega vibración de cámara (0.0 - 1.0). Se suma y se desvanece sola.
func add_trauma(amount: float) -> void:
	trauma = clampf(trauma + amount, 0.0, 1.0)


func _process(delta: float) -> void:
	if trauma <= 0.0:
		return
	trauma = maxf(0.0, trauma - SHAKE_DECAY * delta)
	shake_time += delta * 30.0
	var k := pow(trauma, 1.5)
	camera.h_offset = SHAKE_MAX_OFFSET * k * noise.get_noise_2d(shake_time, 0.0)
	camera.v_offset = SHAKE_MAX_OFFSET * k * noise.get_noise_2d(0.0, shake_time)
	camera.rotation.z = SHAKE_MAX_ROLL * k * noise.get_noise_2d(shake_time, shake_time)
	if trauma == 0.0:
		camera.h_offset = 0.0
		camera.v_offset = 0.0
		camera.rotation.z = 0.0
