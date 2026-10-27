# T-08: arma los planteles 2006 desde la instantánea de Wikidata (tools/t08/out, de fetch.py).
# Elige 18 jugadores por club con reglas fijas y calcula role, stamina_max y skill_rating con la
# fórmula de _notes. Determinista: misma instantánea, mismo resultado.
#   python tools/t08/build.py tools/t08/out            -> informe en pantalla
#   python tools/t08/build.py tools/t08/out --write    -> además escribe data/squads_2006.json
import json
import math
import os
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
ISO_TO_FIFA = {"CHL": "CHI", "PRY": "PAR", "URY": "URU", "DEU": "GER", "NLD": "NED", "PRT": "POR",
               "HRV": "CRO", "CHE": "SUI", "GRC": "GRE", "DNK": "DEN", "BGR": "BUL", "ZAF": "RSA",
               "SVN": "SVN", "LBN": "LIB", "PSE": "PLE", "GTM": "GUA", "HND": "HON", "SLV": "SLV",
               "CRI": "CRC", "TTO": "TRI", "HTI": "HAI", "NGA": "NGA", "DZA": "ALG", "MAR": "MAR"}
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


def covers_ref(start, end):
    return start is not None and end is not None and lo(start) <= REF <= hi(end)


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


def role_of(positions):
    """Rol del juego desde P413. Arquero si alguna posición lo es; si no, la línea con más votos y,
    dentro de ella, la posición específica (la genérica solo si no hay otra). Empates: ROLE_ORDER."""
    found = []
    for p in positions:
        label = norm(p.get("en") or p.get("es") or "")
        for word, role, specific in ROLE_WORDS:
            if word in label:
                found.append((role, specific))
                break
    if not found:
        return None, None
    if any(r == "POR" for r, _ in found):
        return "POR", "POR"
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
    return role, position


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


def facts(q, pdata):
    """Hechos de un jugador. Devuelve (dict, notas para review, problemas que lo dejan fuera)."""
    notes = []
    blocking = []
    name = (pdata.get("labels") or {}).get("es") or (pdata.get("labels") or {}).get("en")
    dobs = sorted({(d["value"][:10], d["prec"]) for d in live(pdata.get("dob", []))})
    age = None
    ages = set()
    for v, prec in dobs:
        if prec < 11:
            ages.add(None)
            continue
        y, m, d = int(v[:4]), int(v[5:7]), int(v[8:10])
        ages.add(REF[0] - y - (1 if (m, d) > (REF[1], REF[2]) else 0))
    shown = ", ".join(v[:10] if prec >= 11 else v[:4] for v, prec in dobs)
    if not dobs:
        notes.append("sin fecha de nacimiento: edad null")
    elif len(ages) == 1 and None not in ages:
        age = next(iter(ages))
        if len(dobs) > 1:
            notes.append("Wikidata registra %d fechas de nacimiento (%s); todas dan %d años al 1-jul-2006" % (len(dobs), shown, age))
    else:
        notes.append("fecha de nacimiento dudosa o sin día (%s): edad null" % shown)
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
        if len(played) == 1:
            nat = played[0]
            notes.append("ciudadanías %s; se usa %s, la selección que defendió" % (", ".join(sorted(cits)), nat))
        else:
            blocking.append("varias nacionalidades (%s) y ninguna selección que las desempate" % ", ".join(sorted(cits)))
    else:
        blocking.append("sin nacionalidad")
    role, position = role_of(pdata.get("positions", []))
    if role is None:
        blocking.append("sin posición (P413)")
    senior = youth = False
    caps = 0
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
            caps += int(float(m.get("matches") or 0))
    return {"qid": q, "name": name, "age": age, "nationality": nat, "role": role, "position": position,
            "senior": senior, "youth": youth, "caps": caps, "sitelinks": int(pdata.get("sitelinks") or 0),
            "eswiki": bool(pdata.get("eswiki"))}, notes, blocking


