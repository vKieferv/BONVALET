# T-08: arma los planteles 2006 desde la instantánea de Wikidata y es.wikipedia (tools/t08/out, de
# fetch.py y fetch_wiki.py). Elige 18 jugadores por club con reglas fijas y calcula role, stamina_max
# y skill_rating con la fórmula de _notes. Determinista: misma instantánea, mismo resultado. La
# instantánea que dio data/squads_2006.json está en el historial de la rama tarea/t-08-planteles-2006
# (commit a8907bc, "instantánea de Wikidata y es.wikipedia"); una nueva puede variar si las fuentes
# cambiaron.
#   python tools/t08/build.py tools/t08/out            -> informe en pantalla
#   python tools/t08/build.py tools/t08/out --write    -> además reescribe lo de T-08 en data/squads_2006.json
import json
import os
import re
import sys
import unicodedata

OUT = sys.argv[1] if len(sys.argv) > 1 else "tools/t08/out"
WRITE = "--write" in sys.argv
SQUADS = "data/squads_2006.json"
TEAMS = "data/teams_chile_2006.json"
CLUBS = ["cobreloa", "audax_italiano", "huachipato", "union_espanola", "everton", "santiago_wanderers",
         "universidad_de_concepcion", "o_higgins", "cobresal", "palestino", "deportes_antofagasta",
         "deportes_la_serena", "coquimbo_unido", "deportes_puerto_montt", "rangers", "santiago_morning"]
REF = (2006, 7, 1)                # edad al 1 de julio de 2006
SEASON = ((2006, 1, 27), (2006, 12, 31))  # Apertura 27-ene a Clausura dic.
TARGET = {"POR": 2, "DEF": 6, "MED": 6, "DEL": 4}
LINES = {"POR": "POR", "DFC": "DEF", "LAT": "DEF", "MCD": "MED", "MCO": "MED", "EXT": "MED", "DEL": "DEL"}
LOAN = "Q2914547"  # calificador P1642 "préstamo"
ISO_TO_FIFA = {"CHL": "CHI", "PRY": "PAR", "URY": "URU", "DEU": "GER", "NLD": "NED", "PRT": "POR",
               "HRV": "CRO", "CHE": "SUI", "GRC": "GRE", "DNK": "DEN", "BGR": "BUL", "ZAF": "RSA",
               "SVN": "SVN", "LBN": "LIB", "PSE": "PLE", "GTM": "GUA", "HND": "HON", "SLV": "SLV",
               "CRI": "CRC", "TTO": "TRI", "HTI": "HAI", "NGA": "NGA", "DZA": "ALG", "MAR": "MAR"}
# País en el texto de la ficha de es.wikipedia (sin tildes) -> código FIFA.
COUNTRY_WORDS = [("chile", "CHI"), ("argentin", "ARG"), ("urugua", "URU"), ("paragua", "PAR"),
                 ("bolivi", "BOL"), ("peru", "PER"), ("colombi", "COL"), ("ecuador", "ECU"),
                 ("venezol", "VEN"), ("brasil", "BRA"), ("mexic", "MEX"), ("espan", "ESP"), ("itali", "ITA"),
                 ("panam", "PAN"), ("costa rica", "CRC"), ("hondur", "HON"), ("estados unidos", "USA")]
MONTHS = {"enero": 1, "febrero": 2, "marzo": 3, "abril": 4, "mayo": 5, "junio": 6, "julio": 7, "agosto": 8,
          "septiembre": 9, "setiembre": 9, "octubre": 10, "noviembre": 11, "diciembre": 12}
ACCENTS = {"á": "a", "é": "e", "í": "i", "ó": "o", "ú": "u", "ü": "u", "ñ": "n"}


def load(name):
    with open(os.path.join(OUT, name), encoding="utf-8") as f:
        return json.load(f)


def slug(text):
    s = text.lower()
    for k, v in ACCENTS.items():
        s = s.replace(k, v)
    out = ""
    for ch in s:
        if ("a" <= ch <= "z") or ("0" <= ch <= "9"):
            out += ch
        elif not out.endswith("_"):
            out += "_"
    return out.strip("_")


def norm(s):
    return unicodedata.normalize("NFKD", s or "").encode("ascii", "ignore").decode().lower()


def tdate(v, prec):
    """Fecha de Wikidata -> (año, mes, día) con lo que no se sabe en None según la precisión."""
    if not v:
        return None
    y, m, d = int(v[:4]), int(v[5:7]), int(v[8:10])
    prec = int(prec or 9)
    return (y, m if prec >= 10 else None, d if prec >= 11 else None)


def lo(t):
    return (t[0], t[1] or 1, t[2] or 1)


def hi(t):
    return (t[0], t[1] or 12, t[2] or 31)


def covers_season(start, end):
    """Membresía con inicio y fin, y que se cruza con la temporada 2006 (con la precisión que haya)."""
    if start is None or end is None:
        return False
    return lo(start) <= SEASON[1] and hi(end) >= SEASON[0]


def age_at_ref(y, m, d):
    return REF[0] - y - (1 if (m, d) > (REF[1], REF[2]) else 0)


def is_national(m):
    return m.get("national") in (True, "true")


def is_youth_team(label):
    n = norm(label)
    return any(w in n for w in ("sub-", "sub ", "under", "u-1", "u-2", "u1", "u2", "juvenil", "olimpic", "olympic"))


