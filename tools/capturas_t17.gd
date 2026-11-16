# Capturas de T-17 (D-49): la oferta de una semana de la segunda mitad (con rarezas), la sesión de video con el "+" propio
# de cada carta, 6 láminas nuevas (2 por estilo) en "Ver mazo" y el partido con una instrucción activa en el marcador.
# Necesita pantalla: NO se corre con --headless.
# Uso (desde futbolista/):
#   ..\Godot_v4.7.2-stable_win64_console.exe --path . -s res://tools/capturas_t17.gd -- --out=C:/ruta/capturas
extends SceneTree

const SAVE := "user://test_capturas_t17.json"
const MAX_FRAMES := 20000
const SETTLE_FRAMES := 90
const LAMP_FRAMES := 40
# Dos láminas por estilo: una básica y una de las raras (élite o instrucción).
const NUEVAS := ["salida_limpia", "juego_posicion", "linea_cinco", "el_muro", "contra_letal", "contra_manual"]   # 2 de Tiki-Taka, 2 de Catenaccio y 2 de Contragolpe (3 láminas por captura)

var out := "user://capturas_t17"
var frames := 0
var step := "boot"
var view: Node
var _wait := 0
var _settled := ""


func _initialize() -> void:
	for arg in OS.get_cmdline_user_args():
		if arg.begins_with("--out="):
			out = arg.get_slice("=", 1)
	DirAccess.make_dir_recursive_absolute(out)
	Career.current = null
	Career.save_path = SAVE
	change_scene_to_file("res://scenes/calendar_view.tscn")


func _shot(shot_name: String) -> void:
	root.get_texture().get_image().save_png(out.path_join(shot_name + ".png"))
	print("captura: ", out.path_join(shot_name + ".png"))


func _process(_delta: float) -> bool:
	frames += 1
	if frames > MAX_FRAMES:
		print("capturas_t17: tiempo agotado en el paso '%s'" % step)
		return _finish(1)
	if _wait > 0:
		_wait -= 1
		return false
	var scene := current_scene
	if scene == null:
		return false
	match step:
		"boot":
			if frames > 10:
				scene._on_start_career()
				step = "oferta"
				_wait = LAMP_FRAMES
		"oferta":
			var c: Career = scene._career
			scene._on_sponsor("telnet")
			c.week = 9   # segunda mitad: ya pueden salir élite e instrucciones
			var tries := 0
			while tries < 60:
				c.training_offer = c.new_offer()
				if c.training_offer.any(func(id): return CardDB.rarity(c.squads.catalog[id]) != "basica"):
					break
				tries += 1
			print("oferta de la semana 9 (%s): %s" % [c.team()["archetype"], c.training_offer])
			c.set_week_event("bautizazo")
			scene._refresh()
			scene._on_event(0)
			scene._refresh()
			scene._on_training("tactical")
			step = "oferta_shot"
			_wait = LAMP_FRAMES
		"oferta_shot":
			_shot("t17_1_oferta_semana_9")
			scene._on_training("video")
			step = "video"
			_wait = LAMP_FRAMES
		"video":
			_shot("t17_2_sesion_video_su_mas")
			scene._career.training_offer = NUEVAS.slice(0, 3)
			scene._on_training("tactical")
			step = "laminas_a"
			_wait = LAMP_FRAMES
		"laminas_a":
			_shot("t17_3a_laminas_tiki_y_catenaccio")
			scene._career.training_offer = NUEVAS.slice(3, 6)
			scene._on_training("video")
			scene._on_training("tactical")
			step = "laminas"
			_wait = LAMP_FRAMES
		"laminas":
			_shot("t17_3b_laminas_catenaccio_y_contragolpe")
			# La sesión de video con las cartas nuevas: cada una con un solo botón, "SU +".
			var c2: Career = scene._career
			c2.deck = []
			for id in NUEVAS + ["pase_corto", "posesion", "presion_tras_perdida"]:
				c2.deck.append({"id": id, "mejora": ""})
			scene._on_training("video")
			step = "video_nuevas"
			_wait = LAMP_FRAMES
		"video_nuevas":
			_shot("t17_2b_sesion_video_cartas_nuevas")
			Career.current = null
			change_scene_to_file("res://scenes/match_view.tscn")
			step = "menu"
			_wait = 20
		"menu":
			view = current_scene
			view._on_start_pressed()
			step = "mano"
			_wait = 5
		"mano":
			if view._busy or view._pantalla == null:
				return false
			if view._in_defense:   # el rival ataca primero: se deja pasar hasta que te toque
				view._on_yield_pressed()
				_wait = 30
				return false
			if not view._in_moment:
				return false
			if _settled != "mano":
				_settled = "mano"
				_wait = SETTLE_FRAMES
				return false
			var e: MatchEngine = view._engine
			var inst := Card.from_dict(CardDB.load_catalog("res://data/cards.json")["juego_posicion"])
			e.deck.hand.append(inst)
			view._build_hand()
			step = "instruccion"
			_wait = SETTLE_FRAMES
		"instruccion":
			_shot("t17_4_partido_mano_con_instruccion")
			var e: MatchEngine = view._engine
			for i in e.deck.hand.size():
				if (e.deck.hand[i] as Card).instruction != "":
					view._on_jugar_duelo(i, "")
					break
			step = "activa"
			_wait = 120
		"activa":
			if view._busy:
				return false
			_shot("t17_5_partido_instruccion_activa")
			return _finish(0)
	return false


func _finish(code: int) -> bool:
	if FileAccess.file_exists(SAVE):
		DirAccess.remove_absolute(SAVE)
	quit(code)
	return true
