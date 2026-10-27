# Reglas de los datos históricos de 2006 (data/history_2006.json, T-07): calendario de una vuelta
# (9 partidos y un club libre por fecha, 18 partidos por club, cada par una vez), tablas que salen de
# los resultados (una diferencia solo vale si review la explica como sanción), llaves de repechaje,
# playoffs y liguilla coherentes con sus marcadores, tabla acumulada, descenso e ids que existen en
# teams_chile_2006.json. Cada sección se comprueba si tiene datos; con "estado": "completo" se exigen
# todas. Antes, las mismas reglas se prueban con temporadas sintéticas para que fallen cuando deben.
# Uso: godot --headless --path . -s res://tests/data_rules.gd
extends SceneTree

const HISTORY_PATH := "res://data/history_2006.json"
const TORNEOS := ["apertura", "clausura"]
const CLUBES := 19                 # 2006: Deportes Concepción suspendido (D-24)
const FECHAS := 19
const PARTIDOS_POR_FECHA := 9
const GRUPOS := ["A", "B", "C", "D"]
const LLAVES_POR_RONDA := {"cuartos": 4, "semis": 2, "final": 1}
const COLUMNAS := ["pj", "pg", "pe", "pp", "gf", "gc", "pts"]
const ESTADOS := ["pendiente", "parcial", "completo"]
const TIPOS_REVIEW := ["bloqueo", "sin_fuente", "discrepancia", "sancion"]
const CRITERIOS := ["global", "penales", "gol_de_visita", "ventaja_deportiva"]
const CLAVES := ["_notes", "estado", "sources", "apertura", "clausura", "tabla_acumulada", "descenso",
		"ascensos", "review"]
const CLAVES_TORNEO := ["inicio", "fin", "equipos", "grupos", "fechas", "tabla", "repechaje", "playoffs",
		"campeon", "goleadores"]

var failures: Array[String] = []
var checks := 0
var league: LeagueManager
var _todos := {}                   # todos los ids de teams_chile_2006.json
var _vacias: Array[String] = []    # secciones sin datos en la última validación
var _fecha_re := RegEx.create_from_string("^\\d{4}-(0[1-9]|1[0-2])-(0[1-9]|[12]\\d|3[01])$")


func _initialize() -> void:
	league = LeagueManager.new()
	_check(league.load_all(), "LeagueManager no carga: %s" % [league.load_errors])
	for t in league.teams:
		_todos[t["id"]] = true
	_test_tabla_a_mano()
	_test_llaves()
	_test_torneo_sintetico()
	_test_temporada_sintetica()
	_test_archivo_pendiente()
	_test_history_file()
	print("data_rules: %d comprobaciones, %d fallas" % [checks, failures.size()])
	for f in failures:
		print("  FALLA: " + f)
	quit(1 if failures.size() > 0 else 0)


func _check(cond: bool, msg: String) -> void:
	checks += 1
	if not cond:
		failures.append(msg)


func _expect_ok(errors: Array[String], what: String) -> void:
	_check(errors.is_empty(), "%s debería pasar: %s" % [what, errors])


# Las reglas tienen que rechazarlo con un error que contenga `contiene` (la regla que se quiere probar).
func _expect_error(errors: Array[String], what: String, contiene: String) -> void:
	var hit := errors.any(func(e: String) -> bool: return e.contains(contiene))
	_check(hit, "%s debería fallar con '%s': %s" % [what, contiene, errors])


# ------------------------------------------------------------------ El archivo real

func _test_history_file() -> void:
	var file := FileAccess.open(HISTORY_PATH, FileAccess.READ)
	_check(file != null, "no se puede abrir %s" % HISTORY_PATH)
	if file == null:
		return
	var data: Variant = JSON.parse_string(file.get_as_text())
	_check(data is Dictionary, "%s no es un objeto JSON válido" % HISTORY_PATH)
	if not (data is Dictionary):
		return
	var errors := _history_errors(data)
	checks += 1
	for e in errors:
		failures.append("history_2006: " + e)
	print("history_2006: estado %s, %d errores%s" % [data.get("estado"), errors.size(),
			"" if _vacias.is_empty() else "; sin datos: " + ", ".join(PackedStringArray(_vacias))])


# ------------------------------------------------------------------ Reglas

func _history_errors(h: Dictionary) -> Array[String]:
	_vacias.clear()
	var e: Array[String] = []
	for key in CLAVES:
		if not h.has(key):
			e.append("falta la clave %s" % key)
	if not e.is_empty():
		return e
	if not (h["estado"] in ESTADOS):
		e.append("estado %s no es uno de %s" % [h["estado"], ESTADOS])
	var completo: bool = h["estado"] == "completo"
	var review := _as_array(h["review"], "review", e)
	e.append_array(_review_errors(review))
	if not completo and review.is_empty():
		e.append("un archivo sin terminar tiene que explicar en review qué falta")
	e.append_array(_sources_errors(_as_array(h["sources"], "sources", e), completo))
	var tablas := {}
	for nombre in TORNEOS:
		var t := _as_dict(h[nombre], nombre, e)
		e.append_array(_torneo_errors(t, nombre, review, completo))
		tablas[nombre] = t.get("tabla", [])
	var acumulada := _as_array(h["tabla_acumulada"], "tabla_acumulada", e)
	e.append_array(_acumulada_errors(acumulada, tablas, review, completo))
	var ascensos := _as_array(h["ascensos"], "ascensos", e)
	e.append_array(_ascensos_errors(ascensos, completo))
	e.append_array(_descenso_errors(_as_dict(h["descenso"], "descenso", e), acumulada, ascensos, review, completo))
	return e


