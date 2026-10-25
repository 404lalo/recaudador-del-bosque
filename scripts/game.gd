extends Node
## Estado global del juego (autoload "Game"): dinero, protección, nivel actual y datos de animales.

signal money_changed

const ANIMALS_PATH := "res://assets/animals/%s.gltf"

# Protección contra depredadores: nivel -> fracción de dinero que se pierde en un ataque.
const PROT_LOSS := [1.0, 0.6, 0.3, 0.0]
const PROT_NAMES := ["Sin protección", "Silbato de alarma", "Perro guardián", "Escolta armada"]
const PROT_COSTS := [0, 60, 150, 300]  # costo de comprar cada nivel

# Los modelos son PLACEHOLDERS con los animales disponibles en el pack.
# Para cambiar el modelo de una especie solo hay que editar "model" y "scale".
## Cada especie usa un modelo del pack de animales (assets/animals). El nombre que se muestra
## corresponde al modelo: Fox=Zorro, ShibaInu=Shiba, Husky, Deer=Venado, Stag=Ciervo, Alpaca,
## Donkey=Burro, Bull=Toro, Cow=Vaca, Horse=Caballo, Horse_White=Yegua Blanca (Wolf = depredador).
## Las crías (cervatillo, potro, ternero) usan el modelo del adulto más pequeño.
const SPECIES := {
	"zorro": {
		"name": "Zorro", "model": "Fox", "scale": 1.0, "tax": 40,
		"intro": "Vaya, vaya... un recaudador. Seguro podemos llegar a un 'arreglo', amigo.",
		"excuse": "Verás, mi contador es muy listo y dice que yo no debo nada.",
		"pay_line": "Hm, eres más listo de lo que parecías. Aquí tienes.",
		"fail_line": "El zorro sonríe, desaparece entre los arbustos y te deja una nota: 'Buen intento'.",
	},
	"shiba": {
		"name": "Perrito Shiba", "model": "ShibaInu", "scale": 0.6, "tax": 20,
		"intro": "¡Guau! ¿Un recaudador? Acabo de enterrar todos mis huesos para el invierno...",
		"excuse": "Los huesos están carísimos y el roble de la esquina me cobra renta.",
		"pay_line": "Está bien, está bien. Toma, mis ahorros de la semana.",
		"fail_line": "El shiba se mete a su madriguera moviendo la cola y no vuelve a salir.",
	},
	"husky": {
		"name": "Husky", "model": "Husky", "scale": 0.65, "tax": 30,
		"intro": "¡Auuu! Tengo catorce cachorros y un plato de croquetas. ¿De verdad vienes por impuestos?",
		"excuse": "Entre las croquetas de los pequeños y la renta de la cueva no me sobra nada.",
		"pay_line": "Toma, ¡pero que conste que es por los cachorros!",
		"fail_line": "El husky aúlla tan fuerte que te zumban los oídos, y se va corriendo.",
	},
	"venado": {
		"name": "Venado", "model": "Deer", "scale": 0.85, "tax": 35,
		"intro": "Shhh... el bosque está escuchando. Habla bajito, recaudador.",
		"excuse": "Como hojas y pasto. ¿Desde cuándo eso da ganancias?",
		"pay_line": "Tienes buen ojo. Aquí está mi parte.",
		"fail_line": "El venado salta entre los árboles sin hacer ruido.",
	},
	"cervatillo": {
		"name": "Cervatillo", "model": "Deer", "scale": 0.5, "tax": 25,
		"intro": "¡Hola! Mi mamá dice que no hable con extraños... pero tú pareces simpático.",
		"excuse": "Solo tengo las monedas que me dio mi abuelito.",
		"pay_line": "¡Le atinaste! Toma, pero no le digas a mi mamá.",
		"fail_line": "El cervatillo se esconde detrás de un arbusto, muerto de risa.",
	},
	"ciervo": {
		"name": "Ciervo", "model": "Stag", "scale": 0.8, "tax": 60,
		"intro": "Mis astas son más viejas que tu oficina de impuestos. Habla.",
		"excuse": "Mis astas se caen cada año y hay que reponerlas.",
		"pay_line": "Me ganaste limpiamente. Toma.",
		"fail_line": "El ciervo levanta sus astas, te mira con desdén y se aleja.",
	},
	"ciervo_real": {
		"name": "Ciervo Real", "model": "Stag", "scale": 1.25, "tax": 160,
		"intro": "Soy el guardián de estas tierras. Aquí las preguntas son de verdad.",
		"excuse": "El rey no paga impuestos: el rey los cobra.",
		"pay_line": "Has demostrado sabiduría. Te pago lo justo.",
		"fail_line": "El Ciervo Real baja su cornamenta y te cierra el paso. No pagará.",
	},
	"alpaca": {
		"name": "Alpaca", "model": "Alpaca", "scale": 0.65, "tax": 25,
		"intro": "¡Mmmh! Me acaban de trasquilar y tengo frío. ¿Encima impuestos?",
		"excuse": "Vendí mi lana barata y el viento se llevó la mitad.",
		"pay_line": "Mmmh... toma estas monedas, eran para mi bufanda.",
		"fail_line": "La alpaca te escupe un poquito y se va muy digna.",
	},
	"burro": {
		"name": "Burro", "model": "Donkey", "scale": 0.8, "tax": 45,
		"intro": "Iii-aaah. Dicen que soy terco... a ver quién se cansa primero.",
		"excuse": "Cargo todo el día y nadie me paga horas extra.",
		"pay_line": "Iii-aaah... está bien, no soy tan burro. Toma.",
		"fail_line": "El burro se sienta en medio del camino y no se mueve.",
	},
	"toro": {
		"name": "Toro", "model": "Bull", "scale": 1.15, "tax": 80,
		"intro": "¡BUFFF! ¿Quién osa molestar mi siesta? Mi paciencia es corta y mis cuernos largos.",
		"excuse": "El rojo de tu chaleco me pone de malas. Y pagar también.",
		"pay_line": "¡Bufff! Ganaste esta vez. Toma y déjame dormir.",
		"fail_line": "El toro baja la cabeza y escarba el suelo. Mejor te alejas.",
	},
	"vaca": {
		"name": "Vaca", "model": "Cow", "scale": 0.9, "tax": 50,
		"intro": "Muuu... ¿impuestos? Yo solo como pasto y doy leche, eh.",
		"excuse": "La leche está a precio de garantía, no me alcanza.",
		"pay_line": "Muuu. Bueno, toma, pero no me ordeñes más.",
		"fail_line": "La vaca te ignora y sigue rumiando. Ni te voltea a ver.",
	},
	"ternero": {
		"name": "Ternero", "model": "Cow", "scale": 0.55, "tax": 30,
		"intro": "¡Muu! Estoy aprendiendo a mugir. ¿Tú qué estás aprendiendo?",
		"excuse": "Mi domingo es de puro pasto, no de monedas.",
		"pay_line": "¡Muu! Qué listo eres. Toma mi domingo.",
		"fail_line": "El ternero sale corriendo a esconderse junto a su mamá.",
	},
	"caballo": {
		"name": "Caballo", "model": "Horse", "scale": 0.9, "tax": 70,
		"intro": "¡Hiiii! Corro más rápido que tus cobros. ¿Seguro que quieres intentarlo?",
		"excuse": "Las herraduras nuevas me costaron un ojo de la cara.",
		"pay_line": "Buena carrera mental. Te lo ganaste.",
		"fail_line": "El caballo relincha y se va galopando por el camino.",
	},
	"potro": {
		"name": "Potro", "model": "Horse", "scale": 0.6, "tax": 40,
		"intro": "¡Hiii! Apenas aprendí a galopar y ya me quieren cobrar.",
		"excuse": "Gasté todo en zanahorias. Valió la pena.",
		"pay_line": "¡Hiii! Me ganaste. Toma.",
		"fail_line": "El potro da un brinco y se va trotando feliz.",
	},
	"yegua": {
		"name": "Yegua Blanca", "model": "Horse_White", "scale": 0.9, "tax": 90,
		"intro": "Pocos llegan tan lejos. Demuestra que mereces mi oro.",
		"excuse": "Mi oro está enterrado bajo tres metros de nieve.",
		"pay_line": "Digno. Toma lo que es tuyo.",
		"fail_line": "La yegua blanca se pierde en la niebla como un fantasma.",
	},
	"perro_trineo": {
		"name": "Perro de Trineo", "model": "Husky", "scale": 0.8, "tax": 100,
		"intro": "¡Guau! Acabo de jalar un trineo diez kilómetros. Que sea rápido.",
		"excuse": "Me pagan en croquetas, no en monedas.",
		"pay_line": "¡Guau guau! Tú sí sabes. Toma.",
		"fail_line": "El perro sale corriendo jalando su trineo vacío.",
	},
}

