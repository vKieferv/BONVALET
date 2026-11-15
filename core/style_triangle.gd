class_name StyleTriangle
extends RefCounted

# D-49 (T-18): el triángulo de estilos (piedra-papel-tijera de a tres). La tabla vive en data/estilos.json:
# `vence_a` (estilo → el estilo al que vence), `puntos` (N) y `activo` (el interruptor). Lógica pura: el motor
# la consulta desde chance_breakdown; nada más sabe de ventajas.

const PATH := "res://data/estilos.json"

static var _cache: Dictionary = {}
static var override_activo := -1   # -1 = lo que diga el JSON; 0 = apagado; 1 = encendido (pruebas y laboratorio)
static var override_puntos := -1.0  # >= 0: N distinto al del JSON (laboratorio)


static func tabla() -> Dictionary:
	if _cache.is_empty():
		var f := FileAccess.open(PATH, FileAccess.READ)
		_cache = JSON.parse_string(f.get_as_text())
	return _cache


static func activo() -> bool:
	if override_activo >= 0:
		return override_activo == 1
	return bool(tabla().get("activo", true))


# N en puntos de probabilidad (0.06 = 6).
static func puntos() -> float:
	if override_puntos >= 0.0:
		return override_puntos
	return float(tabla().get("puntos", 6)) / 100.0


static func vence_a() -> Dictionary:
	return tabla().get("vence_a", {})


# +N si `mio` vence a `suyo`, −N si `suyo` vence a `mio`, 0 en cualquier otro caso (incluye Directo y Kamikaze).
# `n` < 0 usa el valor de la tabla.
static func ventaja(mio: String, suyo: String, n: float = -1.0) -> float:
	if mio == "" or suyo == "" or mio == suyo:
		return 0.0
	var v := vence_a()
	var pts := puntos() if n < 0.0 else n
	if v.get(mio, "") == suyo:
		return pts
	if v.get(suyo, "") == mio:
		return -pts
	return 0.0


# El estilo que vence al rival, "" si el rival no es del triángulo.
static func contra(rival: String) -> String:
	for k: String in vence_a():
		if vence_a()[k] == rival:
			return k
	return ""


# Texto de la previa: "Contragolpe · te conviene Catenaccio"; vacío si no hay ventaja que buscar (rival fuera del
# triángulo o apagado). Si ya juegas con el estilo que le gana, dice que lo tienes a favor.
static func aviso(rival: String, mio: String) -> String:
	if not activo() or contra(rival) == "":
		return ""
	var ideal := contra(rival)
	if mio == ideal:
		return "%s · tu estilo le gana" % rival
	if ventaja(mio, rival, 1.0) < 0.0:
		return "%s · te conviene %s (con %s sufres)" % [rival, ideal, mio]
	return "%s · te conviene %s" % [rival, ideal]