func _torneo_errors(t: Dictionary, nombre: String, review: Array, completo: bool) -> Array[String]:
	var e: Array[String] = []
	for key in CLAVES_TORNEO:
		if not t.has(key):
			e.append("%s: falta %s" % [nombre, key])
	if not e.is_empty():
		return e
	for key in ["inicio", "fin"]:
		if t[key] == null:
			_vacia("%s.%s" % [nombre, key], completo, e)
		elif not _es_dia_2006(t[key]):
			e.append("%s.%s no es un día AAAA-MM-DD de 2006: %s" % [nombre, key, t[key]])
	var inicio: Variant = t["inicio"] if _es_dia_2006(t["inicio"]) else null
	var fin: Variant = t["fin"] if _es_dia_2006(t["fin"]) else null

	var en_torneo := {}
	var equipos := _as_array(t["equipos"], nombre + ".equipos", e)
	for id in equipos:
		if not _es_club(id, "Primera A"):
			e.append("%s.equipos: %s no es un club de Primera A de teams_chile_2006.json" % [nombre, id])
		elif en_torneo.has(id):
			e.append("%s.equipos: %s está repetido" % [nombre, id])
		else:
			en_torneo[id] = true
	if equipos.is_empty():
		_vacia(nombre + ".equipos", completo, e)
	elif equipos.size() != CLUBES:
		e.append("%s tiene %d equipos (deberían ser %d)" % [nombre, equipos.size(), CLUBES])

	var grupos := _as_dict(t["grupos"], nombre + ".grupos", e)
	if grupos.is_empty():
		_vacia(nombre + ".grupos", completo, e)
	else:
		e.append_array(_grupos_errors(grupos, nombre, en_torneo))

	var fechas := _as_array(t["fechas"], nombre + ".fechas", e)
	if fechas.is_empty():
		_vacia(nombre + ".fechas", completo, e)
	else:
		e.append_array(_fechas_errors(fechas, nombre, en_torneo, inicio, fin, review))

	var tabla := _as_array(t["tabla"], nombre + ".tabla", e)
	if tabla.is_empty():
		_vacia(nombre + ".tabla", completo, e)
	else:
		e.append_array(_tabla_errors(tabla, _tabla_desde(fechas), en_torneo, nombre + ".tabla", review))

	e.append_array(_fase_final_errors(t, nombre, en_torneo, grupos, tabla, inicio, fin, review, completo))
	return e


func _grupos_errors(grupos: Dictionary, nombre: String, en_torneo: Dictionary) -> Array[String]:
	var e: Array[String] = []
	var claves := grupos.keys()
	claves.sort()
	if claves != GRUPOS:
		e.append("%s.grupos debería tener los grupos %s y tiene %s" % [nombre, GRUPOS, claves])
	var vistos := {}
	for g in grupos:
		for id in _as_array(grupos[g], "%s.grupos.%s" % [nombre, g], e):
			if not en_torneo.has(id):
				e.append("%s.grupos.%s: %s no está en equipos" % [nombre, g, id])
			elif vistos.has(id):
				e.append("%s.grupos: %s está en dos grupos" % [nombre, id])
			vistos[id] = true
	if not en_torneo.is_empty() and vistos.size() != en_torneo.size():
		e.append("%s.grupos: hay clubes sin grupo" % nombre)
	return e


# Una vuelta: cada fecha con 9 partidos y un club libre, cada club una vez por fecha, una sola fecha
# libre y 18 partidos por club, y cada par una sola vez (con 19 clubes, eso es enfrentar a todos).
func _fechas_errors(fechas: Array, nombre: String, en_torneo: Dictionary, inicio: Variant, fin: Variant,
		review: Array) -> Array[String]:
	var e: Array[String] = []
	if fechas.size() != FECHAS:
		e.append("%s tiene %d fechas (deberían ser %d)" % [nombre, fechas.size(), FECHAS])
	var pares := {}
	var partidos_de := {}
	var libres := {}
	for i in fechas.size():
		var f := _as_dict(fechas[i], "%s.fechas[%d]" % [nombre, i], e)
		if f.is_empty():
			continue
		var donde := "%s.fecha %d" % [nombre, i + 1]
		if not _es_entero(f.get("numero")) or int(f["numero"]) != i + 1:
			e.append("%s.fechas[%d] debería tener numero %d" % [nombre, i, i + 1])
		var en_fecha := {}
		var libre: Variant = f.get("libre")
		if not en_torneo.has(libre):
			e.append("%s: el club libre %s no está en equipos" % [donde, libre])
		else:
			en_fecha[libre] = true
			libres[libre] = libres.get(libre, 0) + 1
		var partidos := _as_array(f.get("partidos"), donde + ".partidos", e)
		if partidos.size() != PARTIDOS_POR_FECHA:
			e.append("%s tiene %d partidos (deberían ser %d)" % [donde, partidos.size(), PARTIDOS_POR_FECHA])
		for p in partidos:
			var pe := _partido_errors(p, donde, en_torneo, inicio, fin, review)
			if not pe.is_empty():
				e.append_array(pe)
				continue
			for id in [p["local"], p["visita"]]:
				if en_fecha.has(id):
					e.append("%s: %s juega dos veces o está libre y juega" % [donde, id])
				en_fecha[id] = true
				partidos_de[id] = partidos_de.get(id, 0) + 1
			var par := _par(p["local"], p["visita"])
			if pares.has(par):
				e.append("%s: %s y %s ya se enfrentaron en la fecha %d" % [donde, p["local"], p["visita"], pares[par]])
			pares[par] = i + 1
	for id in en_torneo:
		if libres.get(id, 0) != 1:
			e.append("%s: %s tiene %d fechas libres (debería tener 1)" % [nombre, id, libres.get(id, 0)])
		if partidos_de.get(id, 0) != CLUBES - 1:
			e.append("%s: %s juega %d partidos (deberían ser %d)" % [nombre, id, partidos_de.get(id, 0), CLUBES - 1])
	return e


# Un partido {local, visita, goles_local, goles_visita, dia, estadio}. Goles null solo si review lo
# explica (tipo "sin_fuente" con este mismo donde).
func _partido_errors(p: Variant, donde: String, validos: Dictionary, inicio: Variant, fin: Variant,
		review: Array) -> Array[String]:
	if not (p is Dictionary):
		return ["%s: un partido no es un objeto" % donde]
	var e: Array[String] = []
	for key in ["local", "visita", "goles_local", "goles_visita", "dia", "estadio"]:
		if not p.has(key):
			e.append("%s: a un partido le falta %s" % [donde, key])
	if not e.is_empty():
		return e
	var quien := "%s %s-%s" % [donde, p["local"], p["visita"]]
	for key in ["local", "visita"]:
		if not validos.has(p[key]):
			e.append("%s: %s no es un club válido aquí" % [quien, p[key]])
	if p["local"] == p["visita"]:
		e.append("%s: un club contra sí mismo" % quien)
	for key in ["goles_local", "goles_visita"]:
		if p[key] == null:
			if not _review_tiene(review, "sin_fuente", donde):
				e.append("%s: %s es null y review no lo explica (sin_fuente, donde '%s')" % [quien, key, donde])
		elif not _es_cuenta(p[key]):
			e.append("%s: %s no es un entero >= 0" % [quien, key])
	if p["dia"] != null:
		if not _es_dia_2006(p["dia"]):
			e.append("%s: dia %s no es un día AAAA-MM-DD de 2006" % [quien, p["dia"]])
		elif (inicio != null and p["dia"] < inicio) or (fin != null and p["dia"] > fin):
			e.append("%s: dia %s fuera del torneo (%s a %s)" % [quien, p["dia"], inicio, fin])
	if p["estadio"] != null and not (p["estadio"] is String):
		e.append("%s: estadio debería ser texto o null" % quien)
	return e