## Niveles en orden. La dificultad sube con:
##   animals      -> más animales que cobrar (nivel más largo)
##   tax_mult     -> impuestos más altos
##   riddle_tier  -> 1 = acertijos de cada especie, 2 = medios, 3 = lógica/matemáticas
##   second_try   -> cuánto paga el animal si aciertas al segundo intento
##   trivia_tier  -> 1 = cultura general básica, 2 = difícil
##   steal        -> fracción del dinero que roba el depredador si fallas (antes de la protección)
##   theme        -> bioma (ver THEMES en level.gd)
const LEVELS := [
	{
		"id": "forest", "name": "Bosque Susurrante", "theme": "forest",
		"animals": ["zorro", "shiba", "venado", "cervatillo", "ciervo"],
		"tax_mult": 1.0, "riddle_tier": 1, "second_try": 0.6, "trivia_tier": 1, "steal": 0.4,
		"predator": "Lobo",
	},
	{
		"id": "desert", "name": "Desierto Ardiente", "theme": "desert",
		"animals": ["burro", "alpaca", "caballo", "potro", "toro"],
		"tax_mult": 1.1, "riddle_tier": 1, "second_try": 0.6, "trivia_tier": 1, "steal": 0.4,
		"predator": "Lobo del Desierto",
	},
	{
		"id": "swamp", "name": "Pantano Brumoso", "theme": "swamp",
		"animals": ["burro", "vaca", "ternero", "zorro", "venado", "cervatillo"],
		"tax_mult": 1.2, "riddle_tier": 2, "second_try": 0.5, "trivia_tier": 1, "steal": 0.45,
		"predator": "Lobo del Pantano",
	},
	{
		"id": "meadow", "name": "Pradera Dorada", "theme": "meadow",
		"animals": ["caballo", "potro", "vaca", "ternero", "burro", "alpaca"],
		"tax_mult": 1.3, "riddle_tier": 2, "second_try": 0.5, "trivia_tier": 2, "steal": 0.5,
		"predator": "Lobo de la Pradera",
	},
	{
		"id": "autumn", "name": "Bosque Otoñal", "theme": "autumn",
		"animals": ["venado", "cervatillo", "ciervo", "zorro", "shiba", "husky", "toro"],
		"tax_mult": 1.4, "riddle_tier": 2, "second_try": 0.45, "trivia_tier": 2, "steal": 0.5,
		"predator": "Lobo Gris",
	},
	{
		"id": "canyon", "name": "Cañón Rojo", "theme": "canyon",
		"animals": ["toro", "burro", "alpaca", "caballo", "zorro", "shiba", "potro"],
		"tax_mult": 1.5, "riddle_tier": 3, "second_try": 0.4, "trivia_tier": 2, "steal": 0.55,
		"predator": "Lobo Rojo",
	},
	{
		"id": "tundra", "name": "Tundra Helada", "theme": "tundra",
		"animals": ["husky", "perro_trineo", "yegua", "ciervo", "ciervo_real", "zorro", "venado", "caballo"],
		"tax_mult": 1.7, "riddle_tier": 3, "second_try": 0.35, "trivia_tier": 2, "steal": 0.6,
		"predator": "Lobo Ártico",
	},
	{
		"id": "summit", "name": "Cumbre del Rey", "theme": "summit",
		"animals": ["ciervo_real", "yegua", "toro", "perro_trineo", "alpaca", "caballo", "ciervo", "vaca"],
		"tax_mult": 2.0, "riddle_tier": 3, "second_try": 0.3, "trivia_tier": 2, "steal": 0.7,
		"predator": "Lobo Alfa",
	},
]

