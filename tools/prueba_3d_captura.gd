# T-12: prueba la escena 3D con eventos de mouse simulados (Input.parse_input_event): arrastra las 4 láminas de
# pase sobre los 4 receptores, suelta fuera, vuelve a Aceval y comprueba portador, láminas, que la pelota en
# vuelo siga la línea y que nada se tape. Guarda capturas y mide los cuadros por segundo de pases seguidos.
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
const CARTAS := ["pase_corto", "toque_toque", "pase_filtrado", "pelotazo"]
# Lo que debe decir cada lámina desde Aceval, con la fórmula de docs/cartas.md ("Pase con marcas").
# Se escribe a mano para no comprobar la fórmula contra sí misma.
const PCT_ACEVAL := {
	"pase_corto": {"VIDAL": 57, "SÁNCHEZ": 45, "FERNÁNDEZ": 29, "MELÉNDEZ": 57},
	"toque_toque": {"VIDAL": 71, "SÁNCHEZ": 59, "FERNÁNDEZ": 43, "MELÉNDEZ": 71},
	"pase_filtrado": {"VIDAL": 71, "SÁNCHEZ": 59, "FERNÁNDEZ": 43, "MELÉNDEZ": 71},
	"pelotazo": {"VIDAL": 39, "SÁNCHEZ": 39, "FERNÁNDEZ": 27, "MELÉNDEZ": 39},
}
const TOLERANCIA_3D := 0.02     # metros entre la pelota en vuelo y la línea
const TOLERANCIA_PX := 1.5      # píxeles (del lienzo) entre la pelota y la línea proyectada
const TOLERANCIA_PIES := 0.75   # metros entre la pelota al llegar y los pies del receptor
const DISTINTAS_M := 0.15       # dos cartas son curvas distintas si se separan al menos esto

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
	# El cursor real del PC no entra a la ventana: si se mueve encima, ensucia los arrastres simulados.
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH, true)
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

	print("Sin objetivo:")
	for carta: String in ["pase_filtrado", "pelotazo"]:
		await _probar_sin_objetivo(carta, vacio)
	# La línea sobre un nombre de zona: termina sobre MEDIO, para ver si los dos se leen.
	var medio: Label = view._zonas[1][0]
	var sobre_medio := medio.position + medio.size * 0.5 + Vector2(0, -6)
	var tramo_medio := _lamina("pase_corto")
	await _arrastrar(tramo_medio, sobre_medio)
	await _segundos(0.2)
	_shot("linea_sobre_nombre_de_zona")
	await _soltar_mouse(sobre_medio)
	await _cuadros(4)
	_revisa(view.portador() == "ACEVAL" and tramo_medio.visible, "soltar sobre un nombre de zona cancela")
	await _probar_matriz()
	await _probar_comprobacion_visual()

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
	await _esperar_vuelo()
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


# La cámara sigue a la pelota con suavidad: hasta que se detiene, los jugadores se corren en la pantalla.
func _camara_quieta() -> void:
	await _cuadros(4)
	var limite := Time.get_ticks_msec() + 6000
	while absf(view._cam_x - view._objetivo_camara(view._pelota.position.x)) > 0.01 and Time.get_ticks_msec() < limite:
		await process_frame
	await _cuadros(2)


func _esperar_vuelo() -> void:
	while view.ocupado():
		await process_frame


func _probar_sin_objetivo(carta: String, vacio: Vector2) -> void:
	var ui := _lamina(carta)
	await _arrastrar(ui, vacio)
	await _segundos(0.2)
	var linea: PackedVector3Array = view.puntos_linea()
	var fin: Vector2 = view._a_pantalla(linea[-1])
	_revisa(fin.distance_to(vacio) < 2.0, "%s: la línea gris termina bajo el mouse (a %.2f px)" % [carta, fin.distance_to(vacio)])
	_revisa(absf(linea[-1].y - view.RADIO_PELOTA) < 0.001, "%s: termina en el pasto" % carta)
	_shot("sin_objetivo_%s" % carta)
	await _soltar_mouse(vacio)
	await _cuadros(4)
	_revisa(view.portador() == "ACEVAL" and ui.visible and not view.ocupado(), "%s: soltar sin objetivo cancela" % carta)


# Distancia de un punto a una línea quebrada.
func _dist_3d(p: Vector3, linea: PackedVector3Array) -> float:
	var mejor := INF
	for i in range(1, linea.size()):
		mejor = minf(mejor, p.distance_to(Geometry3D.get_closest_point_to_segment(p, linea[i - 1], linea[i])))
	return mejor


func _dist_2d(p: Vector2, linea: PackedVector3Array) -> float:
	var mejor := INF
	var antes: Vector2 = view._a_pantalla(linea[0])
	for i in range(1, linea.size()):
		var ahora: Vector2 = view._a_pantalla(linea[i])
		mejor = minf(mejor, p.distance_to(Geometry2D.get_closest_point_to_segment(p, antes, ahora)))
		antes = ahora
	return mejor