# Tabla calculada desde los partidos: club -> {pj, pg, pe, pp, gf, gc, pts, sin_resultado}. Un partido
# con goles null solo suma el pj y cuenta en sin_resultado.
func _tabla_desde(fechas: Array) -> Dictionary:
	var t := {}
	for f in fechas:
		if not (f is Dictionary) or not (f.get("partidos") is Array):
			continue
		for p in f["partidos"]:
			if not (p is Dictionary) or not p.has("local") or not p.has("visita"):
				continue
			var conocido := _es_cuenta(p.get("goles_local")) and _es_cuenta(p.get("goles_visita"))
			for lado in [[p["local"], p.get("goles_local"), p.get("goles_visita")],
					[p["visita"], p.get("goles_visita"), p.get("goles_local")]]:
				if not t.has(lado[0]):
					t[lado[0]] = _fila_vacia()
					t[lado[0]]["sin_resultado"] = 0
				var fila: Dictionary = t[lado[0]]
				fila["pj"] += 1
				if not conocido:
					fila["sin_resultado"] += 1
					continue
				var a: int = int(lado[1])
				var b: int = int(lado[2])
				fila["gf"] += a
				fila["gc"] += b
				if a > b:
					fila["pg"] += 1
					fila["pts"] += 3
				elif a == b:
					fila["pe"] += 1
					fila["pts"] += 1
				else:
					fila["pp"] += 1
	return t


# Una tabla publicada: cada club una vez, ordenada por puntos y con pj = pg + pe + pp. Si hay una tabla
# esperada (la calculada desde los resultados o la suma de los dos torneos), coincide con ella columna
# por columna; los pts solo pueden diferir en las sanciones de review con este mismo donde.
func _tabla_errors(tabla: Array, esperada: Dictionary, validos: Dictionary, donde: String,
		review: Array) -> Array[String]:
	var e: Array[String] = []
	if not validos.is_empty() and tabla.size() != validos.size():
		e.append("%s tiene %d filas (deberían ser %d)" % [donde, tabla.size(), validos.size()])
	var vistos := {}
	var previo := INF
	for i in tabla.size():
		var fila: Variant = tabla[i]
		var quien := "%s, puesto %d" % [donde, i + 1]
		if not (fila is Dictionary):
			e.append(quien + " no es un objeto")
			continue
		var club: Variant = fila.get("club")
		if not validos.has(club):
			e.append("%s: %s no está en el torneo" % [quien, club])
			continue
		if vistos.has(club):
			e.append("%s: %s está repetido" % [quien, club])
			continue
		vistos[club] = true
		var malas := COLUMNAS.filter(func(c: String) -> bool: return not _es_entero(fila.get(c)))
		if not malas.is_empty():
			e.append("%s (%s): columnas sin un entero: %s" % [quien, club, malas])
			continue
		var v := {}
		for c in COLUMNAS:
			v[c] = int(fila[c])
		var ajuste := _sancion(review, donde, club)
		if v["pj"] != v["pg"] + v["pe"] + v["pp"]:
			e.append("%s (%s): pj %d no es pg + pe + pp" % [donde, club, v["pj"]])
		if v["pts"] > previo:
			e.append("%s: no está ordenada por puntos (%s tiene más que el puesto anterior)" % [quien, club])
		previo = float(v["pts"])
		var calc: Dictionary = esperada.get(club, {})
		var sin_resultado: int = calc.get("sin_resultado", 0)
		if esperada.is_empty() or sin_resultado > 0:
			if v["pts"] != 3 * v["pg"] + v["pe"] + ajuste:
				e.append("%s (%s): pts %d no son 3·pg + pe%s" % [donde, club, v["pts"],
						"" if ajuste == 0 else " %+d de sanción" % ajuste])
		if esperada.is_empty():
			continue
		if calc.is_empty():
			e.append("%s (%s): no aparece en los resultados" % [donde, club])
			continue
		for c in (["pj"] if sin_resultado > 0 else COLUMNAS):
			var esperado: int = calc[c] + (ajuste if c == "pts" else 0)
			if v[c] != esperado:
				e.append("%s (%s): %s publicado %d, calculado %d%s" % [donde, club, c, v[c], esperado,
						" (sin sanción en review que lo explique)" if c == "pts" else ""])
	return e


func _fase_final_errors(t: Dictionary, nombre: String, en_torneo: Dictionary, grupos: Dictionary, tabla: Array,
		inicio: Variant, fin: Variant, review: Array, completo: bool) -> Array[String]:
	var e: Array[String] = []
	var posiciones := {}   # club -> puesto en la tabla publicada (0 = primero), para la ventaja deportiva
	var pts_de := {}
	for i in tabla.size():
		if tabla[i] is Dictionary and _es_entero(tabla[i].get("pts")):
			posiciones[tabla[i].get("club")] = i
			pts_de[tabla[i].get("club")] = int(tabla[i]["pts"])

	var gano_repechaje := {}
	var repechaje := _as_array(t["repechaje"], nombre + ".repechaje", e)
	for i in repechaje.size():
		e.append_array(_llave_errors(repechaje[i], "%s.repechaje %d" % [nombre, i + 1], en_torneo, inicio, fin,
				review, posiciones))
		if repechaje[i] is Dictionary:
			gano_repechaje[repechaje[i].get("avanza")] = true

	var playoffs := _as_dict(t["playoffs"], nombre + ".playoffs", e)
	var ganadores := {}    # quienes avanzaron en la ronda anterior (vacío si no hay ronda anterior)
	var la_final: Variant = null
	for ronda in LLAVES_POR_RONDA:
		var donde := "%s.playoffs.%s" % [nombre, ronda]
		if not playoffs.has(ronda):
			e.append("%s: falta" % donde)
			ganadores = {}
			continue
		var llaves: Array = []
		if ronda != "final":
			llaves = _as_array(playoffs[ronda], donde, e)
		elif playoffs[ronda] != null:
			llaves = [playoffs[ronda]]
			la_final = playoffs[ronda]
		if llaves.is_empty():
			_vacia(donde, completo, e)
			ganadores = {}
			continue
		if llaves.size() != LLAVES_POR_RONDA[ronda]:
			e.append("%s tiene %d llaves (deberían ser %d)" % [donde, llaves.size(), LLAVES_POR_RONDA[ronda]])
		var jugaron := {}
		var avanzaron := {}
		for i in llaves.size():
			var quien := donde if ronda == "final" else "%s %d" % [donde, i + 1]
			e.append_array(_llave_errors(llaves[i], quien, en_torneo, inicio, fin, review, posiciones))
			for id in _participantes(llaves[i]):
				if jugaron.has(id):
					e.append("%s: %s juega dos llaves" % [donde, id])
				jugaron[id] = true
			if llaves[i] is Dictionary:
				avanzaron[llaves[i].get("avanza")] = true
		if not ganadores.is_empty() and not _mismas_claves(jugaron, ganadores):
			e.append("%s: la juegan %s y deberían jugarla los que avanzaron antes, %s" % [donde, jugaron.keys(),
					ganadores.keys()])
		if ronda == "cuartos" and not grupos.is_empty():
			for id in jugaron:
				if not _entre_dos_primeros(id, grupos, pts_de) and not gano_repechaje.has(id):
					e.append("%s: %s no está entre los 2 primeros de su grupo ni ganó el repechaje" % [donde, id])
		ganadores = avanzaron

	var campeon: Variant = t["campeon"]
	if campeon == null:
		_vacia(nombre + ".campeon", completo, e)
	elif not en_torneo.has(campeon):
		e.append("%s.campeon: %s no está en equipos" % [nombre, campeon])
	elif la_final is Dictionary and la_final.get("avanza") != campeon:
		e.append("%s.campeon es %s pero la final la ganó %s" % [nombre, campeon, la_final.get("avanza")])

	var goleadores := _as_array(t["goleadores"], nombre + ".goleadores", e)
	if goleadores.is_empty():
		_vacia(nombre + ".goleadores", completo, e)
	var goles: Variant = null
	for g in goleadores:
		if not (g is Dictionary) or not (g.get("nombre") is String) or String(g["nombre"]).is_empty() \
				or not _es_cuenta(g.get("goles")):
			e.append("%s.goleadores: cada uno es {nombre, club, goles}: %s" % [nombre, g])
			continue
		if not en_torneo.has(g.get("club")):
			e.append("%s.goleadores: %s no está en equipos" % [nombre, g.get("club")])
		if goles != null and int(g["goles"]) != goles:
			e.append("%s.goleadores: si son varios, empataron en goles" % nombre)
		goles = int(g["goles"])
	return e