var money := 0
var total_collected := 0
var protection := 0
var level_index := 0
var acorns := 0        # bellotas doradas recogidas en la partida
var coins := 0         # monedas recogidas en la partida
var play_time := 0.0   # segundos jugados dentro de los niveles
var level_time := 0.0  # segundos desde que empezó el nivel actual (para el mapa)
var player_pos := Vector2(0, 6)  # posición (x, z) del jugador, la actualiza level.gd
var tutorial_done := false  # se guarda aparte: sobrevive a Nueva partida

const SETTINGS_PATH := "user://settings.cfg"


func _ready() -> void:
	process_mode = Node.PROCESS_MODE_ALWAYS  # F12 funciona también con el juego en pausa
	_setup_input()
	_load_settings()
	_migrate_old_save()
	# Atajo de desarrollo: godot --path . scenes/level.tscn -- --desert
	if "--desert" in OS.get_cmdline_user_args():
		level_index = 1
	for arg in OS.get_cmdline_user_args():  # godot --path . scenes/level.tscn -- --level=5
		if arg.begins_with("--level="):
			level_index = clampi(int(arg.substr(8)) - 1, 0, LEVELS.size() - 1)


# --- Capturas de pantalla (F12) ---
# Se guardan en Imágenes\4TNature (Windows: C:\Users\<tú>\Pictures\4TNature).

func _input(event: InputEvent) -> void:
	if event is InputEventKey and event.pressed and not event.echo and event.keycode == KEY_F12:
		take_screenshot()


func take_screenshot() -> void:
	var img := get_viewport().get_texture().get_image()  # el cuadro tal cual se ve ahora
	var dir := OS.get_system_dir(OS.SYSTEM_DIR_PICTURES).path_join("4TNature")
	DirAccess.make_dir_recursive_absolute(dir)
	var stamp := Time.get_datetime_string_from_system().replace(":", "-").replace("T", "_")
	var path := dir.path_join("captura_%s_%03d.png" % [stamp, Time.get_ticks_msec() % 1000])
	if img.save_png(path) != OK:
		push_warning("No se pudo guardar la captura en " + path)
		return
	print("Captura guardada: ", path)
	Sfx.play("click", 1.6)
	_screenshot_notice(dir)


func _screenshot_notice(dir: String) -> void:
	var layer := CanvasLayer.new()
	layer.layer = 100
	layer.process_mode = Node.PROCESS_MODE_ALWAYS
	var flash := ColorRect.new()
	flash.color = Color(1, 1, 1, 0.35)
	flash.mouse_filter = Control.MOUSE_FILTER_IGNORE
	flash.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	layer.add_child(flash)
	var lbl := Label.new()
	lbl.text = "Captura guardada en %s" % dir
	lbl.add_theme_font_size_override("font_size", 16)
	lbl.add_theme_color_override("font_outline_color", Color.BLACK)
	lbl.add_theme_constant_override("outline_size", 6)
	lbl.set_anchors_and_offsets_preset(Control.PRESET_BOTTOM_LEFT)
	lbl.position += Vector2(16, -40)
	layer.add_child(lbl)
	get_tree().root.add_child(layer)
	var tw := layer.create_tween()
	tw.tween_property(flash, "color:a", 0.0, 0.25)
	tw.tween_interval(1.5)
	tw.tween_property(lbl, "modulate:a", 0.0, 0.5)
	tw.tween_callback(layer.queue_free)


