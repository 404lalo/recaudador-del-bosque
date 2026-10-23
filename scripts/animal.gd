extends Node3D
## Animal que vive en una madriguera. Carga el modelo de la especie y reproduce animaciones.

var species: Dictionary
var tax := 0
var done := false
var model: Node3D
var anim: AnimationPlayer
var tag: Label3D


func setup(sp: Dictionary, tax_amount: int) -> void:
	species = sp
	tax = tax_amount
	model = (load(Game.ANIMALS_PATH % sp.model) as PackedScene).instantiate()
	model.scale = Vector3.ONE * sp.scale
	add_child(model)
	anim = _find_anim(model)
	play("Idle")
	tag = Label3D.new()
	tag.text = sp.name
	tag.font_size = 48
	tag.pixel_size = 0.008
	tag.outline_size = 12
	tag.billboard = BaseMaterial3D.BILLBOARD_ENABLED
	tag.no_depth_test = true
	tag.position = Vector3(0, 2.0 * max(sp.scale, 0.8), 0)
	add_child(tag)


func face(target: Vector3) -> void:
	var d := target - global_position
	rotation.y = atan2(d.x, d.z)


func play(name: String, loop := true) -> void:
	if anim == null or not anim.has_animation(name):
		return
	anim.get_animation(name).loop_mode = Animation.LOOP_LINEAR if loop else Animation.LOOP_NONE
	anim.play(name)


func mark_done(paid: bool) -> void:
	done = true
	tag.text = "%s ✔" % species.name if paid else "%s ✘" % species.name
	tag.modulate = Color(0.6, 1, 0.6) if paid else Color(1, 0.6, 0.6)
	play("Eating" if paid else "Attack")


func _find_anim(n: Node) -> AnimationPlayer:
	if n is AnimationPlayer:
		return n
	for c in n.get_children():
		var r := _find_anim(c)
		if r:
			return r
	return null
