# T-11: capturas del partido por duelos con el mouse simulado (tests/mouse_duelos.gd). Juega partidos
# rápidos de Colo-Colo contra la U hasta tener: menú, ataque apuntando, pase en el aire, tirada, cuenta
# completa, robo, gol, defensa y ataque del rival. Revisa que ningún texto quede bajo 14 px y mide los
# cuadros por segundo con los 22 jugadores. Necesita pantalla: NO se corre con --headless.
# Uso (desde futbolista/):
#   ..\Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1280x720 -s res://tools/partido_duelos_captura.gd -- --out=C:/ruta
# Opciones (después de --): --sufijo=texto (nombre de las capturas), --rapido (solo menú, apuntando y FPS),
# --defensa (T-15, D-44: intención del rival, Presión, Intercepción y Bloqueo arrastrados y una tirada de defensa).
# T-16: además captura la mano con 5, 7 y 10 láminas (y con el cursor encima), tu defensa, el gol del rival
# y el final del partido. Sirve también sobre el código anterior a T-16 (para las capturas de "antes").
extends SceneTree

const MouseDuelos := preload("res://tests/mouse_duelos.gd")
const RIVAL := "universidad_de_chile"
const MAX_PARTIDOS := 8
const MEDIR_S := 8.0
const RAPIDO_JUEGO := 5.0      # time_scale mientras se juega sin capturar

var out := "user://capturas_t11"
var sufijo := ""
var rapido := false
var defensa := false
var desenlaces := false   # D-48: capturas de los desenlaces (dividida, lateral, falta, rebote, córner)
var view: Control
var mouse: MouseDuelos
var tomadas := {}
var chicos: Array = []
var fallas := 0


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.get_slice("=", 1)
		elif arg.begins_with("--sufijo="):
			sufijo = "_" + arg.get_slice("=", 1)
		elif arg == "--desenlaces":
			desenlaces = true
		elif arg == "--defensa":
			defensa = true
		elif arg == "--rapido":
			rapido = true
	DirAccess.make_dir_recursive_absolute(out)
	DisplayServer.window_set_flag(DisplayServer.WINDOW_FLAG_MOUSE_PASSTHROUGH, true)   # el cursor real no ensucia
	DisplayServer.window_set_vsync_mode(DisplayServer.VSYNC_DISABLED)
	Engine.max_fps = 0
	mouse = MouseDuelos.new(self)
	Career.current = null
	change_scene_to_file("res://scenes/match_view.tscn")
	_correr()


func _shot(nombre: String) -> void:
	var ruta := out.path_join(nombre + sufijo + ".png")
	root.get_texture().get_image().save_png(ruta)
	tomadas[nombre] = true
	for t in Paleta.textos_chicos(view):
		if not chicos.has(t):
			chicos.append(t)
	print("captura: ", ruta)


func _correr() -> void:
	await mouse.cuadros(20)
	view = current_scene as Control
	for i in view._rival_option.item_count:
		if view._rival_option.get_item_metadata(i) == RIVAL:
			view._rival_option.selected = i
	view._mode_option.selected = 0
	await mouse.cuadros(5)
	_shot("0_menu")
	var partidos := 0
	while partidos < MAX_PARTIDOS and not _listo():
		view._on_start_pressed()
		partidos += 1
		await _jugar_partido()
		if rapido:
			break
		if view._menu.visible and not tomadas.has("10_final"):
			Engine.time_scale = 1.0
			await mouse.cuadros(30)
			_shot("10_final")
	await _medir()
	for falta in _faltan():
		print("FALTA la captura: ", falta)
	for t in chicos:
		print("TEXTO CHICO: ", t)
	print("capturas: %d partidos, %d capturas, %d textos bajo 14 px" % [partidos, tomadas.size(), chicos.size()])
	quit(1 if fallas > 0 or not chicos.is_empty() else 0)