func reset() -> void:
	money = 0
	total_collected = 0
	protection = 0
	level_index = 0
	acorns = 0
	coins = 0
	play_time = 0.0
	level_time = 0.0
	used_riddles.clear()
	money_changed.emit()


## Estado actual que viaja con cada evento hacia la base de datos.
func snapshot() -> Dictionary:
	return {
		"dinero": money,
		"total_recaudado": total_collected,
		"proteccion": protection,
		"bellotas": acorns,
		"monedas": coins,
		"tiempo_seg": snappedf(play_time, 0.1),
		"nivel_idx": level_index,
		"t_nivel": snappedf(level_time, 0.1),
		"x": snappedf(player_pos.x, 0.01),
		"z": snappedf(player_pos.y, 0.01),
	}


## Sacude la cámara del jugador (0.0 - 1.0). Se puede llamar desde cualquier script.
func shake(amount: float) -> void:
	get_tree().call_group("player", "add_trauma", amount)


func add_money(amount: int) -> void:
	money = max(0, money + amount)
	if amount > 0:
		total_collected += amount
	money_changed.emit()


func next_protection_cost() -> int:
	if protection >= PROT_COSTS.size() - 1:
		return -1
	return PROT_COSTS[protection + 1]


func buy_protection() -> bool:
	var cost := next_protection_cost()
	if cost < 0 or money < cost:
		return false
	money -= cost
	protection += 1
	money_changed.emit()
	return true


## Acertijos por especie: "a" es la respuesta correcta, "wrong" las incorrectas.
const RIDDLES := {
	"shiba": [
		{"q": "Tengo hojas pero no soy un árbol, tengo lomo pero no soy un animal. ¿Qué soy?",
			"a": "Un libro", "wrong": ["Una flor", "Un río", "Una piedra"]},
		{"q": "Cuanto más seca, más moja. ¿Qué es?",
			"a": "Una toalla", "wrong": ["Una esponja", "La lluvia", "Una nube"]},
	],
	"alpaca": [
		{"q": "Vuelo sin alas y lloro sin ojos. ¿Qué soy?",
			"a": "Una nube", "wrong": ["Una hoja", "Un fantasma", "Una mariposa"]},
		{"q": "Tengo ciudades sin casas, montañas sin árboles y agua sin peces. ¿Qué soy?",
			"a": "Un mapa", "wrong": ["Un sueño", "Un cuadro", "Un globo terráqueo roto"]},
	],
	"zorro": [
		{"q": "Cuanto más grande es, menos se ve. ¿Qué es?",
			"a": "La oscuridad", "wrong": ["Un elefante", "La niebla", "El silencio"]},
		{"q": "Siempre está delante de ti, pero nunca puedes verlo. ¿Qué es?",
			"a": "El futuro", "wrong": ["El horizonte", "Tu sombra", "El aire"]},
	],
	"cervatillo": [
		{"q": "Blanca por dentro, verde por fuera; si quieres que te lo diga, espera. ¿Qué es?",
			"a": "La pera", "wrong": ["La lechuga", "La zanahoria", "El pepino"]},
		{"q": "Tengo cuatro patas y no camino, tengo respaldo y no hablo. ¿Qué soy?",
			"a": "Una silla", "wrong": ["Un perro", "Una cama", "Un caballo de juguete"]},
	],
	"toro": [
		{"q": "Oro parece, plata no es. ¿Qué es?",
			"a": "El plátano", "wrong": ["La miel", "El limón", "El maíz"]},
		{"q": "¿Qué cosa sube y baja, pero siempre se queda en el mismo sitio?",
			"a": "Una escalera", "wrong": ["Un ascensor roto", "Una montaña", "El sol"]},
	],
	"burro": [
		{"q": "Tengo agujas pero no pincho, doy la hora sin ser el sol. ¿Qué soy?",
			"a": "Un reloj", "wrong": ["Un cactus", "Un erizo", "Un calendario"]},
		{"q": "Si me nombras, me rompo. ¿Qué soy?",
			"a": "El silencio", "wrong": ["El cristal", "El eco", "La promesa"]},
	],
	"caballo": [
		{"q": "Tiene corona pero no es rey, tiene escamas pero no es pez. ¿Qué es?",
			"a": "La piña", "wrong": ["El dragón", "El cocodrilo", "La palma"]},
		{"q": "¿Qué camina a cuatro patas por la mañana, a dos al mediodía y a tres por la tarde?",
			"a": "El ser humano", "wrong": ["El camello", "El lagarto", "El buitre"]},
	],
	"venado": [
		{"q": "Redondo como la luna, blanco como la cal, me hacen de leche pura y ya no te digo más. ¿Qué es?",
			"a": "El queso", "wrong": ["El huevo", "La tortilla", "El pan"]},
		{"q": "Agua pasa por mi casa, cate de mi corazón. ¿Qué es?",
			"a": "El aguacate", "wrong": ["El mango", "El limón", "La pera"]},
	],
	"potro": [
		{"q": "Vuelo de noche, duermo de día y nunca verás plumas en el ala mía. ¿Quién soy?",
			"a": "El murciélago", "wrong": ["El búho", "La lechuza", "La mariposa"]},
		{"q": "Lana sube, lana baja. ¿Qué es?",
			"a": "La navaja", "wrong": ["La oveja", "La tejedora", "El ascensor"]},
	],
	"ciervo": [
		{"q": "Cuanto más me quitas, más grande soy. ¿Qué soy?",
			"a": "Un agujero", "wrong": ["Una deuda", "Un pastel", "Una duna"]},
		{"q": "Es tuyo, pero los demás lo usan más que tú. ¿Qué es?",
			"a": "Tu nombre", "wrong": ["Tu dinero", "Tu casa", "Tu sombrero"]},
	],
}