ROLE_WORDS = [  # (palabra en la etiqueta en inglés, rol, específico)
    ("goalkeeper", "POR", True),
    ("centre-back", "DFC", True), ("center-back", "DFC", True), ("centre back", "DFC", True),
    ("sweeper", "DFC", True), ("libero", "DFC", True), ("stopper", "DFC", True),
    ("full-back", "LAT", True), ("fullback", "LAT", True), ("wing-back", "LAT", True),
    ("wing back", "LAT", True), ("left-back", "LAT", True), ("right-back", "LAT", True),
    ("defensive midfielder", "MCD", True), ("holding midfielder", "MCD", True),
    ("central midfielder", "MCD", True), ("attacking midfielder", "MCO", True), ("playmaker", "MCO", True),
    ("winger", "EXT", True), ("wing half", "EXT", True), ("wide midfielder", "EXT", True), ("left midfielder", "EXT", True),
    ("right midfielder", "EXT", True),
    ("centre-forward", "DEL", True), ("center forward", "DEL", True), ("striker", "DEL", True),
    ("second striker", "DEL", True),
    ("defender", "DFC", False), ("midfielder", "MCD", False), ("forward", "DEL", False),
    ("attacker", "DEL", False),
]
ROLE_ORDER = ["POR", "DFC", "LAT", "MCD", "MCO", "EXT", "DEL"]

# Posición escrita en la ficha de es.wikipedia (sin tildes). Gana la primera regla que calce con cada
# parte del texto, así "volante central" es MCD antes de que "central" la haga defensa.
WIKI_ROLE_WORDS = [
    (("arquero", "guardameta", "portero", "golero", "guardavalla"), "POR", True),
    (("lateral", "carrilero"), "LAT", True),
    (("contencion", "volante central", "mediocentro", "pivote", "volante defensivo", "mediocampista defensivo",
      "centrocampista defensivo", "volante mixto"), "MCD", True),
    (("ofensivo", "enganche", "mediapunta", "media punta", "creativo", "armador", "organizador"), "MCO", True),
    (("extremo", "puntero", "alero", "volante por", "volante izquierdo", "volante derecho"), "EXT", True),
    (("defensa central", "defensor central", "marcador central", "zaguero", "libero", "stopper", "central"), "DFC", True),
    (("delantero", "centrodelantero", "ariete", "punta", "atacante", "goleador"), "DEL", True),
    (("defensa", "defensor"), "DFC", False),
    (("centrocampista", "mediocampista", "volante", "medio"), "MCD", False),
]


def role_of(positions):
    """Rol del juego desde P413: (rol, línea, específico). Arquero si alguna posición lo es; si no, la
    línea con más votos y, dentro de ella, la posición específica (la genérica solo si no hay otra).
    Empates: ROLE_ORDER."""
    found = []
    for p in positions:
        label = norm(p.get("en") or p.get("es") or "")
        for word, role, specific in ROLE_WORDS:
            if word in label:
                found.append((role, specific))
                break
    if not found:
        return None, None, False
    if any(r == "POR" for r, _ in found):
        return "POR", "POR", True
    votes = {}
    for r, _ in found:
        votes[LINES[r]] = votes.get(LINES[r], 0) + 1
    line = sorted(votes, key=lambda l: (-votes[l], ["DEF", "MED", "DEL"].index(l)))[0]
    in_line = [x for x in found if LINES[x[0]] == line]
    specific = [r for r, s in in_line if s]
    pool = specific or [r for r, _ in in_line]
    role = sorted(pool, key=ROLE_ORDER.index)[0]
    position = line
    if role == "EXT" and any(r == "DEL" for r, _ in found):
        position = "DEL"
    return role, position, bool(specific)


def fifa(c):
    if c.get("fifa"):
        return c["fifa"]
    iso = c.get("iso3")
    return ISO_TO_FIFA.get(iso, iso) if iso else None


def live(values):
    """Valores no deprecados; si hay preferidos, solo esos."""
    vals = [v for v in values if v.get("rank") != "DeprecatedRank"]
    pref = [v for v in vals if v.get("rank") == "PreferredRank"]
    return pref or vals


# ------------------------------------------------------------------ Ficha de es.wikipedia

def clean(text):
    """Texto legible de un valor de la ficha: sin comentarios, refs ni plantillas de formato."""
    text = re.sub(r"<!--.*?-->", "", text or "", flags=re.S)
    text = re.sub(r"<ref[^>]*/>|<ref.*?</ref>", "", text, flags=re.S | re.I)
    text = re.sub(r"\[\[(?:[^\]|]*\|)?([^\]]*)\]\]", r"\1", text)
    return text


def ficha_field(ficha, *names):
    """Valor crudo del primer campo de la ficha con alguno de esos nombres (o None si está vacío)."""
    if not ficha:
        return None
    for name in names:
        m = re.search(r"\|\s*%s\s*=(.*?)(?=\n\s*\||\n\}\}|\Z)" % re.escape(name), ficha, re.S | re.I)
        if m and clean(m.group(1)).strip():
            return m.group(1).strip()
    return None