func _necesarias() -> Array:
	if desenlaces:
		return ["v2_dividida", "v2_lateral", "v2_falta", "v2_rebote", "v2_corner", "v2_corner_centro"]
	if defensa:
		return ["t15_1_intencion", "t15_2_presion", "t15_3_intercepcion", "t15_4_bloqueo", "t15_5_tirada_defensa"]
	if rapido:
		return ["1_ataque_apuntando"]
	return ["1_ataque_apuntando", "2_pase_en_el_aire", "3_tirada", "4_cuenta", "5_robo", "6_gol", "7_defensa", "8_ataque_rival",
		"9_pase_misma_zona", "10_final", "mano_5", "mano_7", "mano_7_cursor", "mano_10"]


func _faltan() -> Array:
	return _necesarias().filter(func(n): return not tomadas.has(n))


func _listo() -> bool:
	return _faltan().is_empty()


func _jugar_partido() -> void:
	Engine.time_scale = RAPIDO_JUEGO
	var cuadros := 0
	while not (view._menu.visible and not view._busy) and cuadros < 200000:
		cuadros += 1
		var p: PantallaDuelos = view._pantalla
		if p == null:
			await mouse.cuadros(1)
			continue
		_vigilar(p)
		if rapido and _listo():
			return
		if p.modo == PantallaDuelos.Modo.RIVAL:
			if defensa or desenlaces or (tomadas.has("8_ataque_rival") and tomadas.has("5_robo") and tomadas.has("6_gol")):
				await mouse.clic(p._boton_saltar.get_global_rect().get_center())
				await _mientras(func(): return p.modo == PantallaDuelos.Modo.RIVAL)
			else:
				await mouse.cuadros(1)
			continue
		if view._busy:
			await mouse.cuadros(1)
			continue
		if view._in_defense:
			if view._engine.duel_defense_on():
				await _defender_duelos(p)
				continue
			if not tomadas.has("7_defensa"):
				await _quieto(30)
				_shot("7_defensa")
			await _defender(p)
		elif view._in_moment:
			await _atacar(p)
		else:
			await mouse.cuadros(1)
	Engine.time_scale = 1.0


# Lo que se captura apenas aparece: la tirada resuelta, los carteles de robo y gol y el ataque rival.
func _vigilar(p: PantallaDuelos) -> void:
	var tirada_lista: bool = p._tirada.visible and p._tirada_t >= 1.0
	if desenlaces:   # D-48: cada desenlace cuando se anuncia, y la tirada de la dividida
		var titulo := String(p._tirada_datos.get("titulo", ""))
		if tirada_lista and titulo.contains("DIVIDIDA") and not tomadas.has("v2_dividida"):
			_shot("v2_dividida")
		if tirada_lista and titulo.begins_with("REBOTE") and not tomadas.has("v2_rebote"):
			_shot("v2_rebote")
		var g: Control = p._desenlace_g
		if g != null and g.visible:
			var nombre: String = {"¡AL LATERAL!": "v2_lateral", "¡FALTA!": "v2_falta", "¡AL CÓRNER!": "v2_corner"}.get(p.ultimo_desenlace, "")
			if nombre != "" and not tomadas.has(nombre):
				_shot(nombre)
		if p.modo == PantallaDuelos.Modo.ATAQUE and view._engine.corner_pending and not view._busy and not tomadas.has("v2_corner_centro"):
			_shot("v2_corner_centro")
	if tirada_lista and p.modo == PantallaDuelos.Modo.RIVAL and not tomadas.has("8_ataque_rival"):
		_shot("8_ataque_rival")
	elif tirada_lista and p.modo == PantallaDuelos.Modo.DEFENSA and defensa and not tomadas.has("t15_5_tirada_defensa"):
		_shot("t15_5_tirada_defensa")
	elif tirada_lista and p.modo == PantallaDuelos.Modo.ATAQUE and not tomadas.has("3_tirada"):
		_shot("3_tirada")
	var cartel := _cartel(p)
	if cartel.contains("ROBARON") and not tomadas.has("5_robo"):
		_shot("5_robo")
	elif cartel.contains("GOOOOL") and not tomadas.has("6_gol"):
		_shot("6_gol")
	elif cartel.contains("GOL DE") and not tomadas.has("6b_gol_rival"):
		_shot("6b_gol_rival")
	elif cartel.contains("A DEFENDER") and not tomadas.has("5b_aviso"):
		_shot("5b_aviso")