## Acertijos de dificultad media (nivel 2) y alta (nivel 3), para los niveles avanzados.
const RIDDLES_TIER := {
	2: [
		{"q": "Tiene dientes pero no muerde. ¿Qué es?", "a": "Un peine", "wrong": ["Un cuchillo", "Una piedra", "Un caracol"]},
		{"q": "Tiene ojos y no ve, tiene agua y no la bebe. ¿Qué es?", "a": "El coco", "wrong": ["La sandía", "El pozo", "La nube"]},
		{"q": "Vuela sin alas, silba sin boca y no lo puedes ver. ¿Qué es?", "a": "El viento", "wrong": ["El pájaro", "El trueno", "La flecha"]},
		{"q": "Una cajita blanca como la cal: todos la saben abrir, nadie la sabe cerrar. ¿Qué es?", "a": "El huevo", "wrong": ["La nuez", "El cofre", "La concha"]},
		{"q": "Tiene cuello y no cabeza, tiene brazos y no manos. ¿Qué es?", "a": "La camisa", "wrong": ["La botella", "El árbol", "La guitarra"]},
		{"q": "Se pone en la mesa, se parte y se reparte, pero no se come. ¿Qué es?", "a": "La baraja", "wrong": ["El pan", "El pastel", "El queso"]},
		{"q": "Si me tienes, quieres compartirme; si me compartes, ya no me tienes. ¿Qué soy?", "a": "Un secreto", "wrong": ["Un regalo", "El dinero", "Un abrazo"]},
		{"q": "Tiene teclas pero no abre puertas. ¿Qué es?", "a": "El piano", "wrong": ["El candado", "El cerrajero", "La guitarra"]},
		{"q": "Sube llena y baja vacía. ¿Qué es?", "a": "La cuchara", "wrong": ["La escalera", "El ascensor", "El globo"]},
		{"q": "Lo puedes atrapar, pero no lo puedes lanzar. ¿Qué es?", "a": "Un resfriado", "wrong": ["Una pelota", "Una piedra", "Un pez"]},
		{"q": "Pasa por el agua y nunca se moja. ¿Qué es?", "a": "La sombra", "wrong": ["El pez", "La esponja", "El nadador"]},
		{"q": "Tiene un solo ojo y no puede ver. ¿Qué es?", "a": "La aguja", "wrong": ["El cíclope", "El pirata", "La cámara"]},
		{"q": "Lleva su casa a cuestas y deja un camino brillante. ¿Quién es?", "a": "El caracol", "wrong": ["La tortuga", "El cangrejo", "La hormiga"]},
		{"q": "Entra seca, sale mojada, y cuanto más tiempo se queda, más fuerte se pone. ¿Qué es?", "a": "La bolsita de té", "wrong": ["La esponja", "El pan", "La ropa"]},
		{"q": "Siempre sube y nunca baja. ¿Qué es?", "a": "La edad", "wrong": ["El humo", "El cohete", "La marea"]},
		{"q": "Tiene cuatro patas y no camina; tiene plumas y no vuela. ¿Qué es?", "a": "La cama", "wrong": ["El gallo", "La silla", "El pato"]},
	],
	3: [
		{"q": "Un granjero tiene 17 ovejas. Todas menos 9 se escapan. ¿Cuántas le quedan?", "a": "9", "wrong": ["8", "17", "0"]},
		{"q": "Si 3 gatos cazan 3 ratones en 3 minutos, ¿cuántos gatos cazan 100 ratones en 100 minutos?", "a": "3", "wrong": ["100", "33", "300"]},
		{"q": "El papá de María tiene 5 hijas: Lala, Lele, Lili y Lolo. ¿Cómo se llama la quinta?", "a": "María", "wrong": ["Lulu", "Lala", "No se puede saber"]},
		{"q": "Un bate y una pelota cuestan $110. El bate cuesta $100 más que la pelota. ¿Cuánto cuesta la pelota?", "a": "$5", "wrong": ["$10", "$0", "$55"]},
		{"q": "¿Qué pesa más: un kilo de plumas o un kilo de piedras?", "a": "Pesan lo mismo", "wrong": ["Las piedras", "Las plumas", "Depende del viento"]},
		{"q": "En una carrera rebasas al que va en segundo lugar. ¿En qué lugar vas ahora?", "a": "Segundo", "wrong": ["Primero", "Tercero", "Último"]},
		{"q": "¿Cuántos meses del año tienen 28 días?", "a": "Los 12", "wrong": ["1", "2", "Depende del año"]},
		{"q": "Un ladrillo pesa 1 kg más medio ladrillo. ¿Cuánto pesa el ladrillo?", "a": "2 kg", "wrong": ["1.5 kg", "1 kg", "3 kg"]},
		{"q": "¿Qué número sigue? 2, 6, 12, 20, 30, ...", "a": "42", "wrong": ["40", "36", "44"]},
		{"q": "Entras a un cuarto oscuro con un cerillo. Hay una vela, una lámpara de aceite y una chimenea. ¿Qué enciendes primero?", "a": "El cerillo", "wrong": ["La vela", "La lámpara", "La chimenea"]},
		{"q": "Un caracol sube un pozo de 10 m: de día sube 3 m y de noche resbala 2 m. ¿En cuántos días sale?", "a": "8", "wrong": ["10", "7", "5"]},
		{"q": "5 máquinas hacen 5 tornillos en 5 minutos. ¿Cuánto tardan 100 máquinas en hacer 100 tornillos?", "a": "5 minutos", "wrong": ["100 minutos", "20 minutos", "1 minuto"]},
		{"q": "Unos lirios duplican su tamaño cada día y cubren el lago en 48 días. ¿En cuántos días cubrían la mitad?", "a": "47", "wrong": ["24", "46", "36"]},
		{"q": "¿Qué número sigue? 1, 1, 2, 3, 5, 8, ...", "a": "13", "wrong": ["11", "12", "16"]},
		{"q": "Hay 3 manzanas y tú tomas 2. ¿Cuántas manzanas tienes tú?", "a": "2", "wrong": ["1", "3", "0"]},
		{"q": "Te dan 3 pastillas y debes tomar una cada media hora. ¿Cuánto tardas en tomarlas todas?", "a": "1 hora", "wrong": ["1 hora y media", "2 horas", "30 minutos"]},
		{"q": "Antes de descubrirse el Everest, ¿cuál era la montaña más alta del mundo?", "a": "El Everest", "wrong": ["El K2", "El Kilimanjaro", "El Aconcagua"]},
		{"q": "¿Qué número sigue? 3, 9, 27, 81, ...", "a": "243", "wrong": ["162", "108", "324"]},
		{"q": "Un tren eléctrico va al norte y el viento sopla al sur. ¿Hacia dónde va el humo?", "a": "No echa humo", "wrong": ["Al sur", "Al norte", "Hacia arriba"]},
	],
}