func _lado_max(linea: PackedVector3Array) -> float:
	var a := Vector2(linea[0].x, linea[0].z)
	var b := Vector2(linea[-1].x, linea[-1].z)
	var mejor := 0.0
	for p in linea:
		var q := Vector2(p.x, p.z)
		mejor = maxf(mejor, q.distance_to(Geometry2D.get_closest_point_to_segment(q, a, b)))
	return mejor


func _alto_max(linea: PackedVector3Array) -> float:
	var mejor := 0.0
	for p in linea:
		mejor = maxf(mejor, p.y - view.RADIO_PELOTA)
	return mejor


# Las 4 cartas contra los 4 receptores: la pelota en vuelo debe ir por la línea que se mostró.
func _probar_matriz() -> void:
	var lineas := {}
	var duraciones := {}
	var peor_3d := 0.0
	var peor_px := 0.0
	for carta: String in CARTAS:
		for nombre: String in RECEPTORES:
			print("%s a %s:" % [carta, nombre])
			var r: Dictionary = await _probar_pase(carta, nombre)
			peor_3d = maxf(peor_3d, r["d3"])
			peor_px = maxf(peor_px, r["dpx"])
			lineas["%s/%s" % [carta, nombre]] = r["linea"]
			duraciones["%s/%s" % [carta, nombre]] = r["dura"]
	print("Peor distancia entre la pelota y la línea: %.4f m y %.3f px (tolerancia %.2f m y %.1f px)" % [peor_3d, peor_px, TOLERANCIA_3D, TOLERANCIA_PX])
	print("Formas por carta:")
	for nombre: String in RECEPTORES:
		for i in CARTAS.size():
			for j in range(i + 1, CARTAS.size()):
				var a: PackedVector3Array = lineas["%s/%s" % [CARTAS[i], nombre]]
				var b: PackedVector3Array = lineas["%s/%s" % [CARTAS[j], nombre]]
				var sep := 0.0
				for n in a.size():
					sep = maxf(sep, a[n].distance_to(b[n]))
				_revisa(sep >= DISTINTAS_M, "a %s, %s y %s son curvas distintas (se separan %.2f m)" % [nombre, CARTAS[i], CARTAS[j], sep])
		var corto: PackedVector3Array = lineas["pase_corto/%s" % nombre]
		var toque: PackedVector3Array = lineas["toque_toque/%s" % nombre]
		var filtrado: PackedVector3Array = lineas["pase_filtrado/%s" % nombre]
		var pelotazo: PackedVector3Array = lineas["pelotazo/%s" % nombre]
		_revisa(_alto_max(corto) < 0.01 and _lado_max(corto) < 0.01, "a %s, Pase corto va a ras y recto" % nombre)
		_revisa(_alto_max(toque) < 0.5 and _lado_max(toque) < 0.01, "a %s, Toque-toque va casi a ras (%.2f m)" % [nombre, _alto_max(toque)])
		_revisa(_alto_max(filtrado) < 0.01 and _lado_max(filtrado) > 0.5, "a %s, Pase filtrado va a ras y se abre %.2f m" % [nombre, _lado_max(filtrado)])
		_revisa(_alto_max(pelotazo) > 2.0, "a %s, Pelotazo sube %.2f m" % [nombre, _alto_max(pelotazo)])
		var d_toque: float = duraciones["toque_toque/%s" % nombre]
		var d_corto: float = duraciones["pase_corto/%s" % nombre]
		var d_pelotazo: float = duraciones["pelotazo/%s" % nombre]
		_revisa(d_toque < d_corto and d_corto < d_pelotazo, "a %s, Toque-toque es el más rápido y Pelotazo el más lento: %.2f, %.2f y %.2f s" % [nombre, d_toque, d_corto, d_pelotazo])


