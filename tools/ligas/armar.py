# Ligas de Sudamérica 2006-2026 (referencia de uso propio, no para el juego). Paso 3, sin red:
# arma un JSON por liga y año calendario con los clubes y sus jugadores (nombre, posición estimada y
# edad al 1 de julio) desde out/temporadas.json, out/jugadores.json.gz (Wikidata) y, si está,
# out/wikipedia.json.gz (fichas de en.wikipedia, que cubren los años recientes).
#   python tools/ligas/armar.py tools/ligas/out tools/ligas/datos
import gzip
import json
import os
import re
import sys

OUT = sys.argv[1] if len(sys.argv) > 1 else "tools/ligas/out"
DEST = sys.argv[2] if len(sys.argv) > 2 else "tools/ligas/datos"
FIRST, LAST = 2006, 2026
NAMES = {"brasil": "Campeonato Brasileiro Série A", "argentina": "Primera División de Argentina",
         "chile": "Primera División de Chile"}
LABEL_LANG = {"brasil": ("pt", "es", "en"), "argentina": ("es", "en", "pt"), "chile": ("es", "en", "pt")}
# Temporadas que no son el campeonato (goleadores, desempates, finales sueltas, temporadas de todas las divisiones).
NOT_LEAGUE = re.compile(r"goleador|desempate|final del|máxima|maxima|del fútbol chileno|del futbol chileno", re.I)
POSITIONS = [  # (palabra en la etiqueta en inglés de P413, línea), gana la primera que calce
    ("goalkeeper", "POR"), ("centre-back", "DEF"), ("center-back", "DEF"), ("back", "DEF"), ("defender", "DEF"), ("sweeper", "DEF"), ("libero", "DEF"),
    ("stopper", "DEF"), ("defensive midfielder", "MED"), ("midfielder", "MED"), ("wing half", "MED"),
    ("playmaker", "MED"), ("winger", "DEL"), ("forward", "DEL"), ("striker", "DEL"), ("attacker", "DEL"),
]


def participants(s):
    """Clubes de una temporada: la tabla de posiciones si la hay; si no, los más enlazados hasta el
    mayor salto en la cantidad de enlaces (los que juegan salen en tablas y resultados)."""
    tables = [v for v in (s.get("table") or {}).values() if len(v) >= 10]
    if tables:
        return sorted(max(tables, key=len)), "tabla"
    ranked = sorted(((max(v.values()), q) for q, v in s["clubs"].items()), reverse=True)
    if len(ranked) < 10:
        return [], None
    best, cut = 0, None
    for k in range(10, min(30, len(ranked) - 1) + 1):
        hi, lo = ranked[k - 1][0], ranked[k][0] if k < len(ranked) else 0
        if hi >= 3 and hi / max(lo, 1) > best:
            best, cut = hi / max(lo, 1), k
    if cut is None or best < 2:
        return [], None
    return sorted(q for _, q in ranked[:cut]), "enlaces"


def line_of(pos):
    for label in pos:
        l = label.lower()
        for word, line in POSITIONS:
            if word in l:
                return line
    return None


def age_from_birth(birth, year):
    y, m, d = birth
    return year - y - (1 if (m, d) > (7, 1) else 0)


def wiki_name(title):
    return re.sub(r"\s*\([^)]*\)$", "", title)


def age_in(dobs, year):
    """Edad al 1 de julio y si es aproximada (sin día o con fechas que se contradicen)."""
    ages = set()
    approx = False
    for d in dobs:
        value, prec = d.split("/")
        y, m, dd = int(value[:4]), int(value[5:7]), int(value[8:10])
        if int(prec) >= 11:
            ages.add(year - y - (1 if (m, dd) > (7, 1) else 0))
        else:
            ages.add(year - y)
            approx = True
    if not ages:
        return None, False
    return min(ages), approx or len(ages) > 1


def in_year(st, year):
    """Si una membresía (jugador, inicio, prec, fin, prec, préstamo) incluye el año, y si es estimado."""
    s = int(st[1][:4]) if st[1] else None
    e = int(st[3][:4]) if st[3] else None
    if s is not None and e is not None:
        return s <= year <= e, False
    if s is not None:  # sin fin: el año en que llegó; si llegó desde 2023, hasta hoy (plantel actual)
        return year == s or (s >= 2023 and year >= s), year != s
    if e is not None:  # sin inicio: el año en que se fue
        return year == e, False
    return False, False


