# T-12: prueba la escena 3D con eventos de mouse simulados (Input.parse_input_event): arrastra una lámina de
# pase sobre los 4 receptores, suelta fuera, vuelve a Aceval y comprueba portador, láminas, flecha y que
# nada se tape. Guarda capturas de cada caso y mide los cuadros por segundo de pases seguidos.
# Necesita pantalla: NO se corre con --headless. Sale con código 1 si algo falla.
# Uso (desde futbolista/):
#   ..\Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1280x720 -s res://tools/prueba_3d_captura.gd -- --out=C:/ruta/capturas
# Para Compatibility: agrega --rendering-method gl_compatibility antes de -s. Más opciones (después de --):
#   --sufijo=texto      se agrega al nombre de las capturas
#   --extras=13         jugadores de más (22 en total), para ver cómo cae el rendimiento
#   --sin-sombras       apaga las sombras del sol
#   --msaa=0            0, 2 o 4 (por defecto, el de la escena: 4x)
#   --solo-pruebas      no mide
#   --solo-medir        no prueba ni captura
extends SceneTree

const ESCENA := "res://scenes/prueba_3d/prueba_3d.tscn"
const CALENTAR_S := 3.0
const MEDIR_S := 10.0
const RECEPTORES := ["VIDAL", "SÁNCHEZ", "FERNÁNDEZ", "MELÉNDEZ"]
# Lo que debe decir la lámina de Pase corto desde Aceval (tabla de "Pase con marcas" en docs/cartas.md).
const PCT_ACEVAL := {"VIDAL": "57%", "SÁNCHEZ": "45%", "FERNÁNDEZ": "29%", "MELÉNDEZ": "57%"}
const TONO_ACEVAL := {"VIDAL": "dorado", "SÁNCHEZ": "dorado", "FERNÁNDEZ": "coral", "MELÉNDEZ": "dorado"}

var out := "user://capturas_t12"
var sufijo := ""
var extras := 0
var sin_sombras := false
var msaa := -1
var solo_pruebas := false
var solo_medir := false
var view: Control
var fallas := 0
var _peor_inicio := 0
var _prev := 0
var _midiendo := false
var _tiempos: Array[int] = []
var _gpu := 0.0
var _gpu_n := 0
var _vista_rid := RID()


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.get_slice("=", 1)
		elif arg.begins_with("--sufijo="):
			sufijo = "_" + arg.get_slice("=", 1)
		elif arg.begins_with("--extras="):
			extras = arg.get_slice("=", 1).to_int()
		elif arg == "--sin-sombras":
			sin_sombras = true
		elif arg.begins_with("--msaa="):
			msaa = arg.get_slice("=", 1).to_int()
		elif arg == "--solo-pruebas":
			solo_pruebas = true
		elif arg == "--solo-medir":
			solo_medir = true
	DirAccess.make_dir_recursive_absolute(out)
	# Sin tope: se mide lo que la máquina alcanza, no la frecuencia del monitor.
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	change_scene_to_file(ESCENA)
	_correr()


func _process(_delta: float) -> bool:
	var ahora := Time.get_ticks_usec()
	if _midiendo:
		_tiempos.append(ahora - _prev)
		var gpu := RenderingServer.viewport_get_measured_render_time_gpu(_vista_rid)
		if gpu > 0.0:
			_gpu += gpu
			_gpu_n += 1
	elif _prev > 0:
		_peor_inicio = maxi(_peor_inicio, ahora - _prev)
	_prev = ahora
	return false


func _correr() -> void:
	await _cuadros(20)
	view = current_scene as Control
	_preparar()
	await _cuadros(30)
	if not solo_medir:
		await _probar()
		print("pruebas: %d fallas" % fallas)
	if not solo_pruebas:
		await _medir()
	quit(1 if fallas > 0 else 0)


func _preparar() -> void:
	var vista: SubViewport = view.get_node("Senal/Vista3D")
	if extras > 0:
		view.agregar_extras(extras)
	if sin_sombras:
		for n in vista.get_children():
			if n is DirectionalLight3D:
				n.shadow_enabled = false
	if msaa == 0:
		vista.msaa_3d = Viewport.MSAA_DISABLED
	elif msaa == 2:
		vista.msaa_3d = Viewport.MSAA_2X
	elif msaa == 4:
		vista.msaa_3d = Viewport.MSAA_4X
	_vista_rid = vista.get_viewport_rid()
	RenderingServer.viewport_set_measure_render_time(_vista_rid, true)


func _cuadros(n: int) -> void:
	for i in n:
		await process_frame


func _segundos(s: float) -> void:
	await create_timer(s).timeout