# Una llave: ida y vuelta (vuelta null si fue a partido único), global {id: goles} con la suma de ambos
# partidos, penales null o {id: goles}, avanza y criterio (null: lo deciden el global o los penales;
# "gol_de_visita" o "ventaja_deportiva", el mejor puesto en la tabla, si el global quedó empatado).
func _llave_errors(ll: Variant, donde: String, validos: Dictionary, inicio: Variant, fin: Variant,
		review: Array, posiciones: Dictionary) -> Array[String]:
	if not (ll is Dictionary):
		return ["%s no es un objeto" % donde]
	var e: Array[String] = []
	for key in ["ida", "vuelta", "global", "penales", "avanza", "criterio"]:
		if not ll.has(key):
			e.append("%s: falta %s" % [donde, key])
	if not e.is_empty():
		return e
	e.append_array(_partido_errors(ll["ida"], donde + " (ida)", validos, inicio, fin, review))
	var vuelta: Variant = ll["vuelta"]
	if vuelta != null:
		e.append_array(_partido_errors(vuelta, donde + " (vuelta)", validos, inicio, fin, review))
	if not e.is_empty():
		return e
	var ida: Dictionary = ll["ida"]
	var a: String = ida["local"]
	var b: String = ida["visita"]
	if vuelta != null and (vuelta["local"] != b or vuelta["visita"] != a):
		return ["%s: la vuelta debería ser %s-%s" % [donde, b, a]]
	if ida["goles_local"] == null or ida["goles_visita"] == null \
			or (vuelta != null and (vuelta["goles_local"] == null or vuelta["goles_visita"] == null)):
		return e   # sin_fuente explicado en review: no se puede comprobar el resto
	var ga: int = int(ida["goles_local"]) + (int(vuelta["goles_visita"]) if vuelta != null else 0)
	var gb: int = int(ida["goles_visita"]) + (int(vuelta["goles_local"]) if vuelta != null else 0)
	if not _marcador(ll["global"], a, b) or int(ll["global"][a]) != ga or int(ll["global"][b]) != gb:
		e.append("%s: el global debería ser {%s: %d, %s: %d}" % [donde, a, ga, b, gb])
	var criterio: Variant = ll["criterio"]
	if criterio != null and not (criterio in CRITERIOS):
		e.append("%s: criterio %s no es uno de %s" % [donde, criterio, CRITERIOS])
		return e
	var esperado: Variant = null
	if ga != gb:
		esperado = a if ga > gb else b
		if ll["penales"] != null:
			e.append("%s: hay penales sin empate en el global" % donde)
		if criterio != null and criterio != "global":
			e.append("%s: criterio %s con el global desempatado" % [donde, criterio])
	elif ll["penales"] != null:
		var pen: Variant = ll["penales"]
		if not _marcador(pen, a, b):
			e.append("%s: penales debería ser {%s: n, %s: n}" % [donde, a, b])
		elif int(pen[a]) == int(pen[b]):
			e.append("%s: los penales no pueden terminar empatados" % donde)
		else:
			esperado = a if int(pen[a]) > int(pen[b]) else b
		if criterio != null and criterio != "penales":
			e.append("%s: criterio %s con penales" % [donde, criterio])
	elif criterio == "gol_de_visita":
		if vuelta == null:
			e.append("%s: a partido único no hay gol de visita" % donde)
		elif int(vuelta["goles_visita"]) == int(ida["goles_visita"]):
			e.append("%s: también empataron en goles de visita" % donde)
		else:
			esperado = a if int(vuelta["goles_visita"]) > int(ida["goles_visita"]) else b
	elif criterio == "ventaja_deportiva":
		if not (posiciones.has(a) and posiciones.has(b)):
			e.append("%s: sin la tabla no se puede comprobar la ventaja deportiva" % donde)
		else:
			esperado = a if posiciones[a] < posiciones[b] else b
	else:
		e.append("%s: global empatado sin penales ni criterio que lo decida" % donde)
	if not (ll["avanza"] in [a, b]):
		e.append("%s: avanza %s, que no jugó la llave" % [donde, ll["avanza"]])
	elif esperado != null and ll["avanza"] != esperado:
		e.append("%s: avanza %s pero según el marcador avanza %s" % [donde, ll["avanza"], esperado])
	return e


# La acumulada del año: suma de las tablas de la fase regular de ambos torneos.
func _acumulada_errors(acumulada: Array, tablas: Dictionary, review: Array, completo: bool) -> Array[String]:
	var e: Array[String] = []
	if acumulada.is_empty():
		_vacia("tabla_acumulada", completo, e)
		return e
	for nombre in TORNEOS:
		if not (tablas[nombre] is Array) or tablas[nombre].is_empty():
			e.append("tabla_acumulada: falta la tabla de %s para comprobarla" % nombre)
	if not e.is_empty():
		return e
	var suma := _sumar_tablas(tablas["apertura"], tablas["clausura"])
	e.append_array(_tabla_errors(acumulada, suma, suma, "tabla_acumulada", review))
	return e