def main():
    temporadas = json.load(open(os.path.join(OUT, "temporadas.json"), encoding="utf-8"))
    with gzip.open(os.path.join(OUT, "jugadores.json.gz"), "rt", encoding="utf-8") as f:
        data = json.load(f)
    clubs_info = temporadas["clubs"]
    # Membresías por club: (clave del jugador, desde, hasta, estimada, fuente).
    stints = {}
    for club, sts in data["clubs"].items():
        for st in sts:
            stints.setdefault(club, []).append(("wd", st))
    wiki = {}
    path = os.path.join(OUT, "wikipedia.json.gz")
    if os.path.exists(path):
        with gzip.open(path, "rt", encoding="utf-8") as f:
            wiki = json.load(f)["players"]
        for title, w in wiki.items():
            for club, a, b, loan in w["rows"]:
                stints.setdefault(club, []).append(("wp", (title, a, min(b, LAST))))
    resumen = {}
    for country, seasons in temporadas["seasons"].items():
        langs = LABEL_LANG[country]
        by_year = {}
        for s in seasons:
            if NOT_LEAGUE.search(s.get("label") or ""):
                continue
            teams, how = participants(s)
            for y in s["years"]:
                if FIRST <= y <= LAST and teams:
                    for q in teams:
                        by_year.setdefault(y, {}).setdefault(q, set()).add((s.get("label") or s["qid"], how))
        resumen[country] = {}
        for year in range(FIRST, LAST + 1):
            equipos = []
            for club, seen in sorted(by_year.get(year, {}).items()):
                info = clubs_info.get(club, {})
                name = next((info.get(l) for l in langs if info.get(l)), club)
                players = {}
                for kind, st in stints.get(club, []):
                    if kind == "wd":
                        ok, estimated = in_year(st, year)
                        key = st[0]
                        p = data["players"].get(key)
                        if not ok or p is None:
                            continue
                        age, approx = age_in(p["dob"], year)
                        name = next((p.get(l) for l in langs if p.get(l)), key)
                        line = line_of(p["pos"])
                    else:
                        title, a, b = st
                        if not (a <= year <= b):
                            continue
                        w = wiki[title]
                        key = w.get("qid") or title
                        p = data["players"].get(key)
                        estimated = False
                        if p:
                            age, approx = age_in(p["dob"], year)
                            name = next((p.get(l) for l in langs if p.get(l)), wiki_name(title))
                            line = line_of(p["pos"]) or line_of([w["position"]])
                        else:
                            age, approx = (age_from_birth(w["birth"], year), False) if w.get("birth") else (None, False)
                            name = wiki_name(title)
                            line = line_of([w["position"]])
                    if age is not None and not (14 <= age <= 45):
                        continue
                    prev = players.get(key)
                    if prev is not None:
                        prev["fuente"] = sorted(set(prev["fuente"]) | {"wikidata" if kind == "wd" else "wikipedia"})
                        if prev.get("membresia_estimada") and not estimated:
                            del prev["membresia_estimada"]
                        if prev["posicion"] is None:
                            prev["posicion"] = line
                        if prev["edad"] is None and age is not None:
                            prev["edad"] = age
                        continue
                    row = {"nombre": name, "posicion": line, "edad": age, "wikidata": key if key.startswith("Q") else None,
                           "fuente": ["wikidata" if kind == "wd" else "wikipedia"]}
                    if approx:
                        row["edad_aproximada"] = True
                    if estimated:
                        row["membresia_estimada"] = True
                    players[key] = row
                order = {"POR": 0, "DEF": 1, "MED": 2, "DEL": 3, None: 4}
                rows = sorted(players.values(), key=lambda r: (order[r["posicion"]], r["nombre"]))
                equipos.append({"club": name, "wikidata": club, "temporadas": sorted({l for l, _ in seen}),
                                "clubes_por": sorted({h for _, h in seen}), "jugadores_encontrados": len(rows),
                                "jugadores": rows})
            equipos.sort(key=lambda e: e["club"])
            doc = {"liga": NAMES[country], "pais": country, "año": year,
                   "fuente": "Wikidata (CC0) y en.wikipedia; instantánea del 27-oct-2026 (tools/ligas/)",
                   "notas": ["Datos de referencia de uso propio, no para el juego.",
                             "Clubes: los de las temporadas del campeonato que tocan este año calendario (tabla de posiciones de Wikipedia o, si no hay, los clubes más enlazados desde el artículo de la temporada).",
                             "Jugadores: membresías P54 de Wikidata que incluyen el año y años por club de la ficha del jugador en en.wikipedia (fuente dice cuál). En Wikidata sin fecha de fin cuenta el año en que llegó (o hasta hoy si llegó desde 2023): membresia_estimada. Los años de la ficha son por temporada, así que un jugador que cambió de club a mitad de año puede salir en los dos. Los planteles pueden estar incompletos; jugadores_encontrados dice cuántos hay.",
                             "posicion: línea estimada desde P413 (POR, DEF, MED, DEL; null si Wikidata no la tiene). edad: al 1 de julio; edad_aproximada si la fecha de nacimiento no tiene día o tiene fechas distintas."],
                   "equipos": equipos}
            path = os.path.join(DEST, country, "%d.json" % year)
            os.makedirs(os.path.dirname(path), exist_ok=True)
            with open(path, "w", encoding="utf-8") as f:
                json.dump(doc, f, ensure_ascii=False, indent=1)
            counts = [e["jugadores_encontrados"] for e in equipos]
            resumen[country][year] = {"clubes": len(equipos), "jugadores": sum(counts),
                                      "mediana_por_club": sorted(counts)[len(counts) // 2] if counts else 0,
                                      "clubes_con_menos_de_15": sum(1 for c in counts if c < 15)}
    with open(os.path.join(DEST, "cobertura.json"), "w", encoding="utf-8") as f:
        json.dump(resumen, f, ensure_ascii=False, indent=1)
    for country, years in resumen.items():
        print(country)
        for y, r in years.items():
            print("  %d  clubes %2d  jugadores %4d  mediana/club %2d  clubes<15 %2d" % (
                y, r["clubes"], r["jugadores"], r["mediana_por_club"], r["clubes_con_menos_de_15"]))


if __name__ == "__main__":
    main()
