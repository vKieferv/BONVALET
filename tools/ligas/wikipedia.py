# Ligas de Sudamérica 2006-2026 (referencia de uso propio, no para el juego). Paso 4: en.wikipedia.
# Wikidata dejó de actualizar las trayectorias hacia 2016, así que para los años recientes se leen
# las fichas de en.wikipedia: para cada club de out/jugadores.json.gz, su categoría de jugadores
# (P6112 en Wikidata), todos los artículos de esa categoría y, de cada ficha, los pares
# yearsN/clubsN que apuntan a alguno de nuestros clubes, más la fecha de nacimiento y la posición.
# Guarda out/wikipedia.json.gz. Uso: python tools/ligas/wikipedia.py tools/ligas/out
import gzip
import json
import os
import re
import sys
import time
import urllib.parse
import urllib.request

UA = "FutbolistaDeckbuilder-ligas/1.0 (https://github.com/vKieferv/BONVALET; datos de referencia)"
SPARQL = "https://query.wikidata.org/sparql"
API = "https://en.wikipedia.org/w/api.php"
OUT = sys.argv[1] if len(sys.argv) > 1 else "out"
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
    return [{k: v["value"] for k, v in b.items()} for b in res["results"]["bindings"]] if res else []


def api(params):
    time.sleep(0.1)
    data = urllib.parse.urlencode(dict(params, format="json", formatversion=2)).encode()
    return http_json(API, data=data)


def qid(uri):
    return uri.rsplit("/", 1)[-1] if uri else None


def cap(t):
    t = t.replace("_", " ").strip()
    return t[:1].upper() + t[1:]


with gzip.open(os.path.join(OUT, "jugadores.json.gz"), "rt", encoding="utf-8") as f:
    clubs = sorted(json.load(f)["clubs"])

# 1. Artículo y categoría de jugadores de cada club en en.wikipedia.
club_title = {}
club_cat = {}
for i in range(0, len(clubs), 100):
    for r in sparql("""
SELECT ?c ?art ?cat WHERE {
  VALUES ?c { %s }
  OPTIONAL { ?art schema:about ?c ; schema:isPartOf <https://en.wikipedia.org/> }
  OPTIONAL { ?c wdt:P6112 ?ci . ?cat schema:about ?ci ; schema:isPartOf <https://en.wikipedia.org/> }
}""" % " ".join("wd:" + q for q in clubs[i:i + 100])):
        c = qid(r["c"])
        if r.get("art"):
            club_title[c] = cap(urllib.parse.unquote(r["art"].rsplit("/wiki/", 1)[1]))
        if r.get("cat"):
            club_cat.setdefault(c, set()).add(cap(urllib.parse.unquote(r["cat"].rsplit("/wiki/", 1)[1])))
print("clubes con artículo:", len(club_title), "con categoría:", len(club_cat), flush=True)

# 2. Títulos (y redirecciones) que apuntan a cada club, para reconocerlo en las fichas.
link_to_club = {}
titles = sorted(club_title.items(), key=lambda kv: kv[1])
for i in range(0, len(titles), 50):
    batch = dict((t, c) for c, t in titles[i:i + 50])
    cont = {}
    while True:
        res = api(dict({"action": "query", "titles": "|".join(batch), "prop": "redirects", "rdlimit": "max",
                        "redirects": 1}, **cont))
        q = (res or {}).get("query", {})
        final = {}
        for kind in ("normalized", "redirects"):
            for m in q.get(kind, []):
                final[m["to"]] = final.get(m["from"], m["from"])
        for page in q.get("pages", []):
            c = batch.get(final.get(page["title"], page["title"])) or batch.get(page["title"])
            if not c:
                continue
            link_to_club[page["title"]] = c
            for r in page.get("redirects", []):
                link_to_club[r["title"]] = c
        if not res or "continue" not in res:
            break
        cont = res["continue"]
for t, c in club_title.items():
    link_to_club.setdefault(t, c)
print("títulos de club reconocibles:", len(link_to_club), flush=True)