var used_riddles: Array = []  # preguntas ya usadas en la partida (para no repetir)


## Devuelve un acertijo con las opciones ya mezcladas: {q, options: Array[String], correct: int}
## tier 1 = acertijos propios de la especie; 2 y 3 = acertijos generales más difíciles.
func pick_riddle(species_id: String, tier := 1) -> Dictionary:
	var list: Array = RIDDLES.get(species_id, []) if tier <= 1 else RIDDLES_TIER.get(tier, [])
	if list.is_empty():
		list = RIDDLES_TIER[2]
	return _pick_unused(list)


func _pick_unused(list: Array) -> Dictionary:
	var fresh := list.filter(func(r): return not used_riddles.has(r.q))
	if fresh.is_empty():
		fresh = list
	var r: Dictionary = fresh[randi() % fresh.size()]
	used_riddles.append(r.q)
	var options: Array = r.wrong.duplicate()
	options.append(r.a)
	options.shuffle()
	return {"q": r.q, "options": options, "correct": options.find(r.a)}


## Datos de dificultad del nivel actual (con valores por defecto).
func level_setting(key: String, default_value):
	return LEVELS[level_index].get(key, default_value)


## Preguntas de cultura general del depredador: "a" correcta, "wrong" incorrectas.
const TRIVIA := [
	{"q": "¿Cuál es la capital de Francia?", "a": "París", "wrong": ["Lyon", "Roma", "Madrid"]},
	{"q": "¿Cuántos planetas tiene el Sistema Solar?", "a": "8", "wrong": ["7", "9", "10"]},
	{"q": "¿Quién pintó la Mona Lisa?", "a": "Leonardo da Vinci", "wrong": ["Pablo Picasso", "Van Gogh", "Miguel Ángel"]},
	{"q": "¿Cuál es el océano más grande del mundo?", "a": "Pacífico", "wrong": ["Atlántico", "Índico", "Ártico"]},
	{"q": "¿Cuál es el elemento químico con símbolo O?", "a": "Oxígeno", "wrong": ["Oro", "Osmio", "Ozono"]},
	{"q": "¿En qué continente está Egipto?", "a": "África", "wrong": ["Asia", "Europa", "Oceanía"]},
	{"q": "¿Quién escribió 'Don Quijote de la Mancha'?", "a": "Miguel de Cervantes", "wrong": ["Lope de Vega", "Gabriel García Márquez", "Quevedo"]},
	{"q": "¿Cuántos lados tiene un hexágono?", "a": "6", "wrong": ["5", "7", "8"]},
	{"q": "¿Cuál es el animal terrestre más grande?", "a": "El elefante africano", "wrong": ["La jirafa", "El rinoceronte", "El oso polar"]},
	{"q": "¿En qué año llegó el ser humano a la Luna?", "a": "1969", "wrong": ["1959", "1975", "1981"]},
	{"q": "¿Cuál es el río más largo de Sudamérica?", "a": "El Amazonas", "wrong": ["El Orinoco", "El Paraná", "El Magdalena"]},
	{"q": "¿Qué gas necesitan las plantas para la fotosíntesis?", "a": "Dióxido de carbono", "wrong": ["Oxígeno", "Nitrógeno", "Helio"]},
	{"q": "¿Cuántos huesos tiene aproximadamente un adulto?", "a": "206", "wrong": ["106", "306", "412"]},
	{"q": "¿Cuál es el país más grande del mundo por superficie?", "a": "Rusia", "wrong": ["China", "Canadá", "Estados Unidos"]},
]