# El cartel a la vista: la gráfica de TV de la pantalla de duelos (T-16) o, antes, la caja de match_view.
func _cartel(p: PantallaDuelos) -> String:
	if p != null and "cartel_listo" in p:
		return String(p.get("cartel_texto")) if p.get("cartel_listo") else ""
	return view._banner_label.text if view._banner.visible and view._banner.modulate.a > 0.95 else ""


# T-16: la mano con 5, 7 y 10 láminas (se completan con cartas del mazo) y con el cursor sobre una.
func _capturar_manos(p: PantallaDuelos) -> void:
	var e: MatchEngine = view._engine
	Engine.time_scale = 1.0
	await _mientras(func(): return _cartel(p) != "" or view._busy, 600)
	var original: Array = e.deck.hand.duplicate()
	var reserva: Array = e.deck.draw_pile + e.deck.discard_pile
	for n: int in [5, 7, 10]:
		var mano: Array = original.duplicate()
		var i := 0
		while mano.size() < n and not reserva.is_empty():
			mano.append(reserva[i % reserva.size()])
			i += 1
		e.deck.hand.clear()
		e.deck.hand.append_array(mano.slice(0, n))
		view._build_hand()
		mouse.mover(Vector2(640, 250), false)
		await _quieto(40)
		_shot("mano_%d" % n)
		if n == 7 and p.laminas().size() > 2:
			var ui: CardUI = p.laminas()[2]
			mouse.mover(ui.global_position + Vector2(36, 120), false)
			await _quieto(30)
			_shot("mano_7_cursor")
			mouse.mover(Vector2(640, 250), false)
	e.deck.hand.clear()
	e.deck.hand.append_array(original)
	view._build_hand()
	await _quieto(10)
	Engine.time_scale = RAPIDO_JUEGO


func _defender(p: PantallaDuelos) -> void:
	var e: MatchEngine = view._engine
	for ui in p.laminas():
		if e.can_play(ui.card):
			await mouse.clic(ui.get_global_rect().get_center())
			await _ocupado()
			return
	await mouse.clic(p._boton_ceder.get_global_rect().get_center())
	await _ocupado()