# 3. Miembros de cada categoría.
members = set()
for c, cats in sorted(club_cat.items()):
    for cat in sorted(cats):
        cont = {}
        n = 0
        while True:
            res = api(dict({"action": "query", "list": "categorymembers", "cmtitle": cat, "cmnamespace": 0,
                            "cmlimit": "max"}, **cont))
            for m in (res or {}).get("query", {}).get("categorymembers", []):
                members.add(m["title"])
                n += 1
            if not res or "continue" not in res:
                break
            cont = res["continue"]
        print(cat, n, flush=True)
print("artículos de jugadores:", len(members), flush=True)

# 4. Fichas: pares yearsN/clubsN, nacimiento y posición.
def field(box, name):
    m = re.search(r"\|\s*%s\s*=\s*(.*?)(?=\n\s*\||\|\s*[a-z_]+\d*\s*=|\n\}\})" % name, box, re.S)
    return m.group(1).strip() if m else ""


def years(text):
    text = re.sub(r"<ref.*?(</ref>|/>)|<!--.*?-->|\{\{[^}]*\}\}", "", text, flags=re.S)
    m = re.search(r"(\d{4})\s*(?:[–\-—]|&ndash;)?\s*(\d{4}|\d{2})?", text)
    if not m:
        return None
    a = int(m.group(1))
    if m.group(2):
        b = int(m.group(2)) if len(m.group(2)) == 4 else int(str(a)[:2] + m.group(2))
    elif re.search(r"\d{4}\s*(?:[–\-—]|&ndash;)\s*$", text.strip()):
        b = 9999
    else:
        b = a
    return a, b


players = {}
names = sorted(members)
for i in range(0, len(names), 50):
    batch = names[i:i + 50]
    params = {"action": "query", "titles": "|".join(batch), "prop": "revisions|pageprops", "rvprop": "content",
              "rvslots": "main", "rvsection": 0, "ppprop": "wikibase_item", "redirects": 1}
    res = api(params)
    if res and "error" in res:
        del params["rvsection"]
        res = api(params)
    for page in (res or {}).get("query", {}).get("pages", []):
        if not page.get("revisions"):
            continue
        text = page["revisions"][0]["slots"]["main"].get("content", "")
        m = re.search(r"\{\{\s*Infobox football biography(.*)", text, re.S | re.I)
        if not m:
            continue
        box = m.group(1)
        rows = []
        for n in range(1, 40):
            club = field(box, "clubs%d" % n)
            if not club:
                continue
            link = re.search(r"\[\[([^\]|#]+)", club)
            if not link or cap(link.group(1)) not in link_to_club:
                continue
            ys = years(field(box, "years%d" % n))
            if ys:
                rows.append([link_to_club[cap(link.group(1))], ys[0], ys[1], "loan" in club.lower() or "→" in club])
        if not rows:
            continue
        birth = re.search(r"\{\{\s*birth date(?: and age)?\s*\|(?:\s*(?:df|mf)\s*=\s*\w+\s*\|)?\s*(\d{4})\s*\|\s*(\d{1,2})\s*\|\s*(\d{1,2})", box, re.I)
        players[page["title"]] = {"qid": (page.get("pageprops") or {}).get("wikibase_item"),
                                  "birth": [int(birth.group(1)), int(birth.group(2)), int(birth.group(3))] if birth else None,
                                  "position": re.sub(r"\[\[(?:[^\]|]*\|)?([^\]]*)\]\]", r"\1", field(box, "position"))[:80],
                                  "rows": rows}
    if (i // 50) % 20 == 0:
        print("fichas %d/%d, con clubes nuestros: %d" % (min(i + 50, len(names)), len(names), len(players)), flush=True)

os.makedirs(OUT, exist_ok=True)
with gzip.open(os.path.join(OUT, "wikipedia.json.gz"), "wt", encoding="utf-8") as f:
    json.dump({"players": players, "categories": {c: sorted(v) for c, v in club_cat.items()}}, f,
              ensure_ascii=False, separators=(",", ":"), sort_keys=True)
with open(os.path.join(OUT, "errores_wikipedia.json"), "w", encoding="utf-8") as f:
    json.dump(errors, f, ensure_ascii=False, indent=1)
print("listo: %d jugadores con fichas útiles, %d errores" % (len(players), len(errors)))