## Cultura general difícil (niveles con trivia_tier 2).
const TRIVIA_HARD := [
	{"q": "¿Cuál es el planeta más grande del Sistema Solar?", "a": "Júpiter", "wrong": ["Saturno", "Neptuno", "La Tierra"]},
	{"q": "¿Cuál es el hueso más largo del cuerpo humano?", "a": "El fémur", "wrong": ["La tibia", "El húmero", "El radio"]},
	{"q": "¿Quién formuló la teoría de la relatividad?", "a": "Albert Einstein", "wrong": ["Isaac Newton", "Galileo Galilei", "Nikola Tesla"]},
	{"q": "¿Cuál es el metal más abundante en la corteza terrestre?", "a": "El aluminio", "wrong": ["El hierro", "El cobre", "El oro"]},
	{"q": "¿En qué año cayó el Muro de Berlín?", "a": "1989", "wrong": ["1991", "1985", "1979"]},
	{"q": "¿Cuál es la capital de Australia?", "a": "Canberra", "wrong": ["Sídney", "Melbourne", "Perth"]},
	{"q": "¿Cuántos corazones tiene un pulpo?", "a": "3", "wrong": ["1", "2", "8"]},
	{"q": "¿Qué gas es el más abundante en la atmósfera de la Tierra?", "a": "Nitrógeno", "wrong": ["Oxígeno", "Dióxido de carbono", "Argón"]},
	{"q": "¿Cuál es el río más largo de África?", "a": "El Nilo", "wrong": ["El Congo", "El Níger", "El Zambeze"]},
	{"q": "¿Quién propuso la ley de la gravitación universal?", "a": "Isaac Newton", "wrong": ["Nicolás Copérnico", "Johannes Kepler", "Charles Darwin"]},
	{"q": "¿En qué país está Machu Picchu?", "a": "Perú", "wrong": ["Bolivia", "Chile", "Ecuador"]},
	{"q": "¿Cuál es el número primo más pequeño?", "a": "2", "wrong": ["1", "3", "0"]},
	{"q": "¿Quién pintó 'La noche estrellada'?", "a": "Vincent van Gogh", "wrong": ["Claude Monet", "Salvador Dalí", "Frida Kahlo"]},
	{"q": "¿Cuál es el símbolo químico del oro?", "a": "Au", "wrong": ["Ag", "Or", "Go"]},
	{"q": "¿Cuántos lados tiene un dodecágono?", "a": "12", "wrong": ["10", "11", "20"]},
]

const PREDATOR_TAUNTS := [
	"¡JA JA JA! ¿Eso es todo lo que sabes? ¡Hasta un cachorro lo sabría!",
	"Qué pena... y yo que pensaba que los recaudadores eran listos.",
	"¡Incorrecto! Gracias por la donación, 'sabio'.",
	"Con esa cabeza no me extraña que cobres impuestos a ardillas.",
]
const PREDATOR_DEFEATS := [
	"Grrr... tuviste suerte, recaudador. La próxima vez no te escapas.",
	"¡Maldición! Alguien leyó un libro por una vez.",
	"Bah, pregunta fácil. Me voy a buscar presas más tontas.",
]


## Pregunta de cultura general con opciones mezcladas: {q, options, correct}
## tier 1 = básica, 2 = difícil. Si no se indica, usa la del nivel actual.
func pick_trivia(tier := -1) -> Dictionary:
	if tier < 1:
		tier = int(level_setting("trivia_tier", 1))
	return _pick_unused(TRIVIA_HARD if tier >= 2 else TRIVIA)


