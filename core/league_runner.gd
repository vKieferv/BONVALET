class_name LeagueRunner
extends RefCounted

# Liga todos contra todos. Cada duelo A vs B de la semilla s se resuelve así:
#   goles de A = A jugando el partido s contra la defensa de B
#   goles de B = B jugando el partido s contra la defensa de A
# Los k*(k-1) "medios duelos" son independientes y se reparten entre hilos.
# templates_by_profile: el mazo (diccionarios) de cada perfil, en el mismo orden que `profiles`.
# Seguro para ejecutar desde un hilo.
static func run(profiles: Array, n: int, cfg: Dictionary, templates_by_profile: Array, progress: Callable = Callable()) -> Dictionary:
    var k := profiles.size()
    var jobs: Array = []
    for i in k:
        for j in k:
            if i != j:
                jobs.append(Vector2i(i, j))
    var total := jobs.size()
    var results: Array = []
    results.resize(total)
    var mutex := Mutex.new()
    var counter := [0]

    var task := func(idx: int) -> void:
        var pair: Vector2i = jobs[idx]
        var c := SimRunner.cfg_vs(cfg, profiles[pair.y])
        results[idx] = SimRunner.run(profiles[pair.x], n, c, templates_by_profile[pair.x])
        mutex.lock()
        counter[0] += 1
        var f: float = float(counter[0]) / float(total)
        mutex.unlock()
        if progress.is_valid():
            progress.call(f)

    var gid := WorkerThreadPool.add_group_task(task, total, -1, false, "Liga")
    WorkerThreadPool.wait_for_group_task_completion(gid)
    return summarize(profiles, n, jobs, results)


static func summarize(profiles: Array, n: int, jobs: Array, results: Array) -> Dictionary:
    var k := profiles.size()
    var lookup := {}
    for idx in jobs.size():
        lookup[jobs[idx]] = idx

    var acc: Array = []
    var h2h: Array = []
    var names: Array = []
    for i in k:
        var tm: Array = []
        tm.resize(MatchEngine.MAX_MOMENTS)
        tm.fill(0)
        acc.append({"pg": 0, "pe": 0, "pp": 0, "gf": 0, "gc": 0, "tired": 0, "plays": 0, "injuries": 0,
            "tm": tm, "pm": tm.duplicate()})
        var row: Array = []
        row.resize(k)
        h2h.append(row)
        names.append(profiles[i].profile_name)

    for i in k:
        for j in range(i + 1, k):
            var gi: PackedInt32Array = results[lookup[Vector2i(i, j)]]["goals"]
            var gj: PackedInt32Array = results[lookup[Vector2i(j, i)]]["goals"]
            var wi := 0
            var wj := 0
            var dr := 0
            for s in n:
                acc[i]["gf"] += gi[s]
                acc[i]["gc"] += gj[s]
                acc[j]["gf"] += gj[s]
                acc[j]["gc"] += gi[s]
                if gi[s] > gj[s]:
                    wi += 1
                elif gj[s] > gi[s]:
                    wj += 1
                else:
                    dr += 1
            acc[i]["pg"] += wi
            acc[i]["pp"] += wj
            acc[i]["pe"] += dr
            acc[j]["pg"] += wj
            acc[j]["pp"] += wi
            acc[j]["pe"] += dr
            h2h[i][j] = {"w": wi / float(n), "d": dr / float(n), "l": wj / float(n)}
            h2h[j][i] = {"w": wj / float(n), "d": dr / float(n), "l": wi / float(n)}

    for idx in jobs.size():
        var i: int = jobs[idx].x
        var t: Dictionary = results[idx]["totals"]
        acc[i]["tired"] += t["tired_plays"]
        acc[i]["plays"] += t["plays"]
        acc[i]["injuries"] += t["injuries"]
        for m in MatchEngine.MAX_MOMENTS:
            acc[i]["tm"][m] += t["tired_m%d" % m]
            acc[i]["pm"][m] += t["plays_m%d" % m]

    var rows: Array = []
    for i in k:
        var a: Dictionary = acc[i]
        var matches := float((k - 1) * n)
        var bm: Array = []
        for m in MatchEngine.MAX_MOMENTS:
            bm.append({
                "pct": 100.0 * a["tm"][m] / maxf(1.0, float(a["pm"][m])),
                "per_match": a["tm"][m] / matches,
            })
        rows.append({
            "name": names[i],
            "pj": (k - 1) * n,
            "pg": a["pg"], "pe": a["pe"], "pp": a["pp"],
            "gf": a["gf"], "gc": a["gc"],
            "pts": 3 * a["pg"] + a["pe"],
            "tired_pct": 100.0 * a["tired"] / maxf(1.0, float(a["plays"])),
            "injury_pct": 100.0 * a["injuries"] / float((k - 1) * n),
            "by_moment": bm,
        })
    rows.sort_custom(LeagueRunner._cmp_rows)
    return {"rows": rows, "h2h": h2h, "names": names}


# Orden: puntos, diferencia de gol, goles a favor.
static func _cmp_rows(x: Dictionary, y: Dictionary) -> bool:
    if x["pts"] != y["pts"]:
        return x["pts"] > y["pts"]
    var dx: int = x["gf"] - x["gc"]
    var dy: int = y["gf"] - y["gc"]
    if dx != dy:
        return dx > dy
    return x["gf"] > y["gf"]