# Arrastra, compara y suelta. Devuelve la línea mostrada, lo medido y la duración del vuelo.
func _probar_pase(carta: String, nombre: String) -> Dictionary:
	_tecla(KEY_R)
	await _camara_quieta()
	var ui := _lamina(carta)
	_revisa(view.portador() == "ACEVAL" and ui.visible, "la tecla R vuelve a Aceval con la mano completa")
	var destino := _centro_jugador(nombre)
	await _arrastrar(ui, destino)
	await _segundos(0.15)
	_revisa(view.apuntado() == nombre, "la línea se engancha a %s" % nombre)
	var pct: int = PCT_ACEVAL[carta][nombre]
	var tono := "verde" if pct >= 60 else ("dorado" if pct >= 40 else "coral")
	_revisa(ui.chance_label.visible and ui.chance_label.text == "%d%%" % pct, "la lámina dice %d%% (%s)" % [pct, ui.chance_label.text])
	_revisa(view.tono_flecha() == tono, "color de la línea: %s" % view.tono_flecha())
	_revisar_elige(ui)
	var linea: PackedVector3Array = view.puntos_linea().duplicate()
	_revisa(linea[0].distance_to(view._pelota.position) < 0.001, "la línea sale de la pelota")
	var pies: Vector3 = view._jugadores[nombre].position
	var al_pie := Vector2(linea[-1].x - pies.x, linea[-1].z - pies.z).length()
	_revisa(al_pie < TOLERANCIA_PIES, "la línea termina a sus pies (a %.2f m)" % al_pie)
	var lista: Array = view.solapes()
	_revisa(lista.is_empty(), "nada se tapa al apuntar %s" % (str(lista) if not lista.is_empty() else ""))
	if nombre == "FERNÁNDEZ":
		_shot("linea_%s_a_fernandez" % carta)
	await _soltar_mouse(destino)
	_revisa(not ui.visible, "el pase gasta la lámina")
	var d3 := 0.0
	var dpx := 0.0
	var muestras := 0
	var ini := 0
	var fin := 0
	var foto := false
	while view.ocupado():
		await process_frame
		if view.en_vuelo():
			if ini == 0:
				ini = Time.get_ticks_usec()
			fin = Time.get_ticks_usec()
			muestras += 1
			var b: Vector3 = view._pelota.position
			d3 = maxf(d3, _dist_3d(b, linea))
			dpx = maxf(dpx, _dist_2d(view._a_pantalla(b), linea))
			if nombre == "FERNÁNDEZ" and not foto and b.distance_to(linea[0]) > linea[0].distance_to(linea[-1]) * 0.45:
				foto = true
				if carta in ["pelotazo", "pase_filtrado"]:
					_shot("aire_%s_a_fernandez" % carta)
	var dura := (fin - ini) / 1000000.0
	# Solo confirma que se vio el vuelo: con la máquina ocupada hay pocos cuadros, y la pelota igual va por la línea.
	_revisa(muestras >= 3, "la pelota voló (%d cuadros, %.2f s)" % [muestras, dura])
	_revisa(d3 <= TOLERANCIA_3D, "la pelota siguió la línea en el mundo: %.4f m" % d3)
	_revisa(dpx <= TOLERANCIA_PX, "la pelota siguió la línea en la pantalla: %.3f px" % dpx)
	_revisa(view._pelota.position.distance_to(linea[-1]) < 0.001, "la pelota llegó al final de la línea")
	var pies_ahora: Vector3 = view._jugadores[nombre].position
	var llegada := Vector2(view._pelota.position.x - pies_ahora.x, view._pelota.position.z - pies_ahora.z).length()
	_revisa(llegada < TOLERANCIA_PIES, "la pelota quedó a los pies de %s (a %.2f m)" % [nombre, llegada])
	_revisa(view.portador() == nombre, "%s pasa a ser el portador" % nombre)
	_revisa(view._jugadores[nombre]._anillo.mesh == view._anillos["portador"], "el anillo dorado es de %s" % nombre)
	var textos := []
	for g in view._con_balon.get_children():
		if not g.is_queued_for_deletion():
			textos.append(g.texto)
	_revisa(str(textos).contains(nombre), "CON EL BALÓN dice %s" % nombre)
	_revisar_mano(nombre, view.PROPIOS[nombre]["puesto"])
	_revisar_elige()
	await _revisar_solapes("tras recibir %s" % nombre)
	if nombre == "FERNÁNDEZ" and carta == "pase_corto":
		_shot("recibe_fernandez")
	return {"linea": linea, "d3": d3, "dpx": dpx, "dura": dura}


# Deja la línea tenue durante el vuelo, para ver en la captura que la pelota va sobre ella.
func _probar_comprobacion_visual() -> void:
	view.ver_trayectoria_en_vuelo = true
	for carta: String in ["pelotazo", "pase_filtrado"]:
		_tecla(KEY_R)
		await _camara_quieta()
		var ui := _lamina(carta)
		var destino := _centro_jugador("FERNÁNDEZ")
		await _arrastrar(ui, destino)
		await _segundos(0.15)
		await _soltar_mouse(destino)
		while not view.en_vuelo():
			await process_frame
		await _segundos(_mitad_vuelo(carta))
		_shot("aire_con_linea_%s" % carta)
		await _esperar_vuelo()
	view.ver_trayectoria_en_vuelo = false
	_tecla(KEY_R)
	await _camara_quieta()


func _mitad_vuelo(carta: String) -> float:
	return view._vuelo_dura * (0.5 if carta == "pelotazo" else 0.35)


# ------------------------------------------------------------------ Rendimiento

func _medir() -> void:
	await _segundos(CALENTAR_S)
	_prev = Time.get_ticks_usec()
	_midiendo = true
	var ini := Time.get_ticks_msec()
	var i := 0
	while Time.get_ticks_msec() - ini < int(MEDIR_S * 1000.0):
		var nombre: String = RECEPTORES[i % RECEPTORES.size()]
		var pase: CardUI = _lamina(CARTAS[i % CARTAS.size()])
		i += 1
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