func _revisa(ok: bool, texto: String) -> void:
	if ok:
		print("  ok: ", texto)
	else:
		fallas += 1
		print("  FALLA: ", texto)


func _sin_tilde(nombre: String) -> String:
	return nombre.to_lower().replace("á", "a").replace("é", "e")


func _shot(nombre: String) -> void:
	var ruta := out.path_join(nombre + sufijo + ".png")
	root.get_texture().get_image().save_png(ruta)
	print("captura: ", ruta)


# ------------------------------------------------------------------ Mouse y teclado simulados

func _a_ventana(p: Vector2) -> Vector2:
	return root.get_final_transform() * p


func _mover_mouse(p: Vector2, boton := true) -> void:
	var ev := InputEventMouseMotion.new()
	ev.position = _a_ventana(p)
	ev.global_position = ev.position
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if boton else 0
	Input.parse_input_event(ev)


func _boton(p: Vector2, apretado: bool) -> void:
	var ev := InputEventMouseButton.new()
	ev.position = _a_ventana(p)
	ev.global_position = ev.position
	ev.button_index = MOUSE_BUTTON_LEFT
	ev.pressed = apretado
	ev.button_mask = MOUSE_BUTTON_MASK_LEFT if apretado else 0
	Input.parse_input_event(ev)


func _tecla(codigo: Key) -> void:
	var ev := InputEventKey.new()
	ev.keycode = codigo
	ev.physical_keycode = codigo
	ev.pressed = true
	Input.parse_input_event(ev)
	var suelta := InputEventKey.new()
	suelta.keycode = codigo
	suelta.physical_keycode = codigo
	suelta.pressed = false
	Input.parse_input_event(suelta)


func _lamina(id: String) -> CardUI:
	for ui: CardUI in view._laminas:
		if ui.card.id == id:
			return ui
	return null


func _centro_lamina(ui: CardUI) -> Vector2:
	return ui.global_position + ui.size * 0.5


func _centro_jugador(nombre: String) -> Vector2:
	return view._rect_cuerpo(view._jugadores[nombre]).get_center()


# Toma la lámina con el mouse y la lleva por el camino hasta `destino`.
func _arrastrar(ui: CardUI, destino: Vector2) -> void:
	var ini := _centro_lamina(ui)
	_mover_mouse(ini, false)
	await _cuadros(4)
	_boton(ini, true)
	await _cuadros(3)
	for i in range(1, 9):
		_mover_mouse(ini.lerp(destino, i / 8.0))
		await _cuadros(2)


func _soltar_mouse(p: Vector2) -> void:
	_boton(p, false)
	await _cuadros(2)
	_mover_mouse(Vector2(640, 300), false)


func _esperar_pase() -> void:
	var limite := Time.get_ticks_msec() + 5000
	await _cuadros(2)
	while view.ocupado() and Time.get_ticks_msec() < limite:
		await process_frame


func _revisar_mano(nombre: String, puesto: String) -> void:
	var todas := true
	for ui: CardUI in view._laminas:
		if not ui.visible:
			continue
		var jug: Dictionary = ui.contexto.get("jugador", {})
		if String(jug.get("role", "")) != puesto or not String(jug.get("name", "")).to_upper().begins_with(nombre.left(3)):
			todas = false
		if ui.seal_label.visible:
			todas = false
	_revisa(todas, "las láminas son de %s (%s) y no tienen sello" % [nombre, puesto])


func _revisar_elige(apuntando: CardUI = null) -> void:
	var bien := true
	for ui: CardUI in view._laminas:
		if not ui.visible or ui.card.kind != Card.Kind.PASS:
			continue
		var debe_elige := ui != apuntando
		if view._elige[ui].visible != debe_elige or ui.chance_label.visible == debe_elige:
			bien = false
	_revisa(bien, "los pases dicen ELIGE y el % aparece solo en la lámina que apunta")


func _revisar_solapes(caso: String) -> void:
	await _segundos(0.5)
	var lista: Array = view.solapes()
	_revisa(lista.is_empty(), "nada se tapa: %s %s" % [caso, str(lista) if not lista.is_empty() else ""])


# ------------------------------------------------------------------ Pruebas