# T-15 (D-44): el rival anunció su jugada. Se captura la intención y, una vez cada una, la Presión, la
# Intercepción (sobre la línea del pase) y el Bloqueo arrastrados sobre el rival, con la placa y tu defensor.
# Las láminas de inicio solo traen Marca y Despeje: la Intercepción y el Bloqueo se agregan a la mano.
func _defender_duelos(p: PantallaDuelos) -> void:
	if desenlaces:
		await mouse.clic(p._boton_ceder.get_global_rect().get_center())
		await _ocupado()
		return
	var e: MatchEngine = view._engine
	var it: Dictionary = view._intent_actual
	var ic: Card = it.get("card")
	Engine.time_scale = 1.0
	await _quieto(45)   # que lleguen a su lugar
	if not view._in_defense or it.is_empty():
		Engine.time_scale = RAPIDO_JUEGO
		return
	if not defensa and not tomadas.has("7_defensa"):
		_shot("7_defensa")
	if not tomadas.has("t15_1_intencion") and ic != null and MatchEngine.is_pass(ic):
		_shot("t15_1_intencion")
	var quiero := Card.Kind.PRESS
	var nombre := "t15_2_presion"
	if ic != null and ic.kind == Card.Kind.SHOT:
		quiero = Card.Kind.BLOCK
		nombre = "t15_4_bloqueo"
	elif ic != null and MatchEngine.is_pass(ic) and tomadas.has("t15_2_presion"):
		quiero = Card.Kind.INTERCEPT
		nombre = "t15_3_intercepcion"
	if ic != null and not e.deck.hand.any(func(c): return c.kind == quiero) and quiero != Card.Kind.PRESS:
		var extra := Card.from_dict(CardDB.load_catalog("res://data/cards.json")["bloqueo" if quiero == Card.Kind.BLOCK else "intercepcion"])
		if e.ap >= e.ap_cost_of(extra):
			e.deck.hand.append(extra)
			view._build_hand()
			await _quieto(45)
	var pick: CardUI = null
	for ui in p.laminas():
		if e.can_play(ui.card) and ui.card.kind == quiero:
			pick = ui
	if pick == null or tomadas.has(nombre):
		await mouse.clic(p._boton_ceder.get_global_rect().get_center())
		Engine.time_scale = RAPIDO_JUEGO
		await _ocupado()
		return
	var target := e.defense_target(pick.card)
	var to := p.punto_de("V:" + target)
	if quiero == Card.Kind.INTERCEPT and p._linea_rival_2d.size() > 4:
		to = p._linea_rival_2d[p._linea_rival_2d.size() / 2]
	await mouse.arrastrar_hasta(pick.get_global_rect().get_center(), to, 12)
	for k in 40:   # siguen llegando a su lugar: el mouse sigue al rival
		var ahora := p.punto_de("V:" + target)
		if quiero == Card.Kind.INTERCEPT and p._linea_rival_2d.size() > 4:
			ahora = p._linea_rival_2d[p._linea_rival_2d.size() / 2]
		to = ahora
		mouse.mover(to)
		await mouse.cuadros(1)
		if p.apuntado() == target and k > 4:
			break
	await _quieto(20)
	_shot(nombre)
	mouse.soltar(to)
	await _mientras(func(): return not (p._tirada.visible and p._tirada_t >= 1.0), 600)
	if not tomadas.has("t15_5_tirada_defensa"):
		_shot("t15_5_tirada_defensa")
	Engine.time_scale = RAPIDO_JUEGO
	await _ocupado()

