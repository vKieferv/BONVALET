# T-08: consulta Wikidata (SPARQL) y es.wikipedia para los planteles 2006 de Primera A.
# Solo descarga hechos y los guarda tal cual en <out>/; la selección de los 18 y los atributos de
# juego se hacen después, fuera de este script. Uso, desde la raíz del repo:
#   python tools/t08/fetch.py tools/t08/out
import json
import os
import sys
import time
import unicodedata
import urllib.parse
import urllib.request

UA = "FutbolistaDeckbuilder-T08/1.0 (https://github.com/vKieferv/BONVALET; datos de planteles 2006)"
SPARQL = "https://query.wikidata.org/sparql"
ESWIKI = "https://es.wikipedia.org/w/api.php"
OUT = sys.argv[1] if len(sys.argv) > 1 else "out"

# id del juego -> palabras que deben estar en el nombre del club (sin tildes, minúsculas).
CLUBS = {
    "cobreloa": ["cobreloa"],
    "audax_italiano": ["audax"],
    "huachipato": ["huachipato"],
    "union_espanola": ["union espanola"],
    "everton": ["everton"],
    "santiago_wanderers": ["wanderers"],
    "universidad_de_concepcion": ["universidad de concepcion"],
    "o_higgins": ["higgins"],
    "cobresal": ["cobresal"],
    "palestino": ["palestino"],
    "deportes_antofagasta": ["antofagasta"],
    "deportes_la_serena": ["la serena"],
    "coquimbo_unido": ["coquimbo"],
    "deportes_puerto_montt": ["puerto montt"],
    "rangers": ["rangers"],
    "santiago_morning": ["santiago morning"],
}

errors = []


def norm(s):
    s = unicodedata.normalize("NFKD", s or "").encode("ascii", "ignore").decode()
    return s.lower().replace("’", "'")


def http(url, data=None, accept="application/json"):
    for attempt in range(4):
        try:
            req = urllib.request.Request(url, data=data, headers={"User-Agent": UA, "Accept": accept})
            with urllib.request.urlopen(req, timeout=90) as r:
                return json.loads(r.read().decode("utf-8"))
        except Exception as e:  # noqa: BLE001
            err = "%s (intento %d): %s" % (url[:80], attempt + 1, e)
            print(err, flush=True)
            time.sleep(5 * (attempt + 1))
    errors.append(err)
    return None


def sparql(query):
    time.sleep(1.0)
    data = urllib.parse.urlencode({"query": query, "format": "json"}).encode()
    res = http(SPARQL, data=data, accept="application/sparql-results+json")
    if res is None:
        return []
    rows = []
    for b in res["results"]["bindings"]:
        rows.append({k: v["value"] for k, v in b.items()})
    return rows


def qid(uri):
    return uri.rsplit("/", 1)[-1] if uri else None


def save(name, obj):
    path = os.path.join(OUT, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=1, sort_keys=True)
    print("guardado", path, flush=True)


def chunks(seq, n):
    seq = list(seq)
    for i in range(0, len(seq), n):
        yield seq[i:i + n]


def values(qids):
    return " ".join("wd:" + q for q in qids)


# 1. Clubes chilenos de fútbol; luego, cuántos jugadores apuntan (P54) a los que calzan por nombre.
clubs = []
for cls in ("wd:Q476028", "wd:Q15944511"):
    for r in sparql("""
SELECT DISTINCT ?club ?es ?en ?article WHERE {
  ?club wdt:P31/wdt:P279* %s ; wdt:P17 wd:Q298 .
  OPTIONAL { ?club rdfs:label ?es FILTER(lang(?es) = "es") }
  OPTIONAL { ?club rdfs:label ?en FILTER(lang(?en) = "en") }
  OPTIONAL { ?article schema:about ?club ; schema:isPartOf <https://es.wikipedia.org/> }
}""" % cls):
        r["club"] = qid(r["club"])
        if all(r["club"] != c["club"] for c in clubs):
            clubs.append(r)
save("clubs_chile.json", clubs)

chosen = {}
for key, words in CLUBS.items():
    cands = []
    for c in clubs:
        names = norm(c.get("es", "")) + " | " + norm(c.get("en", "")) + " | " + norm(urllib.parse.unquote(c.get("article", "")))
        if all(w in names for w in words) and "femenin" not in names and "women" not in names:
            cands.append(c)
    chosen[key] = {"candidates": cands}