# Descenso por la acumulada (D-24): el último baja directo y el penúltimo va a la liguilla de promoción
# contra un club de Primera B. Si la pierde, su rival sube.
func _descenso_errors(d: Dictionary, acumulada: Array, ascensos: Array, review: Array,
		completo: bool) -> Array[String]:
	var e: Array[String] = []
	if not d.has_all(["directo", "liguilla"]):
		return ["descenso debería tener directo y liguilla"]
	var ultimos: Array = []
	for f in acumulada.slice(-2):
		ultimos.append(f.get("club") if f is Dictionary else null)
	if d["directo"] == null:
		_vacia("descenso.directo", completo, e)
	elif not _es_club(d["directo"], "Primera A"):
		e.append("descenso.directo: %s no es un club de Primera A" % d["directo"])
	elif ultimos.size() == 2 and d["directo"] != ultimos[1]:
		e.append("descenso.directo es %s pero el último de la acumulada es %s" % [d["directo"], ultimos[1]])
	var lig: Variant = d["liguilla"]
	if lig == null:
		_vacia("descenso.liguilla", completo, e)
		return e
	if not (lig is Dictionary) or not lig.has_all(["club", "llave", "se_mantiene"]):
		e.append("descenso.liguilla debería ser {club, llave, se_mantiene}")
		return e
	if not _es_club(lig["club"], "Primera A"):
		e.append("descenso.liguilla: %s no es un club de Primera A" % lig["club"])
	elif ultimos.size() == 2 and lig["club"] != ultimos[0]:
		e.append("descenso.liguilla es para %s pero el penúltimo de la acumulada es %s" % [lig["club"], ultimos[0]])
	var llave_errors := _llave_errors(lig["llave"], "descenso.liguilla", _todos, null, null, review, {})
	e.append_array(llave_errors)
	if not llave_errors.is_empty():
		return e
	var jugaron := _participantes(lig["llave"])
	if not (lig["club"] in jugaron):
		e.append("descenso.liguilla: la llave no la juega %s" % lig["club"])
		return e
	var rival: Variant = jugaron[1] if jugaron[0] == lig["club"] else jugaron[0]
	if not _es_club(rival, "Primera B"):
		e.append("descenso.liguilla: el rival %s no es de Primera B" % rival)
	if not (lig["se_mantiene"] is bool) or lig["se_mantiene"] != (lig["llave"]["avanza"] == lig["club"]):
		e.append("descenso.liguilla: se_mantiene no coincide con quién ganó la llave")
	elif not lig["se_mantiene"] and not (rival in ascensos):
		e.append("descenso.liguilla: %s ganó la liguilla y no está en ascensos" % rival)
	return e


func _ascensos_errors(ascensos: Array, completo: bool) -> Array[String]:
	var e: Array[String] = []
	if ascensos.is_empty():
		_vacia("ascensos", completo, e)
	var vistos := {}
	for id in ascensos:
		if not _es_club(id, "Primera B"):
			e.append("ascensos: %s no es un club de Primera B de teams_chile_2006.json" % id)
		elif vistos.has(id):
			e.append("ascensos: %s está repetido" % id)
		vistos[id] = true
	return e


func _review_errors(review: Array) -> Array[String]:
	var e: Array[String] = []
	for i in review.size():
		var r: Variant = review[i]
		var quien := "review[%d]" % i
		if not (r is Dictionary):
			e.append(quien + " debería ser un objeto {tipo, donde, detalle}")
			continue
		if not (r.get("tipo") in TIPOS_REVIEW):
			e.append("%s: tipo %s no es uno de %s" % [quien, r.get("tipo"), TIPOS_REVIEW])
		for key in ["donde", "detalle"]:
			if not (r.get(key) is String) or String(r[key]).is_empty():
				e.append("%s: falta %s" % [quien, key])
		if r.get("tipo") == "sancion":
			if not _es_club(r.get("club"), ""):
				e.append("%s: la sanción necesita un club de teams_chile_2006.json" % quien)
			if not _es_entero(r.get("pts")) or int(r["pts"]) == 0:
				e.append("%s: la sanción necesita pts distinto de 0" % quien)
	return e


func _sources_errors(sources: Array, completo: bool) -> Array[String]:
	var e: Array[String] = []
	if sources.is_empty():
		e.append("sources está vacía: cada dato necesita fuente (D-02)")
	var ids := {}
	for i in sources.size():
		var s: Variant = sources[i]
		var quien := "sources[%d]" % i
		if not (s is Dictionary):
			e.append(quien + " debería ser un objeto {id, titulo, url, consultada, uso}")
			continue
		for key in ["id", "titulo", "url", "uso"]:
			if not (s.get(key) is String) or String(s[key]).is_empty():
				e.append("%s: falta %s" % [quien, key])
		if s.get("url") is String and not String(s["url"]).begins_with("https://"):
			e.append("%s: url debería empezar con https://" % quien)
		if ids.has(s.get("id")):
			e.append("%s: id %s repetido" % [quien, s.get("id")])
		ids[s.get("id")] = true
		if not s.has("consultada"):
			e.append("%s: falta consultada" % quien)
		elif s["consultada"] == null:
			if completo:
				e.append("%s: un archivo completo necesita la fecha de consulta" % quien)
		elif not (s["consultada"] is String) or _fecha_re.search(s["consultada"]) == null:
			e.append("%s: consultada debería ser AAAA-MM-DD o null" % quien)
	return e


# ------------------------------------------------------------------ Ayudas

# Una sección sin datos: error si el archivo dice estar completo; si no, queda anotada como pendiente.
func _vacia(seccion: String, completo: bool, e: Array[String]) -> void:
	if completo:
		e.append("%s está vacía y el estado es completo" % seccion)
	else:
		_vacias.append(seccion)


func _as_array(v: Variant, donde: String, e: Array[String]) -> Array:
	if v is Array:
		return v
	e.append("%s debería ser una lista" % donde)
	return []


func _as_dict(v: Variant, donde: String, e: Array[String]) -> Dictionary:
	if v is Dictionary:
		return v
	e.append("%s debería ser un objeto" % donde)
	return {}


func _es_club(id: Variant, division: String) -> bool:
	if not (id is String):
		return false
	var team := league.get_team(id)
	return not team.is_empty() and (division == "" or team["division"] == division)


func _es_entero(v: Variant) -> bool:
	return (v is int or v is float) and float(v) == floorf(float(v))


func _es_cuenta(v: Variant) -> bool:
	return _es_entero(v) and v >= 0


func _es_dia_2006(v: Variant) -> bool:
	return v is String and v.begins_with("2006-") and _fecha_re.search(v) != null


func _marcador(m: Variant, a: String, b: String) -> bool:
	return m is Dictionary and m.size() == 2 and m.has(a) and m.has(b) and _es_cuenta(m[a]) and _es_cuenta(m[b])


