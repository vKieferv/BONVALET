# T-08, segunda pasada: cruce con es.wikipedia. Para cada jugador con membresía fechada en 2006 en
# alguno de los 16 clubes (según la instantánea de fetch.py) guarda la ficha de su artículo en
# es.wikipedia (plantilla de futbolista: trayectoria por años). Guarda también el wikitexto de las
# finales y torneos 2006. Uso: python tools/t08/fetch_wiki.py tools/t08/out
import json
import os
import sys
import time
import urllib.parse
import urllib.request

UA = "FutbolistaDeckbuilder-T08/1.0 (https://github.com/vKieferv/BONVALET; datos de planteles 2006)"
API = "https://es.wikipedia.org/w/api.php"
OUT = sys.argv[1] if len(sys.argv) > 1 else "out"
PAGES = ["Final del Torneo Clausura 2006 (Chile)", "Final del Torneo Apertura 2006 (Chile)",
         "Torneo Apertura 2006 (Chile)", "Torneo Clausura 2006 (Chile)"]
errors = []


def api(params):
    params = dict(params, format="json", formatversion=2)
    url = API + "?" + urllib.parse.urlencode(params)
    for attempt in range(4):
        try:
            req = urllib.request.Request(url, headers={"User-Agent": UA})
            with urllib.request.urlopen(req, timeout=60) as r:
                return json.loads(r.read().decode("utf-8"))
        except Exception as e:  # noqa: BLE001
            err = "%s (intento %d): %s" % (url[:100], attempt + 1, e)
            print(err, flush=True)
            time.sleep(5 * (attempt + 1))
    errors.append(err)
    return None


def wikitext(titles):
    """{título pedido: wikitexto} siguiendo redirecciones."""
    res = api({"action": "query", "prop": "revisions", "rvprop": "content", "rvslots": "main",
               "redirects": 1, "titles": "|".join(titles)})
    out = {}
    if not res:
        return out
    q = res.get("query", {})
    back = {}
    for kind in ("normalized", "redirects"):
        for m in q.get(kind, []):
            back[m["to"]] = back.get(m["from"], m["from"])
    for page in q.get("pages", []):
        revs = page.get("revisions")
        if not revs:
            continue
        out[back.get(page["title"], page["title"])] = revs[0]["slots"]["main"]["content"]
    return out


def infobox(text):
    """La primera plantilla {{Ficha de ...}} completa (llaves balanceadas)."""
    i = text.find("{{Ficha de")
    if i < 0:
        i = text.find("{{ficha de")
    if i < 0:
        return None
    depth = 0
    j = i
    while j < len(text) - 1:
        if text[j:j + 2] == "{{":
            depth += 1
            j += 2
            continue
        if text[j:j + 2] == "}}":
            depth -= 1
            j += 2
            if depth == 0:
                return text[i:j]
            continue
        j += 1
    return text[i:]


def year(v):
    return int(v[:4]) if v else None


chosen = json.load(open(os.path.join(OUT, "clubs_elegidos.json"), encoding="utf-8"))
players = json.load(open(os.path.join(OUT, "jugadores.json"), encoding="utf-8"))
wanted = set()
for key, info in chosen.items():
    rows = json.load(open(os.path.join(OUT, "membresias", key + ".json"), encoding="utf-8"))
    for r in rows:
        s, e = year(r.get("start")), year(r.get("end"))
        if r["club"] == info["qid"] and s is not None and e is not None and s <= 2006 <= e:
            wanted.add(r["player"])
titles = {}
for q in sorted(wanted):
    url = (players.get(q) or {}).get("eswiki")
    if url:
        titles[urllib.parse.unquote(url.rsplit("/wiki/", 1)[1]).replace("_", " ")] = q
fichas = {}
names = sorted(titles)
for i in range(0, len(names), 40):
    time.sleep(0.5)
    for title, text in wikitext(names[i:i + 40]).items():
        fichas[titles.get(title, title)] = {"title": title, "ficha": infobox(text)}
os.makedirs(os.path.join(OUT, "wikipedia"), exist_ok=True)
with open(os.path.join(OUT, "wikipedia", "fichas.json"), "w", encoding="utf-8") as f:
    json.dump(fichas, f, ensure_ascii=False, indent=1, sort_keys=True)
for title, text in wikitext(PAGES).items():
    with open(os.path.join(OUT, "wikipedia", title.replace(" ", "_") + ".wikitext"), "w", encoding="utf-8") as f:
        f.write(text)
with open(os.path.join(OUT, "wikipedia", "errores.json"), "w", encoding="utf-8") as f:
    json.dump({"errores": errors, "sin_articulo": sorted(wanted - set(titles.values())),
               "sin_ficha": sorted(q for q, v in fichas.items() if not v["ficha"])}, f, ensure_ascii=False, indent=1)
print("listo: %d jugadores, %d con artículo, %d fichas, %d errores" % (len(wanted), len(titles), len(fichas), len(errors)))
