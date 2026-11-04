# T-11: capturas del partido por duelos con el mouse simulado (tests/mouse_duelos.gd). Juega partidos
# rápidos de Colo-Colo contra la U hasta tener: menú, ataque apuntando, pase en el aire, tirada, cuenta
# completa, robo, gol, defensa y ataque del rival. Revisa que ningún texto quede bajo 14 px y mide los
# cuadros por segundo con los 22 jugadores. Necesita pantalla: NO se corre con --headless.
# Uso (desde futbolista/):
#   ..\Godot_v4.7.2-stable_win64_console.exe --path . --resolution 1280x720 -s res://tools/partido_duelos_captura.gd -- --out=C:/ruta
# Opciones (después de --): --sufijo=texto (nombre de las capturas), --rapido (solo menú, apuntando y FPS).
extends SceneTree

const MouseDuelos := preload("res://tests/mouse_duelos.gd")
const RIVAL := "universidad_de_chile"
const MAX_PARTIDOS := 8
const MEDIR_S := 8.0
const RAPIDO_JUEGO := 5.0      # time_scale mientras se juega sin capturar

var out := "user://capturas_t11"
var sufijo := ""
var rapido := false
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
	await _medir()
	for falta in _faltan():
		print("FALTA la captura: ", falta)
	for t in chicos:
		print("TEXTO CHICO: ", t)
	print("capturas: %d partidos, %d capturas, %d textos bajo 14 px" % [partidos, tomadas.size(), chicos.size()])
	quit(1 if fallas > 0 or not chicos.is_empty() else 0)


func _necesarias() -> Array:
	if rapido:
		return ["1_ataque_apuntando"]
	return ["1_ataque_apuntando", "2_pase_en_el_aire", "3_tirada", "4_cuenta", "5_robo", "6_gol", "7_defensa", "8_ataque_rival", "9_pase_misma_zona"]


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
			if tomadas.has("8_ataque_rival") and tomadas.has("5_robo") and tomadas.has("6_gol"):
				await mouse.clic(p._boton_saltar.get_global_rect().get_center())
				await _mientras(func(): return p.modo == PantallaDuelos.Modo.RIVAL)
			else:
				await mouse.cuadros(1)
			continue
		if view._busy:
			await mouse.cuadros(1)
			continue
		if view._in_defense:
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
	if tirada_lista and p.modo == PantallaDuelos.Modo.RIVAL and not tomadas.has("8_ataque_rival"):
		_shot("8_ataque_rival")
	elif tirada_lista and p.modo == PantallaDuelos.Modo.ATAQUE and not tomadas.has("3_tirada"):
		_shot("3_tirada")
	var cartel: String = view._banner_label.text if view._banner.visible and view._banner.modulate.a > 0.95 else ""
	if cartel.contains("ROBARON") and not tomadas.has("5_robo"):
		_shot("5_robo")
	elif cartel.contains("GOOOOL") and not tomadas.has("6_gol"):
		_shot("6_gol")


func _defender(p: PantallaDuelos) -> void:
	var e: MatchEngine = view._engine
	for ui in p.laminas():
		if e.can_play(ui.card):
			await mouse.clic(ui.get_global_rect().get_center())
			await _ocupado()
			return
	await mouse.clic(p._boton_ceder.get_global_rect().get_center())
	await _ocupado()


func _atacar(p: PantallaDuelos) -> void:
	var e: MatchEngine = view._engine
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