func _probar() -> void:
	_revisar_mano("ACEVAL", "LAT")
	_revisar_elige()
	await _revisar_solapes("al empezar")
	_shot("0_inicio")
	var pase: CardUI = _lamina("pase_corto")

	print("Soltar fuera (pasto vacío):")
	var vacio := Vector2(view._ancho - 90.0, view._alto_senal - 30.0)
	await _arrastrar(pase, vacio)
	_revisa(view.arrastrando(), "arrastrar una lámina de pase muestra la flecha")
	_revisa(view.apuntado() == "" and view.tono_flecha() == "gris", "fuera de un compañero la flecha queda gris")
	await _segundos(0.3)
	_shot("1_arrastre_sin_objetivo")
	await _soltar_mouse(vacio)
	await _cuadros(4)
	_revisa(not view.arrastrando(), "al soltar se apaga la flecha")
	_revisa(view.portador() == "ACEVAL", "soltar fuera no cambia al portador")
	_revisa(pase.visible and not view.ocupado(), "soltar fuera no gasta la lámina ni lanza el pase")
	_revisar_elige()

	print("Soltar sobre un rival y sobre el portador:")
	for nombre: String in ["SALAS", "ACEVAL"]:
		var p := _centro_jugador(nombre)
		await _arrastrar(pase, p)
		_revisa(view.apuntado() == "", "%s no es un objetivo válido" % nombre)
		await _soltar_mouse(p)
		await _cuadros(4)
		_revisa(view.portador() == "ACEVAL" and pase.visible, "soltar sobre %s cancela" % nombre)

	print("Lámina que no es de pase:")
	var amague: CardUI = _lamina("amague")
	await _arrastrar(amague, _centro_jugador("VIDAL"))
	_revisa(not view.arrastrando(), "arrastrar Amague no muestra flecha")
	await _soltar_mouse(_centro_jugador("VIDAL"))
	_revisa(view.portador() == "ACEVAL", "Amague no pasa la pelota")

	for nombre: String in RECEPTORES:
		print("Pase a %s:" % nombre)
		await _probar_receptor(nombre)
		_tecla(KEY_R)
		await _cuadros(4)
		_revisa(view.portador() == "ACEVAL" and _lamina("pase_corto").visible, "la tecla R vuelve a Aceval con la mano completa")
		_revisar_mano("ACEVAL", "LAT")
		await _segundos(1.2)

	print("Pase desde el nuevo portador (Fernández a Sánchez):")
	pase = _lamina("pase_corto")
	await _arrastrar(pase, _centro_jugador("FERNÁNDEZ"))
	await _soltar_mouse(_centro_jugador("FERNÁNDEZ"))
	await _esperar_pase()
	await _segundos(0.5)
	var toque: CardUI = _lamina("toque_toque")
	await _arrastrar(toque, _centro_jugador("FERNÁNDEZ"))
	_revisa(view.apuntado() == "", "el portador no se puede apuntar a sí mismo")
	var p2 := _centro_jugador("SÁNCHEZ")
	_mover_mouse(p2)
	await _cuadros(4)
	_revisa(view.apuntado() == "SÁNCHEZ", "la flecha se engancha a Sánchez")
	# 39 + 20 + 0,5 × (87 − 66) = 69,5
	_revisa(toque.chance_label.text == "70%", "el porcentaje sale con el Pase de Fernández: %s" % toque.chance_label.text)
	_revisa(view.tono_flecha() == "verde", "con 60% o más la flecha es verde")
	await _segundos(0.4)
	_shot("6_arrastre_fernandez_a_sanchez")
	await _soltar_mouse(p2)
	await _esperar_pase()
	_revisa(view.portador() == "SÁNCHEZ", "Sánchez pasa a ser el portador")
	_revisar_mano("SÁNCHEZ", "EXT")

	print("Botón para volver:")
	var boton: Control = view._volver_btn
	var centro := boton.global_position + boton.size * 0.5
	_mover_mouse(centro, false)
	await _cuadros(3)
	_boton(centro, true)
	await _cuadros(2)
	_boton(centro, false)
	await _cuadros(3)
	_mover_mouse(Vector2(640, 300), false)
	_revisa(view.portador() == "ACEVAL", "el botón vuelve a Aceval")
	await _segundos(1.0)


