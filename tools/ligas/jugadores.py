# Ligas de Sudamérica 2006-2026 (referencia de uso propio, no para el juego). Paso 2: jugadores.
# Para cada club que aparece en alguna temporada de out/temporadas.json (tabla de posiciones o entre
# los más enlazados) trae de Wikidata todas sus membresías P54 con fechas y precisión, y de cada
# jugador el nombre (es, pt, en), la fecha de nacimiento y las posiciones (P413). Guarda
# out/jugadores.json.gz. Uso: python tools/ligas/jugadores.py tools/ligas/out
import gzip
import json
import os
import sys
import time
import urllib.parse
import urllib.request

UA = "FutbolistaDeckbuilder-ligas/1.0 (https://github.com/vKieferv/BONVALET; datos de referencia)"
SPARQL = "https://query.wikidata.org/sparql"
OUT = sys.argv[1] if len(sys.argv) > 1 else "out"
errors = []


def sparql(query):
    time.sleep(1.0)
    data = urllib.parse.urlencode({"query": query, "format": "json"}).encode()
    err = None
    for attempt in range(5):
        try:
            req = urllib.request.Request(SPARQL, data=data, headers={"User-Agent": UA, "Accept": "application/sparql-results+json"})
            with urllib.request.urlopen(req, timeout=120) as r:
                res = json.loads(r.read().decode("utf-8"))
            return [{k: v["value"] for k, v in b.items()} for b in res["results"]["bindings"]]
        except Exception as e:  # noqa: BLE001
            err = "%s (intento %d): %s" % (query[:80].replace("\n", " "), attempt + 1, e)
            print(err, flush=True)
            time.sleep(10 * (attempt + 1))
    errors.append(err)
    return None


def qid(uri):
    return uri.rsplit("/", 1)[-1] if uri else None


temporadas = json.load(open(os.path.join(OUT, "temporadas.json"), encoding="utf-8"))
clubs = set()
for country, seasons in temporadas["seasons"].items():
    for s in seasons:
        for lang, items in (s.get("table") or {}).items():
            clubs.update(items)
        ranked = sorted(s["clubs"].items(), key=lambda kv: -max(kv[1].values()))
        clubs.update(q for q, _ in ranked[:30])
print("clubes:", len(clubs), flush=True)

result = {"clubs": {}, "players": {}}
for i, club in enumerate(sorted(clubs)):
    rows = sparql("""
SELECT ?player ?st (SAMPLE(?s) AS ?start) (SAMPLE(?sp) AS ?startPrec) (SAMPLE(?e) AS ?end) (SAMPLE(?ep) AS ?endPrec)
       (SAMPLE(?loan) AS ?loaned) WHERE {
  ?player p:P54 ?st . ?st ps:P54 wd:%s .
  FILTER NOT EXISTS { ?st wikibase:rank wikibase:DeprecatedRank }
  OPTIONAL { ?st pqv:P580 ?sv . ?sv wikibase:timeValue ?s ; wikibase:timePrecision ?sp }
  OPTIONAL { ?st pqv:P582 ?ev . ?ev wikibase:timeValue ?e ; wikibase:timePrecision ?ep }
  OPTIONAL { ?st pq:P1642 ?loan }
} GROUP BY ?player ?st""" % club)
    if rows is None:
        continue
    stints = []
    for r in rows:
        stints.append([qid(r["player"]), (r.get("start") or "")[:10] or None, int(r.get("startPrec") or 0),
                       (r.get("end") or "")[:10] or None, int(r.get("endPrec") or 0), bool(r.get("loaned"))])
        result["players"].setdefault(qid(r["player"]), None)
    result["clubs"][club] = stints
    print("%d/%d %s %d membresías" % (i + 1, len(clubs), club, len(stints)), flush=True)

# Solo se piden datos de jugadores con alguna membresía que pueda tocar 2006-2026.
def relevant(st):
    s, e = st[1], st[3]
    if e and int(e[:4]) < 2006:
        return False
    if s and int(s[:4]) > 2026:
        return False
    return True


wanted = sorted({st[0] for stints in result["clubs"].values() for st in stints if relevant(st)})
print("jugadores a detallar:", len(wanted), flush=True)
for i in range(0, len(wanted), 300):
    batch = wanted[i:i + 300]
    rows = sparql("""
SELECT ?p (SAMPLE(?les) AS ?es) (SAMPLE(?lpt) AS ?pt) (SAMPLE(?len) AS ?en) (GROUP_CONCAT(DISTINCT ?d; separator="|") AS ?dob)
       (GROUP_CONCAT(DISTINCT ?posl; separator="|") AS ?pos) WHERE {
  VALUES ?p { %s }
  OPTIONAL { ?p rdfs:label ?les FILTER(lang(?les) = "es") }
  OPTIONAL { ?p rdfs:label ?lpt FILTER(lang(?lpt) = "pt") }
  OPTIONAL { ?p rdfs:label ?len FILTER(lang(?len) = "en") }
  OPTIONAL { ?p p:P569 ?ds . ?ds psv:P569 ?dv . ?dv wikibase:timeValue ?dt ; wikibase:timePrecision ?dp .
             FILTER NOT EXISTS { ?ds wikibase:rank wikibase:DeprecatedRank }
             BIND(CONCAT(SUBSTR(STR(?dt), 1, 10), "/", STR(?dp)) AS ?d) }
  OPTIONAL { ?p wdt:P413 ?posq . ?posq rdfs:label ?posl FILTER(lang(?posl) = "en") }
} GROUP BY ?p""" % " ".join("wd:" + q for q in batch))
    for r in rows or []:
        result["players"][qid(r["p"])] = {"es": r.get("es"), "pt": r.get("pt"), "en": r.get("en"),
                                          "dob": [x for x in (r.get("dob") or "").split("|") if x],
                                          "pos": [x for x in (r.get("pos") or "").split("|") if x]}
    print("detalle %d/%d" % (min(i + 300, len(wanted)), len(wanted)), flush=True)

result["players"] = {q: v for q, v in result["players"].items() if v is not None}
os.makedirs(OUT, exist_ok=True)
with gzip.open(os.path.join(OUT, "jugadores.json.gz"), "wt", encoding="utf-8") as f:
    json.dump(result, f, ensure_ascii=False, separators=(",", ":"), sort_keys=True)
with open(os.path.join(OUT, "errores_jugadores.json"), "w", encoding="utf-8") as f:
    json.dump(errors, f, ensure_ascii=False, indent=1)
print("listo: %d clubes, %d jugadores, %d errores" % (len(result["clubs"]), len(result["players"]), len(errors)))
