# Ligas de Sudamérica 2006-2026 (datos de referencia de uso propio, no para el juego). Paso 1:
# temporadas y clubes. Busca en Wikidata la primera división de Brasil, Argentina y Chile y sus
# temporadas (P3450, o partes P361 de una temporada) que tocan 2006-2026. Para cada temporada guarda los
# participantes (P1923) si Wikidata los tiene y, además, los clubes del país enlazados desde su artículo
# en es/pt/en.wikipedia con cuántas veces aparece cada uno (los que juegan salen en tablas y
# resultados; los que solo se mencionan, una o dos veces). Uso: python tools/ligas/temporadas.py <out>
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

UA = "FutbolistaDeckbuilder-ligas/1.0 (https://github.com/vKieferv/BONVALET; datos de referencia)"
SPARQL = "https://query.wikidata.org/sparql"
OUT = sys.argv[1] if len(sys.argv) > 1 else "out"
COUNTRIES = {"brasil": "Q155", "argentina": "Q414", "chile": "Q298"}
FIRST, LAST = 2006, 2026
errors = []


def http_json(url, data=None, accept="application/json"):
    err = None
    for attempt in range(5):
        try:
            req = urllib.request.Request(url, data=data, headers={"User-Agent": UA, "Accept": accept})
            with urllib.request.urlopen(req, timeout=120) as r:
                return json.loads(r.read().decode("utf-8"))
        except Exception as e:  # noqa: BLE001
            err = "%s (intento %d): %s" % (url[:100], attempt + 1, e)
            print(err, flush=True)
            time.sleep(5 * (attempt + 1))
    errors.append(err)
    return None


def sparql(query):
    time.sleep(1.0)
    data = urllib.parse.urlencode({"query": query, "format": "json"}).encode()
    res = http_json(SPARQL, data=data, accept="application/sparql-results+json")
    if res is None:
        return []
    return [{k: v["value"] for k, v in b.items()} for b in res["results"]["bindings"]]


def qid(uri):
    return uri.rsplit("/", 1)[-1] if uri else None


def save(name, obj):
    path = os.path.join(OUT, name)
    os.makedirs(os.path.dirname(path), exist_ok=True)
    with open(path, "w", encoding="utf-8") as f:
        json.dump(obj, f, ensure_ascii=False, indent=1, sort_keys=True)
    print("guardado", path, flush=True)


def years_of(s):
    """Años calendario que toca una temporada: por fechas de Wikidata o por los años de su nombre."""
    ys = [int(v[:4]) for k in ("start", "end", "pt") for v in [s.get(k)] if v and v[:4].isdigit()]
    if ys:
        return list(range(min(ys), max(ys) + 1))
    m = re.search(r"((?:19|20)\d\d)(?:\s*[-–/]\s*((?:19|20)?\d\d))?", s.get("label") or "")
    if not m:
        return []
    a = int(m.group(1))
    b = m.group(2)
    if b:
        b = int(b) if len(b) == 4 else int(str(a)[:2] + b)
        return list(range(a, b + 1))
    return [a]


# 1. La liga de cada país: la que más temporadas tiene entre las ligas de fútbol del país.
leagues = {}
for country, cq in COUNTRIES.items():
    rows = sparql("""
SELECT ?l ?es ?en (COUNT(DISTINCT ?s) AS ?n) WHERE {
  ?l wdt:P31/wdt:P279* wd:Q15991303 ; wdt:P17 wd:%s .
  ?s wdt:P3450 ?l .
  OPTIONAL { ?l rdfs:label ?es FILTER(lang(?es) = "es") }
  OPTIONAL { ?l rdfs:label ?en FILTER(lang(?en) = "en") }
} GROUP BY ?l ?es ?en ORDER BY DESC(?n) LIMIT 15""" % cq)
    cands = [{"qid": qid(r["l"]), "es": r.get("es"), "en": r.get("en"), "seasons": int(r["n"])} for r in rows]
    leagues[country] = {"candidates": cands}
save("ligas.json", leagues)

# La primera división: el nombre lo dice y no es femenina, de ascenso ni de reservas.
BAD = ("femenin", "women", "feminino", "serie b", "série b", "serie c", "série c", "serie d", "série d",
       "segunda", "tercera", "primera b", "nacional b", "reserva", "juvenil", "sub-", "copa")
GOOD = {"brasil": ("série a", "serie a"), "argentina": ("primera división", "primera division", "liga profesional"),
        "chile": ("primera división", "primera division")}