func _probar_receptor(nombre: String) -> void:
	var pase: CardUI = _lamina("pase_corto")
	var destino := _centro_jugador(nombre)
	await _arrastrar(pase, destino)
	await _segundos(0.45)
	_revisa(view.apuntado() == nombre, "la flecha se engancha a %s" % nombre)
	_revisa(view.tono_flecha() == TONO_ACEVAL[nombre], "color de la flecha: %s" % view.tono_flecha())
	_revisa(pase.chance_label.visible and pase.chance_label.text == PCT_ACEVAL[nombre], "la lámina muestra %s (%s)" % [PCT_ACEVAL[nombre], pase.chance_label.text])
	_revisar_elige(pase)
	var cruces: Array = view.cruces_flecha()
	var sobre_zona := cruces.filter(func(c: String) -> bool: return c.begins_with("zona "))
	var sobre_gente := cruces.filter(func(c: String) -> bool: return not c.begins_with("zona "))
	_revisa(sobre_gente.is_empty(), "la flecha no pasa sobre jugadores ni etiquetas: %s" % str(sobre_gente))
	if not sobre_zona.is_empty():
		print("  aviso: la flecha cruza un nombre de zona: ", sobre_zona)
	var punta: Vector2 = view._fin_flecha()
	var cuerpo: Rect2 = view._rect_cuerpo(view._jugadores[nombre])
	_revisa(absf(punta.x - cuerpo.get_center().x) < 30.0 and punta.y <= cuerpo.position.y + 2.0 and punta.y > cuerpo.position.y - 30.0, "la punta queda sobre la cabeza de %s" % nombre)
	var lista: Array = view.solapes()
	_revisa(lista.is_empty(), "nada se tapa al apuntar %s" % (str(lista) if not lista.is_empty() else ""))
	_shot("arrastre_a_%s" % _sin_tilde(nombre))
	await _soltar_mouse(destino)
	_revisa(not pase.visible, "el pase gasta la lámina")
	await _segundos(0.45)
	_shot("pelota_en_el_aire_a_%s" % _sin_tilde(nombre))
	await _esperar_pase()
	_revisa(view.portador() == nombre, "%s pasa a ser el portador" % nombre)
	var pies: Vector3 = view._jugadores[nombre].position
	_revisa(Vector3(view._pelota.position.x, 0, view._pelota.position.z).distance_to(pies) < 1.2, "la pelota queda a sus pies")
	_revisa(view._jugadores[nombre]._anillo.mesh == view._anillos["portador"], "el anillo dorado es de %s" % nombre)
	var textos := []
	for g in view._con_balon.get_children():
		if not g.is_queued_for_deletion():
			textos.append(g.texto)
	_revisa(str(textos).contains(nombre), "CON EL BALÓN dice %s: %s" % [nombre, str(textos)])
	_revisar_mano(nombre, view.PROPIOS[nombre]["puesto"])
	_revisar_elige()
	await _revisar_solapes("tras recibir %s" % nombre)
	_shot("recibe_%s" % _sin_tilde(nombre))


# ------------------------------------------------------------------ Rendimiento

func _medir() -> void:
	await _segundos(CALENTAR_S)
	_prev = Time.get_ticks_usec()
	_midiendo = true
	var ini := Time.get_ticks_msec()
	var i := 0
	while Time.get_ticks_msec() - ini < int(MEDIR_S * 1000.0):
		var nombre: String = RECEPTORES[i % RECEPTORES.size()]
		i += 1
		var pase: CardUI = _lamina("pase_corto")
		var destino := _centro_jugador(nombre)
		await _arrastrar(pase, destino)
		await _soltar_mouse(destino)
		await _esperar_pase()
		await _segundos(0.4)
		_tecla(KEY_R)
		await _segundos(0.2)
	_midiendo = false
	_informe()


func _informe() -> void:
	var total := 0
	for dt in _tiempos:
		total += dt
	var ordenados := _tiempos.duplicate()
	ordenados.sort()
	var n := ordenados.size()
	var vista: SubViewport = view.get_node("Senal/Vista3D")
	print("---- T-12 rendimiento ----")
	print("renderizador: ", RenderingServer.get_current_rendering_method(), " / ", RenderingServer.get_current_rendering_driver_name())
	print("equipo: ", RenderingServer.get_video_adapter_name(), " | ", OS.get_processor_name(), " | ", OS.get_processor_count(), " hilos")
	print("ventana: ", root.size, " | 3D: ", vista.size, " | MSAA: ", ["no", "2x", "4x", "8x"][vista.msaa_3d], " | jugadores: ", 9 + extras, " | sombras: ", not sin_sombras)
	print("cuadros por segundo (promedio de %d s): %.1f" % [roundi(total / 1000000.0), n * 1000000.0 / total])
	print("cuadro mediano: %.2f ms | peor 1%%: %.2f ms" % [ordenados[n / 2] / 1000.0, ordenados[mini(n - 1, n * 99 / 100)] / 1000.0])
	print("peor cuadro al abrir la escena: %.1f ms" % (_peor_inicio / 1000.0))
	if _gpu_n > 0:
		print("GPU de la cancha 3D: %.2f ms por cuadro" % (_gpu / _gpu_n))
	print("llamadas de dibujo por cuadro: ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_DRAW_CALLS_IN_FRAME),
			" | triángulos: ", RenderingServer.get_rendering_info(RenderingServer.RENDERING_INFO_TOTAL_PRIMITIVES_IN_FRAME))
	print("triángulos por jugador: ", view.Jugador.triangulos_por_jugador("corto"))