all_cands = sorted({c["club"] for info in chosen.values() for c in info["candidates"]})
counts = {}
for batch in chunks(all_cands, 40):
    for r in sparql("""
SELECT ?club (COUNT(DISTINCT ?p) AS ?n) WHERE { VALUES ?club { %s } ?p wdt:P54 ?club . } GROUP BY ?club
""" % values(batch)):
        counts[qid(r["club"])] = int(r["n"])
for key, info in chosen.items():
    for c in info["candidates"]:
        c["players"] = counts.get(c["club"], 0)
    info["candidates"].sort(key=lambda c: -c["players"])
    info["qid"] = info["candidates"][0]["club"] if info["candidates"] else None
save("clubs_elegidos.json", chosen)

# 2. Todas las membresías (P54) a cada club, con fechas, partidos y goles como calificadores.
members = {}
for key, info in chosen.items():
    rows_all = []
    for cand in info["candidates"][:3]:
        rows = sparql("""
SELECT ?player ?st ?start ?startPrec ?end ?endPrec ?matches ?goals ?rank WHERE {
  ?player p:P54 ?st . ?st ps:P54 wd:%s ; wikibase:rank ?rank .
  OPTIONAL { ?st pqv:P580 ?sv . ?sv wikibase:timeValue ?start ; wikibase:timePrecision ?startPrec }
  OPTIONAL { ?st pqv:P582 ?ev . ?ev wikibase:timeValue ?end ; wikibase:timePrecision ?endPrec }
  OPTIONAL { ?st pq:P1350 ?matches }
  OPTIONAL { ?st pq:P1351 ?goals }
}""" % cand["club"])
        for r in rows:
            r["player"] = qid(r["player"])
            r["st"] = r["st"].rsplit("/", 1)[-1]
            r["rank"] = r["rank"].rsplit("#", 1)[-1]
            r["club"] = cand["club"]
        rows_all.extend(rows)
    members[key] = rows_all
    save("membresias/%s.json" % key, rows_all)


def year(v):
    return int(v[:4]) if v else None


# Jugadores con alguna membresía que toque 2005-2007 (o sin fechas: se guardan, pero sin detalle).
cand_players = set()
for key, rows in members.items():
    for r in rows:
        s, e = year(r.get("start")), year(r.get("end"))
        if s is None and e is None:
            continue
        if (s if s is not None else 0) <= 2007 and (e if e is not None else 9999) >= 2005:
            cand_players.add(r["player"])

# 3. Figuras de teams_chile_2006.json: se buscan por nombre por si no salen en el paso 2.
teams = json.load(open("data/teams_chile_2006.json", encoding="utf-8"))["teams"]
figures = {t["id"]: t.get("signature_card") for t in teams if t["id"] in CLUBS}
fig_found = {}
for key, name in figures.items():
    if not name:
        continue
    rows = sparql("""
SELECT DISTINCT ?p ?desc WHERE {
  { ?p rdfs:label "%s"@es } UNION { ?p skos:altLabel "%s"@es } UNION { ?p rdfs:label "%s"@en }
  ?p wdt:P106 wd:Q937857 .
  OPTIONAL { ?p schema:description ?desc FILTER(lang(?desc) = "es") }
}""" % (name, name, name))
    fig_found[key] = {"name": name, "matches": [{"qid": qid(r["p"]), "desc": r.get("desc")} for r in rows]}
    for r in rows:
        cand_players.add(qid(r["p"]))
save("figuras.json", fig_found)

# 4. Detalle de cada jugador candidato.
players = {q: {"labels": {}, "dob": [], "citizenship": [], "sport_country": [], "positions": [],
               "memberships": []} for q in cand_players}