def wiki_roles(ficha):
    """[(rol, específico)] de la posición escrita en la ficha, en el orden en que aparecen."""
    value = ficha_field(ficha, "posición", "posicion")
    if not value:
        return []
    out = []
    for part in re.split(r",|/|;|\s+y\s+|\s+o\s+|<br\s*/?>|\n|\(|\)", norm(clean(value))):
        part = part.strip()
        for words, role, specific in WIKI_ROLE_WORDS:
            if any(w in part for w in words):
                out.append((role, specific))
                break
    return out


def wiki_birth(ficha):
    """(año, mes, día) de la fecha de nacimiento de la ficha, o None."""
    value = ficha_field(ficha, "fecha nacimiento", "fecha de nacimiento", "fechanacimiento", "nacimiento")
    if not value:
        return None
    m = re.search(r"\{\{\s*fecha[^|}]*\|\s*([^|}]+?)\s*\|\s*([^|}]+?)\s*\|\s*([^|}]+?)\s*[|}]", value, re.I)
    parts = None
    if m:
        a, b, c = (norm(x).strip() for x in m.groups())
        parts = (c, b, a) if len(c) == 4 and c.isdigit() else ((a, b, c) if len(a) == 4 and a.isdigit() else None)
    else:
        m = re.search(r"(\d{1,2})\s+de\s+([a-z]+)\s+de\s+(\d{4})", norm(clean(value)))
        if m:
            parts = (m.group(3), m.group(2), m.group(1))
    if not parts:
        return None
    y, mo, d = parts
    mo = int(mo) if mo.isdigit() else MONTHS.get(mo)
    if not (y.isdigit() and d.isdigit() and mo):
        return None
    return int(y), int(mo), int(d)


def wiki_country_text(ficha, *fields):
    return " ".join(norm(clean(ficha_field(ficha, f) or "")) + " " + " ".join(
        re.findall(r"\{\{\s*selb?\s*\|\s*([^|}]+)", ficha_field(ficha, f) or "", re.I)) for f in fields)


def countries_in(text):
    """Códigos FIFA mencionados en un texto de la ficha (por nombre de país o código en {{selb|XXX}})."""
    found = {code for word, code in COUNTRY_WORDS if word in text}
    found |= {c.upper() for c in re.findall(r"\b([a-z]{3})\b", text) if c.upper() in {code for _, code in COUNTRY_WORDS}}
    return found


# ------------------------------------------------------------------ Hechos de un jugador

def facts(q, pdata, ficha):
    """Hechos de un jugador. Devuelve (dict, notas para review, problemas que lo dejan fuera)."""
    notes = []
    blocking = []
    name = (pdata.get("labels") or {}).get("es") or (pdata.get("labels") or {}).get("en")

    # Edad: Wikidata; la ficha de es.wikipedia desempata o completa.
    dobs = sorted({(d["value"][:10], d["prec"]) for d in live(pdata.get("dob", []))})
    wb = wiki_birth(ficha)
    exact = [(int(v[:4]), int(v[5:7]), int(v[8:10])) for v, prec in dobs if prec >= 11]
    ages = {age_at_ref(*t) for t in exact} | ({None} if any(prec < 11 for _, prec in dobs) else set())
    shown = ", ".join(v[:10] if prec >= 11 else v[:4] for v, prec in dobs)
    age = None
    if len(ages) == 1 and None not in ages:
        age = next(iter(ages))
        if len(dobs) > 1:
            notes.append("Wikidata registra %d fechas de nacimiento (%s); todas dan %d años al 1-jul-2006" % (len(dobs), shown, age))
    elif wb and (not dobs or wb in exact or all(prec < 11 and int(v[:4]) == wb[0] for v, prec in dobs)):
        age = age_at_ref(*wb)
        notes.append("fecha de nacimiento %02d-%02d-%d según es.wikipedia (Wikidata: %s)" % (wb[2], wb[1], wb[0], shown or "sin fecha"))
    elif not dobs:
        notes.append("sin fecha de nacimiento: edad null")
    else:
        notes.append("fecha de nacimiento dudosa o sin día (%s): edad null" % shown)

    # Nacionalidad: P1532, P27 única, la selección que defendió (Wikidata o ficha) o la de la ficha.
    sport = {fifa(c) for c in live(pdata.get("sport_country", [])) if fifa(c)}
    cits = {fifa(c): c for c in live(pdata.get("citizenship", [])) if fifa(c)}
    nat = None
    if len(sport) == 1:
        nat = next(iter(sport))
    elif len(cits) == 1:
        nat = next(iter(cits))
    elif len(cits) > 1:
        teams_nat = [norm(m.get("tl")) for m in live(pdata.get("memberships", [])) if is_national(m) and m.get("tl")]
        played = sorted(code for code, c in cits.items() if c.get("label") and any(norm(c["label"]) in t for t in teams_nat))
        on_ficha = sorted(countries_in(wiki_country_text(ficha, "selección", "seleccion", "nac_deportiva")) & set(cits))
        if len(played) == 1:
            nat = played[0]
            notes.append("ciudadanías %s; se usa %s, la selección que defendió" % (", ".join(sorted(cits)), nat))
        elif len(on_ficha) == 1:
            nat = on_ficha[0]
            notes.append("ciudadanías %s; se usa %s, la selección o nacionalidad deportiva de su ficha en es.wikipedia" % (
                ", ".join(sorted(cits)), nat))
        else:
            blocking.append("varias nacionalidades (%s) y ninguna selección que las desempate" % ", ".join(sorted(cits)))
    else:
        on_ficha = sorted(countries_in(wiki_country_text(ficha, "nacionalidad")))
        if len(on_ficha) == 1:
            nat = on_ficha[0]
            notes.append("sin nacionalidad en Wikidata; %s según su ficha en es.wikipedia" % nat)
        else:
            blocking.append("sin nacionalidad")

    # Posición: P413; la ficha afina un rol genérico de la misma línea o lo da si no hay P413.
    role, position, specific = role_of(pdata.get("positions", []))
    wroles = wiki_roles(ficha)
    if role is None and wroles:
        role = wroles[0][0]
        position = "DEL" if role == "EXT" and any(r == "DEL" for r, _ in wroles) else LINES[role]
        notes.append("sin posición en Wikidata; %s según su ficha en es.wikipedia" % role)
    elif role not in (None, "POR") and not specific:
        for r, s in wroles:
            if s and r != role and (LINES[r] == LINES[role] or (r == "EXT" and position in ("MED", "DEL"))):
                role = r
                break
    if role is None:
        blocking.append("sin posición (P413 ni ficha)")

    senior = youth = False
    for m in live(pdata.get("memberships", [])):
        if not is_national(m):
            continue
        st = tdate(m.get("start"), m.get("startPrec"))
        if st is None or st[0] > 2006:
            continue
        if is_youth_team(m.get("tl") or ""):
            youth = True
        else:
            senior = True
    return {"qid": q, "name": name, "age": age, "nationality": nat, "role": role, "position": position,
            "senior": senior, "youth": youth, "sitelinks": int(pdata.get("sitelinks") or 0),
            "eswiki": bool(pdata.get("eswiki"))}, notes, blocking