func _par(a: Variant, b: Variant) -> String:
	return "%s|%s" % ([a, b] if str(a) < str(b) else [b, a])


func _participantes(ll: Variant) -> Array:
	if not (ll is Dictionary) or not (ll.get("ida") is Dictionary):
		return []
	return [ll["ida"].get("local"), ll["ida"].get("visita")]


func _mismas_claves(x: Dictionary, y: Dictionary) -> bool:
	return x.size() == y.size() and x.keys().all(func(k: Variant) -> bool: return y.has(k))


func _review_tiene(review: Array, tipo: String, donde: String) -> bool:
	for r in review:
		if r is Dictionary and r.get("tipo") == tipo and r.get("donde") == donde:
			return true
	return false


func _sancion(review: Array, donde: String, club: Variant) -> int:
	var total := 0
	for r in review:
		if r is Dictionary and r.get("tipo") == "sancion" and r.get("donde") == donde and r.get("club") == club \
				and _es_entero(r.get("pts")):
			total += int(r["pts"])
	return total


# Con los puntos de la tabla: el club termina entre los 2 primeros de su grupo (un empate en puntos con el
# segundo también cuenta, porque el desempate no se comprueba). Sin puntos no se puede decir que no.
func _entre_dos_primeros(id: Variant, grupos: Dictionary, pts_de: Dictionary) -> bool:
	for g in grupos:
		var miembros: Variant = grupos[g]
		if not (miembros is Array) or not (id in miembros):
			continue
		var pts: Array = []
		for m in miembros:
			if not pts_de.has(m):
				return true
			pts.append(pts_de[m])
		pts.sort()
		pts.reverse()
		return pts.size() < 2 or pts_de[id] >= pts[1]
	return true


func _fila_vacia() -> Dictionary:
	return {"pj": 0, "pg": 0, "pe": 0, "pp": 0, "gf": 0, "gc": 0, "pts": 0}


# club -> suma de sus filas en ambas tablas (columnas que no son enteros se ignoran: ya fallan aparte).
func _sumar_tablas(t1: Array, t2: Array) -> Dictionary:
	var suma := {}
	for fila in t1 + t2:
		if not (fila is Dictionary) or not (fila.get("club") is String):
			continue
		if not suma.has(fila["club"]):
			suma[fila["club"]] = _fila_vacia()
		for c in COLUMNAS:
			if _es_entero(fila.get(c)):
				suma[fila["club"]][c] += int(fila[c])
	return suma


# ------------------------------------------------------------------ Pruebas de las reglas
# Las temporadas sintéticas usan ids reales con resultados al azar (semilla fija): solo prueban que las
# reglas acepten lo coherente y rechacen lo que no; nunca se escriben en data/ ni dicen nada de 2006.

func _test_tabla_a_mano() -> void:
	var fechas := [{"partidos": [_partido("a", "b", 2, 1), _partido("b", "c", 0, 0), _partido("c", "a", 1, 3),
			_partido("a", "d", null, null)]}]
	var t := _tabla_desde(fechas)
	_check(t["a"] == {"pj": 3, "pg": 2, "pe": 0, "pp": 0, "gf": 5, "gc": 2, "pts": 6, "sin_resultado": 1},
			"tabla a mano, a: %s" % [t["a"]])
	_check(t["b"] == {"pj": 2, "pg": 0, "pe": 1, "pp": 1, "gf": 1, "gc": 2, "pts": 1, "sin_resultado": 0},
			"tabla a mano, b: %s" % [t["b"]])
	_check(t["c"] == {"pj": 2, "pg": 0, "pe": 1, "pp": 1, "gf": 1, "gc": 3, "pts": 1, "sin_resultado": 0},
			"tabla a mano, c: %s" % [t["c"]])


func _test_llaves() -> void:
	var v := {"x": true, "y": true}
	var gana_x := _llave(_partido("x", "y", 2, 1), _partido("y", "x", 1, 1), {"x": 3, "y": 2}, null, "x", null)
	_expect_ok(_llave_errors(gana_x, "llave", v, null, null, [], {}), "x gana 3-2 el global")
	var mal := gana_x.duplicate(true)
	mal["avanza"] = "y"
	_expect_error(_llave_errors(mal, "llave", v, null, null, [], {}), "avanza el que perdió el global", "avanza")
	mal = gana_x.duplicate(true)
	mal["global"] = {"x": 3, "y": 3}
	_expect_error(_llave_errors(mal, "llave", v, null, null, [], {}), "un global mal sumado", "global")
	mal = gana_x.duplicate(true)
	mal["vuelta"] = _partido("x", "y", 1, 1)
	_expect_error(_llave_errors(mal, "llave", v, null, null, [], {}), "una vuelta con el mismo local", "vuelta")
	mal = gana_x.duplicate(true)
	mal["penales"] = {"x": 4, "y": 2}
	_expect_error(_llave_errors(mal, "llave", v, null, null, [], {}), "penales sin empate", "penales")

	var penales := _llave(_partido("x", "y", 1, 0), _partido("y", "x", 1, 0), {"x": 1, "y": 1}, {"x": 4, "y": 5},
			"y", null)
	_expect_ok(_llave_errors(penales, "llave", v, null, null, [], {}), "y gana por penales")
	mal = penales.duplicate(true)
	mal["avanza"] = "x"
	_expect_error(_llave_errors(mal, "llave", v, null, null, [], {}), "avanza el que perdió los penales", "avanza")
	mal = penales.duplicate(true)
	mal["penales"] = null
	_expect_error(_llave_errors(mal, "llave", v, null, null, [], {}), "un empate sin desempate", "empatado")
	mal["criterio"] = "gol_de_visita"
	_expect_error(_llave_errors(mal, "llave", v, null, null, [], {}), "gol de visita también empatado", "visita")

	var visita := _llave(_partido("x", "y", 1, 1), _partido("y", "x", 2, 2), {"x": 3, "y": 3}, null, "x",
			"gol_de_visita")
	_expect_ok(_llave_errors(visita, "llave", v, null, null, [], {}), "x gana por gol de visita")
	mal = visita.duplicate(true)
	mal["avanza"] = "y"
	_expect_error(_llave_errors(mal, "llave", v, null, null, [], {}), "avanza el de menos goles de visita", "avanza")

	var ventaja := _llave(_partido("x", "y", 0, 0), _partido("y", "x", 1, 1), {"x": 1, "y": 1}, null, "y",
			"ventaja_deportiva")
	_expect_ok(_llave_errors(ventaja, "llave", v, null, null, [], {"x": 5, "y": 0}), "y avanza por mejor puesto")
	_expect_error(_llave_errors(ventaja, "llave", v, null, null, [], {"x": 0, "y": 5}),
			"avanza el de peor puesto", "avanza")
	_expect_error(_llave_errors(ventaja, "llave", v, null, null, [], {}), "ventaja deportiva sin tabla", "tabla")

	var unico := _llave(_partido("x", "y", 0, 2), null, {"x": 0, "y": 2}, null, "y", null)
	_expect_ok(_llave_errors(unico, "llave", v, null, null, [], {}), "una llave a partido único")