func _atacar(p: PantallaDuelos) -> void:
	var e: MatchEngine = view._engine
	if e.corner_pending:   # D-48: el córner se tira tocando al que va a cabecear
		var rec := e.best_corner_receiver()
		mouse.mover(p.punto_de("L:" + rec), false)
		await _quieto(20)
		_vigilar(p)
		await mouse.clic(p.punto_de("L:" + rec))
		await _ocupado()
		return
	if not tomadas.has("mano_10") and not rapido and not defensa and not desenlaces and e.deck.hand.size() >= 3:
		await _capturar_manos(p)
		return
	if not tomadas.has("4_cuenta") and not p.laminas().is_empty() and not rapido:
		Engine.time_scale = 1.0
		var ui: CardUI = p.laminas()[0]
		var c := ui.get_global_rect().get_center()
		mouse.apretar(c)
		await _mientras(func(): return not p.cuenta_visible(), 240)
		await mouse.cuadros(10)
		_shot("4_cuenta")
		mouse.soltar(c)
		await mouse.cuadros(3)
		Engine.time_scale = RAPIDO_JUEGO
		return
	for ui in p.laminas():
		var card: Card = ui.card
		if not e.can_play(card):
			continue
		var desde := ui.get_global_rect().get_center()
		if MatchEngine.is_pass(card):
			var opciones: Array = e.receivers(card)
			var adelante: Array = opciones.filter(func(o): return e.pass_zone(card, o["id"]) != e.zone)
			var r := String((adelante if not adelante.is_empty() else opciones)[randi() % maxi(1, (adelante if not adelante.is_empty() else opciones).size())]["id"])
			# D-46: después de la primera captura, un pase a un compañero de la misma zona (placa con NO AVANZA).
			var mismos: Array = opciones.filter(func(o): return e.pass_zone(card, o["id"]) == e.zone and e.target_zone(card) != e.zone)
			var misma := tomadas.has("1_ataque_apuntando") and not tomadas.has("9_pase_misma_zona") and not mismos.is_empty()
			if misma:
				r = String(mismos[0]["id"])
			var capturar := misma or not tomadas.has("1_ataque_apuntando") or not tomadas.has("2_pase_en_el_aire")
			if capturar:
				Engine.time_scale = 1.0
				await _mientras(func(): return view._banner.visible)
				await _quieto(40)
			await mouse.arrastrar_hasta(desde, p.punto_de("L:" + r), 12)
			for i in 90:
				await mouse.cuadros(1)
				mouse.mover(p.punto_de("L:" + r))
				if p.apuntado() == r and i > 30:
					break
			if not tomadas.has("1_ataque_apuntando"):
				_shot("1_ataque_apuntando")
			elif misma and not tomadas.has("9_pase_misma_zona"):
				_shot("9_pase_misma_zona")
			mouse.soltar(p.punto_de("L:" + r))
			if not tomadas.has("2_pase_en_el_aire"):
				await _mientras(func(): return not (p.cancha.en_vuelo() and p.cancha._vuelo_carta != "conduccion"), 600)
				await _mientras(func(): return p.cancha.en_vuelo() and (p.cancha.reloj - p.cancha._vuelo_ini) < p.cancha.duracion_vuelo() * 0.45, 400)
				_shot("2_pase_en_el_aire")
			Engine.time_scale = RAPIDO_JUEGO
		else:
			var hasta := p.punto_de(p.portador())
			await mouse.arrastrar_hasta(desde, hasta, 8)
			mouse.soltar(hasta)
		await _ocupado()
		return
	if e.can_hold():
		await mouse.clic(p._boton_aguantar.get_global_rect().get_center())
	else:
		await mouse.clic(p._boton_ceder.get_global_rect().get_center())
	await _ocupado()


# Espera mientras view._busy, vigilando lo que hay que capturar.
func _ocupado() -> void:
	await mouse.cuadros(1)
	var n := 0
	while view._busy and n < 20000:
		if view._pantalla != null:
			_vigilar(view._pantalla)
		await mouse.cuadros(1)
		n += 1


func _mientras(cond: Callable, maximo: int = 20000) -> void:
	var n := 0
	while cond.call() and n < maximo:
		if view._pantalla != null:
			_vigilar(view._pantalla)
		await mouse.cuadros(1)
		n += 1


func _quieto(n: int) -> void:
	await mouse.cuadros(n)


# Cuadros por segundo con los 22 jugadores y la cancha, con un partido nuevo en marcha a velocidad real.
func _medir() -> void:
	Engine.time_scale = 1.0
	if view._pantalla == null:
		return
	if view._menu.visible:
		view._on_start_pressed()
	await mouse.cuadros(30)   # se mide con el partido en marcha, sea cual sea la fase (sin jugar)
	if view._pantalla == null:
		return
	var t0 := Time.get_ticks_usec()
	var cuadros := 0
	var peor := 0
	var antes := t0
	while Time.get_ticks_usec() - t0 < int(MEDIR_S * 1e6):
		await process_frame
		var ahora := Time.get_ticks_usec()
		peor = maxi(peor, ahora - antes)
		antes = ahora
		cuadros += 1
	var s := float(Time.get_ticks_usec() - t0) / 1e6
	print("FPS (%s, %d jugadores): %.0f promedio, peor cuadro %.1f ms" % [str(DisplayServer.window_get_size()),
		view._pantalla.cancha.jugadores.size(), cuadros / s, peor / 1000.0])