def club_stints(pdata, club_qids):
    """Membresías del jugador (de su ficha completa) a cualquiera de los qids del club."""
    out = []
    for m in live(pdata.get("memberships", [])):
        if m.get("team") in club_qids:
            out.append((tdate(m.get("start"), m.get("startPrec")), tdate(m.get("end"), m.get("endPrec")), m))
    return out


# Clubes en la trayectoria de es.wikipedia: palabras del enlace o del texto, y palabras que lo
# descartan (homónimos de otros países).
WIKI_CLUBS = {
    "cobreloa": (["cobreloa"], []), "audax_italiano": (["audax"], []), "huachipato": (["huachipato"], []),
    "union_espanola": (["union espanola"], []), "everton": (["everton"], ["football club", "f. c.", "fc"]),
    "santiago_wanderers": (["santiago wanderers"], []), "universidad_de_concepcion": (["universidad de concepcion"], []),
    "o_higgins": (["higgins"], ["instituto"]), "cobresal": (["cobresal"], []), "palestino": (["palestino"], []),
    "deportes_antofagasta": (["antofagasta"], []), "deportes_la_serena": (["la serena"], []),
    "coquimbo_unido": (["coquimbo"], []), "deportes_puerto_montt": (["puerto montt"], []),
    "rangers": (["rangers"], ["glasgow", "football club", "queens", "fc"]), "santiago_morning": (["santiago morning"], []),
}


def wiki_career(ficha):
    """[(texto del club, año inicio, año fin)] desde la trayectoria de la ficha, en orden."""
    if not ficha:
        return None
    text = "\n".join(m.group(1) for m in re.finditer(
        r"\|\s*(?:equipos|clubesanteriores|clubesanterioresjug)\s*=(.*?)(?=\n\s*\|\s*[a-zñ_ ]+\s*=|\Z)", ficha, re.S | re.I))
    out = []
    for line in re.split(r"\n|<br\s*/?>", text):
        link = re.search(r"\[\[([^\]|]+)(?:\|([^\]]+))?\]\]", line)
        years = re.search(r"\((\d{4})(?:\s*[-–]\s*(\d{2,4}|presente|actualidad)?)?\)", line)
        if not link or not years:
            continue
        a = int(years.group(1))
        b = years.group(2)
        if b is None:
            end = a
        elif not b.isdigit():
            end = 9999
        elif len(b) == 2:
            end = int(str(a)[:2] + b)
        else:
            end = int(b)
        out.append((norm(link.group(1)) + " | " + norm(link.group(2) or ""), a, end))
    return out or None


def is_club(txt, club):
    words, bad = WIKI_CLUBS[club]
    return all(w in txt for w in words) and not any(b in txt.split(" | ")[0] for b in bad)


def wiki_says(career, club):
    """True si la trayectoria lo pone en el club en 2006, False si no, None si no hay trayectoria."""
    if career is None:
        return None
    return any(is_club(txt, club) and a <= 2006 <= e for txt, a, e in career)


def wiki_span(career, club):
    """(año inicio, año fin) del último paso por el club que la trayectoria muestra en 2006, o None."""
    span = None
    for txt, a, e in career or []:
        if is_club(txt, club) and a <= 2006 <= e:
            span = (a, e)
    return span


def wiki_last_2006(career, clubs):
    """De varios clubes, el último que la trayectoria muestra en 2006 (el orden de la lista)."""
    last = None
    for txt, a, e in career or []:
        if not (a <= 2006 <= e):
            continue
        for club in clubs:
            if is_club(txt, club):
                last = club
    return last


