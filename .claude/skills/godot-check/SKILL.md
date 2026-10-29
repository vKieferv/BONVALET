---
name: godot-check
description: Verifica Futbolista Deckbuilder con Godot 4.7.2 en headless - compila todos los .gd/.tscn, juega partidos completos de match_view y opcionalmente imprime métricas de balance por arquetipo. Úsalo después de cualquier cambio en archivos .gd, .tscn o data/*.json, antes de decir que algo funciona, y cuando el usuario pida probar, verificar o balancear el juego.
---

# godot-check

Ejecuta desde la raíz del repo (`futbolista/`), sin cambiar la política de ejecución. Godot se busca en `$env:GODOT`, en la carpeta padre del repo y en el PATH:

```powershell
& .\.claude\skills\godot-check\check.ps1
```

En Linux (sesiones en la nube, GitHub Actions) usa `check.sh` con los mismos pasos; si no encuentra Godot (`$GODOT`, PATH o `~/.cache/godot`) descarga la versión oficial 4.7.2 desde github.com:

```bash
bash .claude/skills/godot-check/check.sh            # --skip-smoke, --balance, --matches N
```

GitHub Actions (`.github/workflows/godot-check.yml`) lo corre en cada push a `main` y en cada PR; el balance completo se lanza a mano desde la pestaña Actions ("Run workflow" → balance). Los logs quedan como artefacto `godot-check-logs`.

Opciones de `check.ps1`:
- `-Matches N` — partidos de la prueba de humo (5 por defecto; uno por arquetipo, rotando la postura).
- `-Balance` — además corre `core/sim.gd` (semillas fijas): tabla por arquetipo, peligro de cada rival, partidos de Colo-Colo, la matriz neutral en tres etapas de la temporada (inicio, +4 y +8 cartas de crecimiento, cada una con su EN RANGO / FUERA DE RANGO) y la constructibilidad. Tarda más; úsalo al tocar constantes de balance, `coach_bot.gd`, `bot_profile.gd`, `cards.json` o `decks.json`.
- `-SkipSmoke` — solo compilar (rápido, para cambios que no tocan la escena del partido).
- `-TimeoutSec N` (240) por paso y `-BalanceTimeoutSec N` (600) para `sim.gd`, que con el planificador de `CoachBot` y la matriz en tres etapas tarda unos 5-6 minutos.
- Para comparar palancas de balance antes de tocar constantes, usa la skill `balance-lab` (más rápida que `-Balance` y con variantes lado a lado).

## Qué hace
1. `--import`: regenera la caché de `class_name` (necesario tras crear o renombrar scripts).
2. `tests/check_scripts.gd`: carga cada `.gd` y `.tscn`; falla si alguno no compila.
3. `tests/engine_rules.gd`, `tests/career_rules.gd` y `tests/data_rules.gd`: reglas sin escena. `data_rules` valida `data/history_2006.json` (calendario de una vuelta, tablas calculadas desde los resultados, llaves de playoffs, acumulada y descenso) y prueba esas reglas con temporadas sintéticas. `career_rules` revisa los planteles de los 32 clubes (18 jugadores, Sub-21, extranjeros, ids únicos, 11 titulares), el mazo de inicio de cada club contra `validate_deck` y el tamaño 10-20 (también con +8 cartas), el Ejecutor Natural por titulares y la semana del modo carrera. `engine_rules` revisa (catálogo y `decks.json`, mazo de inicio de cada arquetipo, filtro de posesión, Ejecutor Natural, defensa y despeje de emergencia, fases de Kamikaze, clubes grandes vs LOW, `validate_deck` positivo y negativo, integridad de los 32 clubes).
4. `tests/smoke_match.gd`: instancia `match_view.tscn`, juega partidos completos (ataque y defensa, con algún despeje de emergencia) y comprueba que ningún partido se cuelgue, que el marcador coincida con `MatchEngine.stats`, que la postura no cambie durante una jugada, que cada carta muestre su efecto (avanza, roba, corta), que haya fases defensivas y que `exploit_rival_space` se active al jugar LOW contra un rival que castiga la pasividad. Después, `tests/smoke_career.gd` juega dos semanas del modo carrera (calendario → partido → calendario) y comprueba que la carrera avance.

Cualquier `SCRIPT ERROR` en ejecución cuenta como falla, aunque Godot salga con código 0. **La salida es corta para ahorrar tokens:** si pasa, una sola línea (`✅ OK: godot-check pasó`), más las métricas con `-Balance`; si falla, las últimas 25 líneas del resumen y `❌ FALLA: godot-check (pasos)`, con código 1. El resumen de todos los pasos queda en `%TEMP%\godot-check\resumen.txt` (`-Full` / `--full` lo imprime entero) y la salida cruda de cada paso en `%TEMP%\godot-check\<paso>.out.txt` y `.err.txt`.

## Al fallar
- Lee `%TEMP%\godot-check\<paso>.err.txt`: trae el archivo y la línea del error de GDScript.
- Error típico de Godot 4.7: `Cannot infer the type of "x"` → `var x := dict["k"]` necesita tipo explícito (`var x: float = ...`).
- Si agregas una regla nueva a la escena del partido (algo que el jugador pueda romper), agrega su comprobación en `tests/smoke_match.gd`.
- `exit 1` del script termina la sesión de PowerShell actual: no encadenes comandos de limpieza después en la misma llamada.
- No mates procesos Godot por nombre: el usuario puede tener el editor abierto.