func _test_torneo_sintetico() -> void:
	var t := _torneo_sintetico(1)
	_expect_ok(_torneo_errors(t, "apertura", [], true), "un torneo sintético coherente")

	var mal := t.duplicate(true)
	var ultimo: String = mal["tabla"][-1]["club"]
	mal["tabla"][-1]["pts"] -= 3
	_expect_error(_torneo_errors(mal, "apertura", [], true), "3 puntos menos sin explicar", "pts")
	var sancion := [{"tipo": "sancion", "donde": "apertura.tabla", "detalle": "prueba", "club": ultimo, "pts": -3}]
	_expect_ok(_torneo_errors(mal, "apertura", sancion, true), "3 puntos menos con la sanción en review")
	_expect_error(_torneo_errors(mal, "clausura", sancion, true), "una sanción anotada en otro torneo", "pts")

	mal = t.duplicate(true)
	for f in mal["fechas"]:
		var p: Dictionary = f["partidos"][0]
		if p["goles_local"] != p["goles_visita"]:
			var g: int = p["goles_local"]
			p["goles_local"] = p["goles_visita"]
			p["goles_visita"] = g
			break
	_expect_error(_torneo_errors(mal, "apertura", [], true), "un resultado dado vuelta", "calculado")

	mal = t.duplicate(true)
	mal["fechas"][1]["partidos"][0] = mal["fechas"][0]["partidos"][0].duplicate()
	_expect_error(_torneo_errors(mal, "apertura", [], true), "un par que se repite", "ya se enfrentaron")

	mal = t.duplicate(true)
	mal["fechas"][0]["partidos"].pop_back()
	_expect_error(_torneo_errors(mal, "apertura", [], true), "una fecha con 8 partidos", "8 partidos")

	mal = t.duplicate(true)
	mal["fechas"][0]["libre"] = mal["fechas"][1]["libre"]
	_expect_error(_torneo_errors(mal, "apertura", [], true), "un club libre dos veces", "fechas libres")

	mal = t.duplicate(true)
	mal["fechas"][0]["partidos"][0]["goles_local"] = null
	_expect_error(_torneo_errors(mal, "apertura", [], true), "un resultado null sin explicar", "review")
	var sin_fuente := [{"tipo": "sin_fuente", "donde": "apertura.fecha 1", "detalle": "prueba"}]
	_expect_ok(_torneo_errors(mal, "apertura", sin_fuente, true), "un resultado null explicado en review")

	mal = t.duplicate(true)
	mal["equipos"][0] = "club_inexistente"
	_expect_error(_torneo_errors(mal, "apertura", [], true), "un id que no existe", "club_inexistente")
	mal = t.duplicate(true)
	mal["equipos"][0] = "deportes_melipilla"
	_expect_error(_torneo_errors(mal, "apertura", [], true), "un club de Primera B en el torneo", "Primera A")

	mal = t.duplicate(true)
	mal["fin"] = "2006-06-30"
	mal["fechas"][0]["partidos"][0]["dia"] = "2006-07-15"
	_expect_error(_torneo_errors(mal, "apertura", [], true), "un partido después del fin", "fuera del torneo")
	mal["fechas"][0]["partidos"][0]["dia"] = "2005-12-31"
	_expect_error(_torneo_errors(mal, "apertura", [], true), "un partido de otro año", "de 2006")

	mal = t.duplicate(true)
	var semi: Dictionary = mal["playoffs"]["semis"][0]
	semi["avanza"] = _participantes(semi)[1] if semi["avanza"] == _participantes(semi)[0] else _participantes(semi)[0]
	_expect_error(_torneo_errors(mal, "apertura", [], true), "una semifinal con el ganador cambiado", "avanza")

	mal = t.duplicate(true)
	var finalistas := _participantes(mal["playoffs"]["final"])
	mal["campeon"] = finalistas[1] if mal["campeon"] == finalistas[0] else finalistas[0]
	_expect_error(_torneo_errors(mal, "apertura", [], true), "un campeón que perdió la final", "campeon")

	# Un club último de su grupo en los cuartos.
	mal = t.duplicate(true)
	var pts_de := {}
	for fila in mal["tabla"]:
		pts_de[fila["club"]] = fila["pts"]
	var grupo_a: Array = mal["grupos"]["A"].duplicate()
	grupo_a.sort_custom(func(x: String, y: String) -> bool: return pts_de[x] < pts_de[y])
	var cuarto: Dictionary = mal["playoffs"]["cuartos"][0]
	mal["playoffs"]["cuartos"][0] = _llave_sintetica(grupo_a[0], _participantes(cuarto)[1], _rng(9))
	_expect_error(_torneo_errors(mal, "apertura", [], true), "un último de grupo en cuartos", "2 primeros")


func _test_temporada_sintetica() -> void:
	var h := _temporada_sintetica()
	_expect_ok(_history_errors(h), "una temporada sintética completa")

	var mal := h.duplicate(true)
	mal["tabla_acumulada"][0]["pts"] += 1
	_expect_error(_history_errors(mal), "una acumulada que no suma", "tabla_acumulada")
	mal = h.duplicate(true)
	mal["descenso"]["directo"] = mal["tabla_acumulada"][0]["club"]
	_expect_error(_history_errors(mal), "baja el primero de la acumulada", "último")
	mal = h.duplicate(true)
	mal["descenso"]["liguilla"]["se_mantiene"] = not mal["descenso"]["liguilla"]["se_mantiene"]
	_expect_error(_history_errors(mal), "se_mantiene al revés", "se_mantiene")
	mal = h.duplicate(true)
	mal["ascensos"].append("colo_colo")
	_expect_error(_history_errors(mal), "un club de Primera A que asciende", "Primera B")
	mal = h.duplicate(true)
	mal["ascensos"].clear()
	_expect_error(_history_errors(mal), "un archivo completo sin ascensos", "ascensos")
	mal = h.duplicate(true)
	mal["sources"][0]["consultada"] = null
	_expect_error(_history_errors(mal), "un archivo completo con una fuente sin consultar", "consulta")
	mal = h.duplicate(true)
	mal["review"].append({"tipo": "opinion", "donde": "*", "detalle": "prueba"})
	_expect_error(_history_errors(mal), "un tipo de review desconocido", "tipo")