def final_lineups():
    """Títulos de los artículos enlazados en las alineaciones de las finales 2006 (es.wikipedia)."""
    names = set()
    for page in ("Final_del_Torneo_Apertura_2006_(Chile)", "Final_del_Torneo_Clausura_2006_(Chile)"):
        path = os.path.join(OUT, "wikipedia", page + ".wikitext")
        if not os.path.exists(path):
            continue
        for line in open(path, encoding="utf-8"):
            if re.search(r"\|(?:POR|DEF|MED|DEL)\]\]", line):
                for m in re.finditer(r"\{\{Bandera\|[A-Z]{3}\}\}\s*\[\[([^\]|]+)", line):
                    names.add(m.group(1).strip())
    return names


# ------------------------------------------------------------------ Atributos (fórmula de _notes)

def stamina(role, age):
    base = {"POR": 64, "DFC": 68, "LAT": 74, "MCD": 76, "MCO": 68, "EXT": 76, "DEL": 68}[role]
    if age is None:
        mod = 0
    elif age <= 20:
        mod = 4
    elif age <= 26:
        mod = 2
    elif age <= 30:
        mod = 0
    elif age <= 32:
        mod = -4
    elif age <= 34:
        mod = -8
    else:
        mod = -12
    return max(40, min(100, base + mod))