func _setup_input() -> void:
	var map := {
		"move_forward": [KEY_W, KEY_UP],
		"move_back": [KEY_S, KEY_DOWN],
		"move_left": [KEY_A, KEY_LEFT],
		"move_right": [KEY_D, KEY_RIGHT],
		"sprint": [KEY_SHIFT],
		"interact": [KEY_E],
		"jump": [KEY_SPACE],
		"pause": [KEY_P],
	}
	for action in map:
		if not InputMap.has_action(action):
			InputMap.add_action(action)
		for k in map[action]:
			var ev := InputEventKey.new()
			ev.physical_keycode = k
			InputMap.action_add_event(action, ev)


# ---------------------------------------------------------------- guardado (ranuras)

## Hay MAX_SLOTS ranuras de partida, cada una con su propio progreso (y su propio jugador).
## La ranura se escribe al iniciar cada zona (checkpoint) y al terminar el recorrido queda
## marcada como "completada".
const MAX_SLOTS := 3
const SAVE_PATH_FMT := "user://save_slot_%d.json"
const OLD_SAVE_PATH := "user://save.json"  # versión anterior (una sola partida)

var slot := 1                    # ranura en uso
var open_slots_on_menu := false  # el menú abre la lista de partidas al cargar


func save_path(s := -1) -> String:
	return SAVE_PATH_FMT % (slot if s < 1 else s)


func has_save(s := -1) -> bool:
	return FileAccess.file_exists(save_path(s))


func save_game(completed := false) -> void:
	var data := {
		"version": 2,
		"slot": slot,
		"level_index": level_index,
		"level_name": LEVELS[level_index].name,
		"money": money,
		"total_collected": total_collected,
		"protection": protection,
		"acorns": acorns,
		"coins": coins,
		"play_time": play_time,
		"session_id": Api.session_id,
		"player": Api.player_name,
		"completed": completed,
		"updated": Time.get_unix_time_from_system(),
	}
	_write_save(slot, data)


## Al salir al menú a media zona: solo actualiza el tiempo jugado y la fecha.
func update_save_time() -> void:
	var d := peek_save()
	if d.is_empty():
		return
	d["play_time"] = play_time
	d["updated"] = Time.get_unix_time_from_system()
	_write_save(slot, d)


func _write_save(s: int, data: Dictionary) -> void:
	var f := FileAccess.open(save_path(s), FileAccess.WRITE)
	if f == null:
		push_warning("No se pudo guardar la partida: %s" % FileAccess.get_open_error())
		return
	f.store_string(JSON.stringify(data, "\t"))


## Lee una ranura sin aplicarla (para mostrarla en el menú). {} si está vacía o corrupta.
func peek_save(s := -1) -> Dictionary:
	if not has_save(s):
		return {}
	var parsed = JSON.parse_string(FileAccess.get_file_as_string(save_path(s)))
	return parsed if typeof(parsed) == TYPE_DICTIONARY else {}


## Carga una ranura y la deja como la ranura en uso. No carga recorridos ya completados.
func load_game(s := -1) -> bool:
	var d := peek_save(s)
	if d.is_empty() or bool(d.get("completed", false)):
		return false
	if s >= 1:
		slot = s
	level_index = clampi(int(d.get("level_index", 0)), 0, LEVELS.size() - 1)
	money = maxi(0, int(d.get("money", 0)))
	total_collected = maxi(0, int(d.get("total_collected", 0)))
	protection = clampi(int(d.get("protection", 0)), 0, PROT_COSTS.size() - 1)
	acorns = maxi(0, int(d.get("acorns", 0)))
	coins = maxi(0, int(d.get("coins", 0)))
	play_time = maxf(0.0, float(d.get("play_time", 0.0)))
	Api.resume(str(d.get("session_id", "")), str(d.get("player", "")))
	money_changed.emit()
	return true


func delete_save(s := -1) -> void:
	if has_save(s):
		DirAccess.remove_absolute(save_path(s))


## La ranura en curso jugada más recientemente (0 si no hay ninguna).
func last_slot() -> int:
	var best := 0
	var best_t := -1.0
	for s in range(1, MAX_SLOTS + 1):
		var d := peek_save(s)
		if d.is_empty() or bool(d.get("completed", false)):
			continue
		var t := float(d.get("updated", 0.0))
		if t > best_t:
			best_t = t
			best = s
	return best


## Primera ranura vacía (0 si están todas ocupadas).
func free_slot() -> int:
	for s in range(1, MAX_SLOTS + 1):
		if not has_save(s):
			return s
	return 0


## Si existe el guardado de la versión anterior, lo pasa a la ranura 1.
func _migrate_old_save() -> void:
	if FileAccess.file_exists(OLD_SAVE_PATH) and not has_save(1):
		DirAccess.rename_absolute(ProjectSettings.globalize_path(OLD_SAVE_PATH),
			ProjectSettings.globalize_path(save_path(1)))


func mark_tutorial_done() -> void:
	tutorial_done = true
	var cfg := ConfigFile.new()
	cfg.load(SETTINGS_PATH)
	cfg.set_value("progress", "tutorial_done", true)
	cfg.save(SETTINGS_PATH)


func _load_settings() -> void:
	var cfg := ConfigFile.new()
	if cfg.load(SETTINGS_PATH) == OK:
		tutorial_done = bool(cfg.get_value("progress", "tutorial_done", false))
