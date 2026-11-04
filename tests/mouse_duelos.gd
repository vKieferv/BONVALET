# Mouse simulado para la pantalla de duelos (T-11), como la prueba de T-12: apretar, arrastrar y soltar
# con eventos de verdad (Viewport.push_input), así pasan por CardUI y PantallaDuelos igual que con la mano.
# Lo usan tests/smoke_match.gd (sin pantalla) y tools/partido_duelos_captura.gd (con pantalla).
extends RefCounted

var tree: SceneTree
var mouse := Vector2.ZERO


func _init(p_tree: SceneTree) -> void:
	tree = p_tree


func _boton(p: Vector2, apretado: bool, boton: MouseButton = MOUSE_BUTTON_LEFT) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = p
	ev.global_position = p
	ev.button_index = boton
	ev.pressed = apretado
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if apretado and boton == MOUSE_BUTTON_LEFT else 0
	mouse = p
	tree.root.push_input(ev, true)


func mover(p: Vector2, apretado: bool = true) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = p
	ev.global_position = p
	ev.relative = p - mouse
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if apretado else 0
	mouse = p
	tree.root.push_input(ev, true)


func apretar(p: Vector2) -> void:
	mover(p, false)
	_boton(p, true)


func soltar(p: Vector2) -> void:
	_boton(p, false)


func clic_derecho(p: Vector2) -> void:
	_boton(p, true, MOUSE_BUTTON_RIGHT)
	_boton(p, false, MOUSE_BUTTON_RIGHT)


func cuadros(n: int) -> void:
	for i in n:
		await tree.process_frame


# Aprieta en `desde`, se mueve en `pasos` cuadros hasta `hasta` y se queda ahí apretado (para mirar o
# capturar antes de soltar).
func arrastrar_hasta(desde: Vector2, hasta: Vector2, pasos: int = 6) -> void:
	apretar(desde)
	await cuadros(1)
	for i in pasos:
		mover(desde.lerp(hasta, float(i + 1) / pasos))
		await cuadros(1)


func clic(p: Vector2) -> void:
	apretar(p)
	await cuadros(1)
	soltar(p)
	await cuadros(1)