for country, info in leagues.items():
    ok = [c for c in info["candidates"]
          if any(g in ((c["es"] or "") + " " + (c["en"] or "")).lower() for g in GOOD[country])
          and not any(b in ((c["es"] or "") + " " + (c["en"] or "")).lower() for b in BAD)]
    info["chosen"] = ok[0]["qid"] if ok else None
    print(country, "->", ok[0] if ok else None, flush=True)

# 2. Temporadas de cada liga (directas o partes de una temporada), con fechas y artículos.
seasons = {}
for country, info in leagues.items():
    if not info["chosen"]:
        continue
    rows = sparql("""
SELECT ?s (SAMPLE(?lab) AS ?label) (MIN(?st) AS ?start) (MAX(?en) AS ?end) (SAMPLE(?p) AS ?pt)
       (SAMPLE(?parent) AS ?part_of) (SAMPLE(?esw) AS ?es) (SAMPLE(?ptw) AS ?ptwiki) (SAMPLE(?enw) AS ?en_)
       (COUNT(DISTINCT ?team) AS ?n) WHERE {
  { ?s wdt:P3450 wd:%s } UNION { ?s wdt:P361 ?parent . ?parent wdt:P3450 wd:%s }
  OPTIONAL { ?s rdfs:label ?lab FILTER(lang(?lab) = "es") }
  OPTIONAL { ?s wdt:P580 ?st } OPTIONAL { ?s wdt:P582 ?en } OPTIONAL { ?s wdt:P585 ?p }
  OPTIONAL { ?esw schema:about ?s ; schema:isPartOf <https://es.wikipedia.org/> }
  OPTIONAL { ?ptw schema:about ?s ; schema:isPartOf <https://pt.wikipedia.org/> }
  OPTIONAL { ?enw schema:about ?s ; schema:isPartOf <https://en.wikipedia.org/> }
  OPTIONAL { ?s wdt:P1923 ?team }
} GROUP BY ?s""" % (info["chosen"], info["chosen"]))
    out = []
    for r in rows:
        s = {"qid": qid(r["s"]), "label": r.get("label"), "start": r.get("start"), "end": r.get("end"),
             "pt": r.get("pt"), "part_of": qid(r.get("part_of")), "p1923": int(r.get("n", 0)),
             "wiki": {k: urllib.parse.unquote(r[f].rsplit("/wiki/", 1)[1]).replace("_", " ")
                      for k, f in (("es", "es"), ("pt", "ptwiki"), ("en", "en_")) if r.get(f)}}
        s["years"] = years_of(s)
        if any(FIRST <= y <= LAST for y in s["years"]):
            out.append(s)
    out.sort(key=lambda s: (s["years"][0] if s["years"] else 0, s["label"] or ""))
    seasons[country] = out
    print(country, len(out), "temporadas en %d-%d" % (FIRST, LAST), flush=True)

# 2b. Años sin temporada en Wikidata: el artículo de en.wikipedia por su nombre habitual.
FALLBACK = {"brasil": ["{y} Campeonato Brasileiro Série A"],
            "argentina": ["{y} Argentine Primera División", "{y} Argentine Primera División season"],
            "chile": ["{y} Chilean Primera División", "{y} Chilean Primera División season", "{y} Liga de Primera"]}
for country, ss in seasons.items():
    covered = {y for s in ss for y in s["years"]}
    for y in range(FIRST, LAST + 1):
        if y in covered:
            continue
        for pattern in FALLBACK[country]:
            title = pattern.format(y=y)
            time.sleep(0.2)
            res = http_json("https://en.wikipedia.org/w/api.php?" + urllib.parse.urlencode(
                {"action": "query", "titles": title, "redirects": 1, "prop": "pageprops", "ppprop": "wikibase_item",
                 "format": "json", "formatversion": 2}))
            pages = (res or {}).get("query", {}).get("pages", [])
            if pages and not pages[0].get("missing"):
                ss.append({"qid": (pages[0].get("pageprops") or {}).get("wikibase_item"), "label": pages[0]["title"],
                           "years": [y], "p1923": 0, "wiki": {"en": pages[0]["title"]}, "fallback": True})
                print(country, y, "->", pages[0]["title"], flush=True)
                break

# 3. Participantes de Wikidata (P1923).
for country, ss in seasons.items():
    with_q = [s for s in ss if s.get("qid")]
    by_q = {s["qid"]: s for s in with_q}
    for i in range(0, len(with_q), 40):
        vals = " ".join("wd:" + s["qid"] for s in with_q[i:i + 40])
        for r in sparql("SELECT ?s ?t WHERE { VALUES ?s { %s } ?s wdt:P1923 ?t . }" % vals):
            by_q[qid(r["s"])].setdefault("participants", []).append(qid(r["t"]))