func _test_archivo_pendiente() -> void:
	var torneo := {"inicio": null, "fin": null, "equipos": [], "grupos": {}, "fechas": [], "tabla": [],
			"repechaje": [], "playoffs": {"cuartos": [], "semis": [], "final": null}, "campeon": null,
			"goleadores": []}
	var h := {"_notes": [], "estado": "pendiente", "sources": [_fuente(null)], "apertura": torneo,
			"clausura": torneo.duplicate(true), "tabla_acumulada": [], "descenso": {"directo": null, "liguilla": null},
			"ascensos": [], "review": [{"tipo": "bloqueo", "donde": "*", "detalle": "prueba"}]}
	_expect_ok(_history_errors(h), "un archivo pendiente con el bloqueo en review")
	var mal := h.duplicate(true)
	mal["estado"] = "completo"
	_expect_error(_history_errors(mal), "un archivo vacío que dice estar completo", "vacía")
	mal = h.duplicate(true)
	mal["review"].clear()
	_expect_error(_history_errors(mal), "un archivo pendiente sin explicar", "review")
	mal = h.duplicate(true)
	mal.erase("clausura")
	_expect_error(_history_errors(mal), "un archivo sin clausura", "clausura")


func _rng(semilla: int) -> RandomNumberGenerator:
	var rng := RandomNumberGenerator.new()
	rng.seed = semilla
	return rng


func _partido(local: String, visita: String, goles_local: Variant, goles_visita: Variant) -> Dictionary:
	return {"local": local, "visita": visita, "goles_local": goles_local, "goles_visita": goles_visita, "dia": null,
			"estadio": null}


func _llave(ida: Dictionary, vuelta: Variant, marcador_global: Dictionary, penales: Variant, avanza: String,
		criterio: Variant) -> Dictionary:
	return {"ida": ida, "vuelta": vuelta, "global": marcador_global, "penales": penales, "avanza": avanza,
			"criterio": criterio}


func _fuente(consultada: Variant) -> Dictionary:
	return {"id": "prueba", "titulo": "Fuente de prueba", "url": "https://example.org", "consultada": consultada,
			"uso": "prueba"}


func _llave_sintetica(a: String, b: String, rng: RandomNumberGenerator) -> Dictionary:
	var ida := _partido(a, b, rng.randi_range(0, 3), rng.randi_range(0, 3))
	var vuelta := _partido(b, a, rng.randi_range(0, 3), rng.randi_range(0, 3))
	var ga: int = ida["goles_local"] + vuelta["goles_visita"]
	var gb: int = ida["goles_visita"] + vuelta["goles_local"]
	if ga != gb:
		return _llave(ida, vuelta, {a: ga, b: gb}, null, a if ga > gb else b, null)
	return _llave(ida, vuelta, {a: ga, b: gb}, {a: 4, b: 3}, a, null)


# Una vuelta por el método del círculo (19 clubes + un hueco que marca la fecha libre), tabla calculada,
# 4 grupos y playoffs con los 2 primeros de cada grupo.
func _torneo_sintetico(semilla: int) -> Dictionary:
	var rng := _rng(semilla)
	var ids: Array = league.get_teams("Primera A").map(func(t: Dictionary) -> String: return t["id"]).slice(0, CLUBES)
	var slots: Array = ids.duplicate()
	slots.append("")
	var fechas: Array = []
	for r in FECHAS:
		var f := {"numero": r + 1, "libre": "", "partidos": []}
		for i in slots.size():
			var j: int = slots.size() - 1 - i
			if j <= i:
				break
			var a: String = slots[i]
			var b: String = slots[j]
			if a == "" or b == "":
				f["libre"] = b if a == "" else a
				continue
			var local: String = a if (r + i) % 2 == 0 else b
			var visita: String = b if local == a else a
			f["partidos"].append(_partido(local, visita, rng.randi_range(0, 3), rng.randi_range(0, 3)))
		fechas.append(f)
		slots.insert(1, slots.pop_back())

	var calc := _tabla_desde(fechas)
	var tabla: Array = []
	for id in ids:
		var fila: Dictionary = calc[id].duplicate()
		fila.erase("sin_resultado")
		fila["club"] = id
		tabla.append(fila)
	tabla.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["pts"] > y["pts"])
	var pts_de := {}
	for fila in tabla:
		pts_de[fila["club"]] = fila["pts"]

	var grupos := {"A": ids.slice(0, 5), "B": ids.slice(5, 10), "C": ids.slice(10, 15), "D": ids.slice(15, CLUBES)}
	var orden := {}
	for g in grupos:
		var miembros: Array = grupos[g].duplicate()
		miembros.sort_custom(func(x: String, y: String) -> bool: return pts_de[x] > pts_de[y])
		orden[g] = miembros
	var cuartos: Array = []
	for cruce in [["A", "B"], ["B", "A"], ["C", "D"], ["D", "C"]]:
		cuartos.append(_llave_sintetica(orden[cruce[0]][0], orden[cruce[1]][1], rng))
	var semis: Array = [_llave_sintetica(cuartos[0]["avanza"], cuartos[2]["avanza"], rng),
			_llave_sintetica(cuartos[1]["avanza"], cuartos[3]["avanza"], rng)]
	var la_final := _llave_sintetica(semis[0]["avanza"], semis[1]["avanza"], rng)
	return {"inicio": "2006-01-01", "fin": "2006-12-31", "equipos": ids, "grupos": grupos, "fechas": fechas,
			"tabla": tabla, "repechaje": [], "playoffs": {"cuartos": cuartos, "semis": semis, "final": la_final},
			"campeon": la_final["avanza"], "goleadores": [{"nombre": "Goleador sintético", "club": la_final["avanza"],
			"goles": 10}]}


func _temporada_sintetica() -> Dictionary:
	var apertura := _torneo_sintetico(1)
	var clausura := _torneo_sintetico(2)
	var acumulada: Array = []
	var suma := _sumar_tablas(apertura["tabla"], clausura["tabla"])
	for club in suma:
		var fila: Dictionary = suma[club]
		fila["club"] = club
		acumulada.append(fila)
	acumulada.sort_custom(func(x: Dictionary, y: Dictionary) -> bool: return x["pts"] > y["pts"])
	var penultimo: String = acumulada[-2]["club"]
	var primera_b: Array = league.get_teams("Primera B")
	var llave := _llave_sintetica(penultimo, primera_b[0]["id"], _rng(3))
	var se_mantiene: bool = llave["avanza"] == penultimo
	var ascensos: Array = [primera_b[1]["id"]]
	if not se_mantiene:
		ascensos.append(primera_b[0]["id"])
	return {"_notes": [], "estado": "completo", "sources": [_fuente("2026-10-27")], "apertura": apertura,
			"clausura": clausura, "tabla_acumulada": acumulada,
			"descenso": {"directo": acumulada[-1]["club"],
					"liguilla": {"club": penultimo, "llave": llave, "se_mantiene": se_mantiene}},
			"ascensos": ascensos, "review": []}