for batch in chunks(sorted(cand_players), 60):
    v = values(batch)
    for r in sparql("""
SELECT ?p ?es ?en ?sitelinks ?eswiki ?enwiki WHERE {
  VALUES ?p { %s }
  OPTIONAL { ?p rdfs:label ?es FILTER(lang(?es) = "es") }
  OPTIONAL { ?p rdfs:label ?en FILTER(lang(?en) = "en") }
  OPTIONAL { ?p wikibase:sitelinks ?sitelinks }
  OPTIONAL { ?eswiki schema:about ?p ; schema:isPartOf <https://es.wikipedia.org/> }
  OPTIONAL { ?enwiki schema:about ?p ; schema:isPartOf <https://en.wikipedia.org/> }
}""" % v):
        d = players[qid(r["p"])]
        d["labels"] = {"es": r.get("es"), "en": r.get("en")}
        d["sitelinks"] = int(r.get("sitelinks", 0))
        d["eswiki"] = r.get("eswiki")
        d["enwiki"] = r.get("enwiki")
    for r in sparql("""
SELECT ?p ?dob ?prec ?rank WHERE {
  VALUES ?p { %s }
  ?p p:P569 ?s . ?s psv:P569 ?v ; wikibase:rank ?rank . ?v wikibase:timeValue ?dob ; wikibase:timePrecision ?prec .
}""" % v):
        players[qid(r["p"])]["dob"].append({"value": r["dob"], "prec": int(r["prec"]), "rank": r["rank"].rsplit("#", 1)[-1]})
    for prop, field in (("P27", "citizenship"), ("P1532", "sport_country")):
        for r in sparql("""
SELECT ?p ?c ?cl ?iso ?fifa ?rank WHERE {
  VALUES ?p { %s }
  ?p p:%s ?s . ?s ps:%s ?c ; wikibase:rank ?rank .
  OPTIONAL { ?c rdfs:label ?cl FILTER(lang(?cl) = "es") }
  OPTIONAL { ?c wdt:P298 ?iso }
  OPTIONAL { ?c wdt:P3441 ?fifa }
}""" % (v, prop, prop)):
            players[qid(r["p"])][field].append({"qid": qid(r["c"]), "label": r.get("cl"), "iso3": r.get("iso"),
                                                "fifa": r.get("fifa"), "rank": r["rank"].rsplit("#", 1)[-1]})
    for r in sparql("""
SELECT ?p ?pos ?es ?en WHERE {
  VALUES ?p { %s }
  ?p wdt:P413 ?pos .
  OPTIONAL { ?pos rdfs:label ?es FILTER(lang(?es) = "es") }
  OPTIONAL { ?pos rdfs:label ?en FILTER(lang(?en) = "en") }
}""" % v):
        players[qid(r["p"])]["positions"].append({"qid": qid(r["pos"]), "es": r.get("es"), "en": r.get("en")})
    for r in sparql("""
SELECT ?p ?team ?tl ?start ?startPrec ?end ?endPrec ?matches ?goals ?national ?loan ?rank WHERE {
  VALUES ?p { %s }
  ?p p:P54 ?s . ?s ps:P54 ?team ; wikibase:rank ?rank .
  OPTIONAL { ?team rdfs:label ?tl FILTER(lang(?tl) = "es") }
  OPTIONAL { ?s pqv:P580 ?sv . ?sv wikibase:timeValue ?start ; wikibase:timePrecision ?startPrec }
  OPTIONAL { ?s pqv:P582 ?ev . ?ev wikibase:timeValue ?end ; wikibase:timePrecision ?endPrec }
  OPTIONAL { ?s pq:P1350 ?matches }
  OPTIONAL { ?s pq:P1351 ?goals }
  OPTIONAL { ?s pq:P1642 ?loan }
  OPTIONAL { ?team wdt:P31/wdt:P279* wd:Q6979593 . BIND(true AS ?national) }
}""" % v):
        r2 = {k: r.get(k) for k in ("tl", "start", "startPrec", "end", "endPrec", "matches", "goals", "national")}
        r2["team"] = qid(r["team"])
        r2["loan"] = qid(r.get("loan")) if r.get("loan") else None
        r2["rank"] = r["rank"].rsplit("#", 1)[-1]
        players[qid(r["p"])]["memberships"].append(r2)
save("jugadores.json", players)

# 5. es.wikipedia: artículos de temporada 2006 por club (para cruzar el plantel publicado).
wiki = {}
for key, info in chosen.items():
    best = info["candidates"][0] if info["candidates"] else {}
    name = best.get("es") or key
    found = []
    for q in ('intitle:2006 "%s"' % name, 'intitle:temporada intitle:2006 %s' % " ".join(CLUBS[key])):
        time.sleep(0.5)
        res = http(ESWIKI + "?" + urllib.parse.urlencode({"action": "query", "list": "search", "srsearch": q,
                                                          "srlimit": 10, "format": "json"}))
        if res:
            found.extend(h["title"] for h in res.get("query", {}).get("search", []))
    wiki[key] = sorted(set(found))
save("wikipedia_busqueda.json", wiki)

save("errores.json", errors)
print("listo: %d jugadores candidatos, %d errores" % (len(players), len(errors)))