# 4. Clubes enlazados desde los artículos de cada temporada, con cuántas veces aparece cada enlace.
APIS = {"es": "https://es.wikipedia.org/w/api.php", "pt": "https://pt.wikipedia.org/w/api.php",
        "en": "https://en.wikipedia.org/w/api.php"}


def api(lang, params):
    time.sleep(0.2)
    params = dict(params, format="json", formatversion=2)
    return http_json(APIS[lang] + "?" + urllib.parse.urlencode(params))


def cap(t):
    t = t.replace("_", " ").strip()
    return t[:1].upper() + t[1:]


all_linked = set()
for country, ss in seasons.items():
    for s in ss:
        s["linked"] = {}
        for lang, title in s["wiki"].items():
            res = api(lang, {"action": "query", "prop": "revisions", "rvprop": "content", "rvslots": "main",
                             "titles": title, "redirects": 1})
            pages = (res or {}).get("query", {}).get("pages", [])
            if not pages or not pages[0].get("revisions"):
                continue
            text = pages[0]["revisions"][0]["slots"]["main"]["content"]
            counts = {}
            for m in re.finditer(r"\[\[([^\]|#]+)(?:#[^\]|]*)?(?:\|[^\]]*)?\]\]", text):
                t = cap(m.group(1))
                counts[t] = counts.get(t, 0) + 1
            # Tabla de posiciones con el módulo Sports table (en.wikipedia y otras): |name_XXX=[[Club]].
            table = {cap(m.group(1)) for m in re.finditer(r"\|\s*name_[^=|]+=\s*(?:\{\{[^}]*\}\}\s*)?\[\[([^\]|#]+)", text)}
            # Enlaces del artículo -> qid (siguiendo redirecciones), de a 500.
            to_q = {}
            cont = {}
            while True:
                res = api(lang, dict({"action": "query", "generator": "links", "titles": title, "gpllimit": "max",
                                      "gplnamespace": 0, "prop": "pageprops", "ppprop": "wikibase_item",
                                      "redirects": 1}, **cont))
                q = (res or {}).get("query", {})
                page_q = {page["title"]: (page.get("pageprops") or {}).get("wikibase_item") for page in q.get("pages", [])}
                for t, item in page_q.items():
                    if item:
                        to_q[t] = item
                for mm in q.get("redirects", []):
                    if page_q.get(mm["to"]):
                        to_q[mm["from"]] = page_q[mm["to"]]
                if not res or "continue" not in res:
                    break
                cont = res["continue"]
            for t, n in counts.items():
                item = to_q.get(t)
                if item:
                    s["linked"].setdefault(item, {})[lang] = s["linked"].get(item, {}).get(lang, 0) + n
                    all_linked.add(item)
            if table:
                s.setdefault("table", {})[lang] = sorted({to_q[t] for t in table if t in to_q})
        print(country, s["label"], {k: len(v) for k, v in [("enlaces", s["linked"])]}, flush=True)

# 5. Cuáles de los enlazados son clubes de fútbol y de qué país.
clubs = {}
items = sorted(all_linked)
for i in range(0, len(items), 250):
    for r in sparql("""
SELECT ?c ?country ?es ?pt ?en WHERE {
  VALUES ?c { %s }
  ?c wdt:P31/wdt:P279* wd:Q476028 .
  OPTIONAL { ?c wdt:P17 ?country }
  OPTIONAL { ?c rdfs:label ?es FILTER(lang(?es) = "es") }
  OPTIONAL { ?c rdfs:label ?pt FILTER(lang(?pt) = "pt") }
  OPTIONAL { ?c rdfs:label ?en FILTER(lang(?en) = "en") }
}""" % " ".join("wd:" + q for q in items[i:i + 250])):
        c = clubs.setdefault(qid(r["c"]), {"countries": [], "es": r.get("es"), "pt": r.get("pt"), "en": r.get("en")})
        if r.get("country") and qid(r["country"]) not in c["countries"]:
            c["countries"].append(qid(r["country"]))
for country, ss in seasons.items():
    for s in ss:
        s["clubs"] = {q: n for q, n in s["linked"].items() if q in clubs and COUNTRIES[country] in clubs[q]["countries"]}
        del s["linked"]
save("temporadas.json", {"leagues": leagues, "seasons": seasons, "clubs": clubs})
save("errores.json", errors)
print("listo: %d errores" % len(errors))