def club_stints(pdata, club_qids):
    """Membresías del jugador (de su ficha completa) a cualquiera de los qids del club."""
    out = []
    for m in live(pdata.get("memberships", [])):
        if m.get("team") in club_qids:
            out.append((tdate(m.get("start"), m.get("startPrec")), tdate(m.get("end"), m.get("endPrec")), m))
    return out


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
    fame = min(6, f["sitelinks"] // 5)
    return max(40, min(99, base + mod + sel + fame + (10 if figure else 0)))


def support(f, stint_matches):
    return f["sitelinks"] + (3 if f["eswiki"] else 0) + min(stint_matches, 60) / 10.0


def main():
    teams = {t["id"]: t for t in json.load(open(TEAMS, encoding="utf-8"))["teams"]}
    squads = json.load(open(SQUADS, encoding="utf-8"))
    chosen = load("clubs_elegidos.json")
    players = load("jugadores.json")
    figs = load("figuras.json")
    taken = {p["id"] for t in squads["squads"].values() for p in t["players"]}
    taken_names = {norm(p["name"]) for t in squads["squads"].values() for p in t["players"]}

    # 1. Candidatos por club: membresía con fechas que se cruza con la temporada 2006.
    cands = {}
    homes = {}  # qid -> [(club, start, end)]
    for club in CLUBS:
        info = chosen.get(club, {})
        qids = {info.get("qid")} if info.get("qid") else set()
        cands[club] = {}
        for q, pdata in players.items():
            for st, en, m in club_stints(pdata, qids):
                if covers_season(st, en):
                    cands[club][q] = cands[club].get(q, 0) + int(float(m.get("matches") or 0))
                    homes.setdefault(q, []).append((club, st, en))
    report = {}
    result = {}
    pending = {}
    # 2. Jugadores en dos clubes del juego en 2006: quedan en el club donde terminaron el año (la
    #    misma convención del Clausura que usa teams_chile_2006.json para DT y figura): la membresía que
    #    sigue después de 2006; si todas terminan en 2006, la que empezó más tarde. Empate: fuera.
    owner = {}
    moved = {}
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
            continue
        latest = max(lo(st) for c, st, en in hs)
        last = sorted({c for c, st, en in hs if lo(st) == latest and st[1] is not None} or
                      {c for c, st, en in hs if lo(st) == latest})
        owner[q] = last[0] if len(last) == 1 else None
    for club in CLUBS:
        team = teams[club]
        level = int(team.get("facilities_level", 1))
        figure = team.get("signature_card")
        review = []
        pool = []
        fig_qids = {m["qid"] for m in figs.get(club, {}).get("matches", [])}
        fig_in = False
        for q, matches in sorted(cands[club].items()):
            pdata = players[q]
            f, notes, blocking = facts(q, pdata)
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
                notes.append("en 2006 también en %s; terminó el año aquí" % others)
            if norm(label) in taken_names or slug(label) in taken:
                review.append("%s: también en 2006 aquí, pero ya está en el plantel de otro club real" % tag)
                continue
            if blocking:
                review.append("%s: %s; queda fuera" % (tag, "; ".join(blocking + notes)))
                continue
            if is_fig:
                fig_in = True
            pool.append((f, support(f, matches), is_fig, notes))
        if figure is not None and not fig_in:
            review.append("figura %s: no queda en el plantel con membresía fechada en 2006 (coincidencias por nombre: %s)" % (
                figure, ", ".join(sorted(fig_qids)) or "ninguna"))
        pick = select(pool)
        report[club] = {"qid": chosen.get(club, {}).get("qid"), "candidates": len(cands[club]), "usable": len(pool),
                        "picked": len(pick) if pick else 0, "review": review}
        if pick is None or (figure is not None and not fig_in):
            pending[club] = ["%d jugadores con membresía fechada en 2006 en Wikidata, %d utilizables" % (
                len(cands[club]), len(pool))] + review + ["%s (%s): %s" % (x[0]["name"], x[0]["qid"], n) for x in pool for n in x[3]]
            continue
        rows = []
        for f, sup, is_fig, notes in pick:
            pid = slug(f["name"])
            if pid in taken:
                pid = "%s_%s" % (pid, club)
            taken.add(pid)
            rows.append({"id": pid, "name": figure if is_fig else f["name"], "age": f["age"],
                         "nationality": f["nationality"], "position": f["position"], "role": f["role"],
                         "stamina_max": stamina(f["role"], f["age"]),
                         "skill_rating": skill(level, f, is_fig), "signature_card_id": None,
                         "wikidata": f["qid"]})
            review.extend("%s: %s" % (pid, n) for n in notes)
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


if __name__ == "__main__":
    squads, result, pending, report = main()
    for club in CLUBS:
        r = report[club]
        print("%-26s qid=%s candidatos=%d utilizables=%d -> %s" % (club, r["qid"], r["candidates"], r["usable"],
              "REAL" if club in result else "generado"))
        if club in result:
            for p in result[club]["players"]:
                print("   %-4s %-3s %-30s %4s %s st=%d sk=%d %s" % (p["position"], p["role"], p["name"], p["age"], p["nationality"],
                      p["stamina_max"], p["skill_rating"], p["wikidata"]))
        for line in r["review"]:
            print("   review:", line)