def skill(level, f, figure):
    base = 50 + 6 * level + 4  # el mismo nivel de club que usa SquadGenerator (Primera A)
    age = f["age"]
    if age is None:
        mod = 0
    elif age <= 18:
        mod = -10
    elif age <= 20:
        mod = -6
    elif age <= 22:
        mod = -2
    elif age <= 25:
        mod = 0
    elif age <= 30:
        mod = 2
    elif age <= 33:
        mod = 0
    else:
        mod = -2
    sel = 6 if f["senior"] else (2 if f["youth"] else 0)
    fame = min(4, f["sitelinks"] // 5)
    return max(40, min(99, base + mod + sel + fame + (8 if figure else 0)))


def support(f, stint_matches):
    return f["sitelinks"] + (3 if f["eswiki"] else 0) + min(stint_matches, 60) / 10.0


# ------------------------------------------------------------------ Selección

def main():
    teams = {t["id"]: t for t in json.load(open(TEAMS, encoding="utf-8"))["teams"]}
    squads = json.loads(strip_t08(open(SQUADS, encoding="utf-8").read()))
    chosen = load("clubs_elegidos.json")
    players = load("jugadores.json")
    figs = load("figuras.json")
    fichas = load("wikipedia/fichas.json")
    careers = {q: wiki_career(v.get("ficha")) for q, v in fichas.items()}
    finals = final_lineups()
    taken = {p["id"] for t in squads["squads"].values() for p in t["players"]}
    taken_names = {norm(p["name"]) for t in squads["squads"].values() for p in t["players"]}
    # ids de las figuras de los clubes que pueden quedar generados (SquadGenerator usa slug(figura)).
    reserved = {t["id"]: slug(t["signature_card"]) for t in teams.values()
                if t.get("signature_card") and t["id"] not in squads["squads"]}

    # 1. Candidatos por club. (a) Membresía P54 con inicio y fin que se cruzan con la temporada 2006.
    #    (b) Membresía P54 sin inicio o sin fin (y lo que tenga, compatible con 2006) que la trayectoria
    #    de su ficha en es.wikipedia pone en 2006: las fechas salen de la ficha.
    cands = {}
    by_wiki_dates = {}
    homes = {}  # qid -> [(club, start, end)]
    for club in CLUBS:
        info = chosen.get(club, {})
        qids = {info.get("qid")} if info.get("qid") else set()
        cands[club] = {}
        by_wiki_dates[club] = set()
        for q, pdata in players.items():
            stints = club_stints(pdata, qids)
            dated = [(st, en, m) for st, en, m in stints if covers_season(st, en)]
            for st, en, m in dated:
                cands[club][q] = cands[club].get(q, 0) + int(float(m.get("matches") or 0))
                homes.setdefault(q, []).append((club, st, en))
            if dated:
                continue
            partial = [m for st, en, m in stints if (st is None or en is None)
                       and (st is None or st[0] <= 2006) and (en is None or en[0] >= 2006)]
            span = wiki_span(careers.get(q), club) if partial else None
            if span:
                cands[club][q] = sum(int(float(m.get("matches") or 0)) for m in partial)
                homes.setdefault(q, []).append((club, (span[0], None, None), (span[1], None, None)))
                by_wiki_dates[club].add(q)
    report = {}
    result = {}
    pending = {}
    # 2. Jugadores en dos clubes del juego en 2006: quedan en el club donde terminaron el año (la
    #    misma convención del Clausura que usa teams_chile_2006.json para DT y figura): la membresía que
    #    sigue después de 2006; si todas terminan en 2006, la que empezó más tarde; si no, el orden de
    #    su trayectoria en es.wikipedia. Empate: fuera.
    owner = {}
    moved = {}
    by_wiki = set()
    for q, hs in homes.items():
        clubs_q = sorted({h[0] for h in hs})
        owner[q] = clubs_q[0]
        if len(clubs_q) == 1:
            continue
        moved[q] = clubs_q
        after = sorted({c for c, st, en in hs if en[0] > 2006})
        if len(after) == 1:
            owner[q] = after[0]
            continue
        if after:
            owner[q] = None
        else:
            latest = max(lo(st) for c, st, en in hs)
            last = sorted({c for c, st, en in hs if lo(st) == latest and st[1] is not None} or
                          {c for c, st, en in hs if lo(st) == latest})
            owner[q] = last[0] if len(last) == 1 else None
        if owner[q] is None:
            owner[q] = wiki_last_2006(careers.get(q), clubs_q)
            if owner[q] is not None:
                by_wiki.add(q)
    for club in CLUBS:
        team = teams[club]
        level = int(team.get("facilities_level", 1))
        figure = team.get("signature_card")
        review = []
        pool = []
        sources = {}
        fig_qids = {m["qid"] for m in figs.get(club, {}).get("matches", [])}
        fig_in = False
        for q, matches in sorted(cands[club].items()):
            pdata = players[q]
            ficha = (fichas.get(q) or {}).get("ficha")
            f, notes, blocking = facts(q, pdata, ficha)
            label = f["name"] or q
            is_fig = figure is not None and q in fig_qids
            tag = "%s (%s%s)" % (label, q, ", figura" if is_fig else "")
            if q in moved:
                others = ", ".join(c for c in moved[q] if c != club)
                if owner.get(q) is None:
                    review.append("%s: en 2006 también en %s y las fechas no dicen dónde terminó el año; fuera de ambos" % (tag, others))
                    continue
                if owner[q] != club:
                    continue
                notes.append("en 2006 también en %s; terminó el año aquí%s" % (
                    others, " según el orden de su trayectoria en es.wikipedia" if q in by_wiki else ""))
            if norm(label) in taken_names:
                loan = any(m.get("loan") == LOAN for st, en, m in club_stints(pdata, {chosen[club]["qid"]}))
                review.append("%s: en 2006 aquí%s, pero ya está en el plantel real de su club" % (tag, " a préstamo" if loan else ""))
                continue
            says = wiki_says(careers.get(q), club)
            if says is False:
                blocking.append("Wikidata lo pone en el club en 2006, pero su trayectoria en es.wikipedia no")
            in_final = (fichas.get(q) or {}).get("title") in finals
            if blocking:
                review.append("%s: %s; queda fuera" % (tag, "; ".join(blocking + notes)))
                continue
            if is_fig:
                fig_in = True
            pool.append((f, support(f, matches) + (5 if says else 0) + (5 if in_final else 0), is_fig, notes))
            sources[q] = (says, in_final, q in by_wiki_dates[club])
        if figure is not None and not fig_in:
            review.append("figura %s: no queda en el plantel con membresía en 2006 (coincidencias por nombre: %s)" % (
                figure, ", ".join(sorted(fig_qids)) or "ninguna"))
        pick = select(pool)
        n_wd = len(cands[club]) - len(by_wiki_dates[club])
        report[club] = {"qid": chosen.get(club, {}).get("qid"), "candidates": len(cands[club]), "usable": len(pool),
                        "dated_wd": n_wd, "dated_wiki": len(by_wiki_dates[club]), "sources": sources,
                        "picked": len(pick) if pick else 0, "review": review}
        if pick is None or (figure is not None and not fig_in):
            missing = max(0, 18 - len(pool))
            pending[club] = ["%d jugadores con membresía en 2006 (%d con fechas de Wikidata y %d fechados por es.wikipedia) y %d utilizables (%s %d para 18): %s" % (
                len(cands[club]), n_wd, len(by_wiki_dates[club]), len(pool), "falta" if missing == 1 else "faltan", missing,
                ", ".join("%s (%s)" % (x[0]["name"], x[0]["qid"]) for x in sorted(pool, key=lambda x: x[0]["name"])))] + \
                review + ["%s (%s): %s" % (x[0]["name"], x[0]["qid"], n) for x in pool for n in x[3]]
            continue
        rows = []
        wiki_dated = []
        for f, sup, is_fig, notes in pick:
            pid = slug(f["name"])
            own = is_fig and reserved.get(club) == pid
            if pid in taken or (pid in reserved.values() and not own):
                pid = "%s_%s" % (pid, club)
            taken.add(pid)
            rows.append({"id": pid, "name": figure if is_fig else f["name"], "age": f["age"],
                         "nationality": f["nationality"], "position": f["position"], "role": f["role"],
                         "stamina_max": stamina(f["role"], f["age"]),
                         "skill_rating": skill(level, f, is_fig), "signature_card_id": None,
                         "wikidata": f["qid"]})
            review.extend("%s: %s" % (pid, n) for n in notes)
            if f["qid"] in by_wiki_dates[club]:
                wiki_dated.append(pid)
        if wiki_dated:
            review.insert(0, "membresía en Wikidata sin fechas, fechada en 2006 por su trayectoria en es.wikipedia: %s" % ", ".join(sorted(wiki_dated)))
        order = ["POR", "DEF", "MED", "DEL"]
        rows.sort(key=lambda r: (order.index(r["position"]) if r["position"] in order else 9, -r["skill_rating"], r["name"]))
        result[club] = {"review": review, "players": rows}
    return squads, result, pending, report


def select(pool):
    """18 por respaldo con cuotas por línea (2/6/6/4), la figura siempre, mín. 2 Sub-21, máx. 6
    extranjeros. None si no se puede."""
    if len(pool) < 18:
        return None
    ranked = sorted(pool, key=lambda x: (-x[1], x[0]["name"]))
    line = lambda x: LINES[x[0]["role"]] if x[0]["role"] in LINES else "MED"
    picked = [x for x in ranked if x[2]]
    for l, n in TARGET.items():
        for x in ranked:
            if sum(1 for y in picked if line(y) == l) >= n:
                break
            if x not in picked and line(x) == l:
                picked.append(x)
    for x in ranked:
        if len(picked) >= 18:
            break
        if x not in picked and not (line(x) == "POR" and sum(1 for y in picked if line(y) == "POR") >= 3):
            picked.append(x)
    if len(picked) < 18:
        return None
    sub21 = lambda x: x[0]["age"] is not None and x[0]["age"] < 21
    foreign = lambda x: x[0]["nationality"] != "CHI"

    def swap_in(x):
        out = [y for y in picked if not y[2] and not sub21(y)]
        same = [y for y in out if line(y) == line(x)] or out
        if not same:
            return False
        worst = min(same, key=lambda y: (y[1], y[0]["name"]))
        picked[picked.index(worst)] = x
        return True

    for x in ranked:
        if sum(1 for y in picked if sub21(y)) >= 2:
            break
        if x not in picked and sub21(x) and not foreign(x):
            swap_in(x)
    for x in ranked:
        if sum(1 for y in picked if sub21(y)) >= 2:
            break
        if x not in picked and sub21(x):
            swap_in(x)
    if sum(1 for y in picked if sub21(y)) < 2:
        return None
    while sum(1 for y in picked if foreign(y)) > 6:
        drop = min((y for y in picked if foreign(y) and not y[2] and not sub21(y)), key=lambda y: (y[1], y[0]["name"]), default=None)
        if drop is None:
            return None
        repl = [x for x in ranked if x not in picked and not foreign(x)]
        repl = [x for x in repl if line(x) == line(drop)] or repl
        if not repl:
            return None
        picked[picked.index(drop)] = repl[0]
    return picked


# ------------------------------------------------------------------ Escritura de data/squads_2006.json
# El archivo está alineado a mano (un jugador por línea), así que se insertan bloques de texto con el
# mismo estilo en vez de volver a serializarlo entero. Antes se quita lo que haya escrito T-08.

KEYS = ["id", "name", "age", "nationality", "position", "role", "stamina_max", "skill_rating",
        "signature_card_id", "wikidata"]
BASE_FIRST = "Colo-Colo, U. de Chile y U. Católica."
T08_NOTES = ('    "T-08', '    "wikidata: entidad')


def strip_t08(text):
    """El archivo sin lo que agrega T-08: notas, clubes de CLUBS y el review de la raíz."""
    text = "\n".join(l for l in text.split("\n") if not l.startswith(T08_NOTES))
    text = re.sub(r'(\n    "signature_card_id: carta de data/signature_cards\.json\.[^\n]*"),(\n  \])', r"\1\2", text)
    i = text.index("Planteles reales base (18 jugadores) de ") + len("Planteles reales base (18 jugadores) de ")
    j = text.index(" El resto de los clubes", i)
    text = text[:i] + BASE_FIRST + text[j:]
    cuts = [text.find(',\n    "%s": {' % c) for c in CLUBS] + [text.find('\n  },\n  "review": {')]
    cuts = [c for c in cuts if c >= 0]
    if cuts:
        text = text[:min(cuts)] + "\n  }\n}\n"
    data = json.loads(text)
    assert not set(data["squads"]) & set(CLUBS) and "review" not in data
    return text


def player_lines(players):
    cells = [["%s: %s," % (json.dumps(k), json.dumps(p[k], ensure_ascii=False)) for k in KEYS] for p in players]
    for row in cells:
        row[-1] = row[-1].rstrip(",")
    widths = [max(len(row[i]) for row in cells) for i in range(len(KEYS))]
    lines = []
    for row in cells:
        parts = [c.ljust(widths[i]) if i < 2 else c for i, c in enumerate(row)]
        lines.append("        {" + " ".join(parts) + "}")
    return ",\n".join(lines)


def club_block(club, data):
    review = ",\n".join("        " + json.dumps(r, ensure_ascii=False) for r in data["review"])
    return ('    %s: {\n      "players": [\n%s\n      ],\n      "review": [%s]\n    }' % (
        json.dumps(club), player_lines(data["players"]), "\n" + review + "\n      " if review else ""))


def write(result, pending, notes):
    body = strip_t08(open(SQUADS, encoding="utf-8").read())
    tail = "\n  }\n}\n"
    assert body.endswith(tail), "fin inesperado en %s" % SQUADS
    body = body[:-len(tail)]
    for club in CLUBS:
        if club in result:
            body += ",\n" + club_block(club, result[club])
    review = ",\n".join('    %s: [\n%s\n    ]' % (json.dumps(c), ",\n".join("      " + json.dumps(r, ensure_ascii=False) for r in pending[c]))
                        for c in CLUBS if c in pending)
    body += "\n  },\n  \"review\": {\n" + review + "\n  }\n}\n"
    body = body.replace(BASE_FIRST + " El resto", notes[0] + " El resto", 1)
    anchor = '    "signature_card_id: carta de data/signature_cards.json.'
    i = body.index(anchor)
    j = body.index("\n", i)
    body = body[:j].rstrip() + ",\n" + ",\n".join("    " + json.dumps(n, ensure_ascii=False) for n in notes[1:]) + body[j:]
    json.loads(body)  # sigue siendo JSON válido
    open(SQUADS, "w", encoding="utf-8").write(body)


def notes_for(result):
    names = {"colo_colo": "Colo-Colo", "universidad_de_chile": "U. de Chile", "universidad_catolica": "U. Católica"}
    teams = {t["id"]: t for t in json.load(open(TEAMS, encoding="utf-8"))["teams"]}
    new = [teams[c].get("short_name") or teams[c]["name"] for c in CLUBS if c in result]
    real = [names[c] for c in names] + new
    return ["%s y %s." % (", ".join(real[:-1]), real[-1]),
            "T-08 (%s): instantánea de Wikidata y es.wikipedia del 27-oct-2026 (consulta: tools/t08/fetch.py y fetch_wiki.py; selección y atributos: tools/t08/build.py, determinista). Candidatos (D-27 y D-28): membresía P54 al club con inicio y fin que se cruzan con la temporada 2006 (27-ene a 31-dic), o membresía P54 sin inicio o sin fin que la trayectoria de la ficha del jugador en es.wikipedia pone en 2006. Si la ficha tiene trayectoria y no lo pone en el club en 2006, queda fuera (review). Un jugador en dos clubes del juego en 2006 queda donde terminó el año, la convención del Clausura de teams_chile_2006.json (la membresía que sigue después de 2006; si no, la que empezó más tarde; si las fechas no lo dicen, el orden de su trayectoria en es.wikipedia); un préstamo desde Colo-Colo, U. de Chile o U. Católica se queda en su club. No hay planteles 2006 por club publicados en es.wikipedia; para Audax se cruzó además con las alineaciones de la final del Clausura 2006." % ", ".join(new),
            "T-08, hechos: edad desde P569 (si hay varias fechas y todas dan la misma edad al 1-jul-2006 se usa esa; si se contradicen o faltan, la fecha de la ficha de es.wikipedia cuando coincide con una de Wikidata o Wikidata no tiene día; si no, null). nationality: P1532 (país deportivo), si no P27 única, si no la ciudadanía cuya selección defendió (P54 o la ficha); sin P27, la nacionalidad de la ficha; sin eso, queda fuera. position y role desde P413: arquero si alguna posición lo es; si no, la línea con más posiciones y su posición más específica (las genéricas defensa, mediocampista y delantero dan DFC, MCD y DEL; extremo da EXT). Un rol genérico se afina con la posición escrita en la ficha si es de la misma línea, y sin P413 se usa la de la ficha; sin ninguna, queda fuera.",
            "T-08, los 18: respaldo = sitelinks de Wikidata + 3 si tiene artículo en es.wikipedia + 5 si su trayectoria allí lo pone en el club en 2006 + 5 si jugó la final 2006 + partidos en el club según Wikidata ÷ 10 (máx. 6). Cuotas por línea 2 POR, 6 DEF, 6 MED y 4 DEL por respaldo; si una línea no alcanza, se completa con los de más respaldo (máx. 3 arqueros). La figura del club siempre; mín. 2 Sub-21 y máx. 6 extranjeros, reemplazando a los de menos respaldo de la misma línea.",
            "T-08, atributos (fórmula propia; nada de puntajes de otros juegos): skill_rating = 50 + 6 × facilities_level + 4 (la base de SquadGenerator para Primera A) + edad (≤18: −10, 19-20: −6, 21-22: −2, 23-25: 0, 26-30: +2, 31-33: 0, ≥34: −2; null: 0) + selección adulta con membresía desde 2006 o antes en Wikidata +6 (solo juveniles +2) + notoriedad min(4, sitelinks ÷ 5) + 8 si es la figura del club; acotado a 40-99. stamina_max = base por rol (POR 64, DFC 68, LAT 74, MCD 76, MCO 68, EXT 76, DEL 68) + edad (≤20: +4, 21-26: +2, 27-30: 0, 31-32: −4, 33-34: −8, ≥35: −12; null: 0); acotado a 40-100.",
            "wikidata: entidad del jugador en Wikidata (solo en los planteles de T-08). review (en la raíz): lo encontrado para los clubes que siguen generados porque no llegaron a 18 jugadores con fuente."]


if __name__ == "__main__":
    squads, result, pending, report = main()
    for club in CLUBS:
        r = report[club]
        print("%-26s qid=%s candidatos=%d (Wikidata %d, es.wikipedia %d) utilizables=%d -> %s" % (
            club, r["qid"], r["candidates"], r["dated_wd"], r["dated_wiki"], r["usable"],
            "REAL" if club in result else "generado"))
        if club in result:
            for p in result[club]["players"]:
                print("   %-4s %-3s %-30s %4s %s st=%d sk=%d %s" % (p["position"], p["role"], p["name"], p["age"], p["nationality"],
                      p["stamina_max"], p["skill_rating"], p["wikidata"]))
        for line in (result[club]["review"] if club in result else r["review"]):
            print("   review:", line)
    if WRITE:
        write(result, pending, notes_for(result))
        print("escrito", SQUADS)
