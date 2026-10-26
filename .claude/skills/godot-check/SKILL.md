---
name: godot-check
description: Verifica Futbolista Deckbuilder con Godot 4.7.2 en headless - compila todos los .gd/.tscn, juega partidos completos de match_view y opcionalmente imprime métricas de balance por arquetipo. Úsalo después de cualquier cambio en archivos .gd, .tscn o data/*.json, antes de decir que algo funciona, y cuando el usuario pida probar, verificar o balancear el juego.
---

# godot-check

Ejecuta desde la raíz del repo (`futbolista/`), sin cambiar la política de ejecución. Godot se busca en `$env:GODOT`, en la carpeta padre del repo y en el PATH:

```powershell
& .\.claude\skills\godot-check\check.ps1
```

Opciones:
- `-Matches N` — partidos de la prueba de humo (5 por defecto; uno por arquetipo, rotando la postura).
- `-Balance` — además corre `core/sim.gd` (2000 partidos por perfil, semillas fijas): goles, Flow, cansancio, lesiones por arquetipo. Tarda más; úsalo al tocar constantes de balance, `coach_bot.gd`, `bot_profile.gd` o `cards.json`.
- `-SkipSmoke` — solo compilar (rápido, para cambios que no tocan la escena del partido).

## Qué hace
1. `--import`: regenera la caché de `class_name` (necesario tras crear o renombrar scripts).
2. `tests/check_scripts.gd`: carga cada `.gd` y `.tscn`; falla si alguno no compila.
3. `tests/smoke_match.gd`: instancia `match_view.tscn`, juega partidos completos eligiendo la primera carta jugable y comprueba que ningún partido se cuelgue, que el marcador coincida con `MatchEngine.stats`, que la postura no cambie dentro de un Momento Clave y que `exploit_rival_space` se active al jugar LOW contra un Contragolpe.

El resultado final es `RESULTADO: OK` o `RESULTADO: FALLA (pasos)`; el script sale con código 1 si falla. Los logs completos quedan en `%TEMP%\godot-check\`.

## Al fallar
- Lee `%TEMP%\godot-check\<paso>.err.txt`: trae el archivo y la línea del error de GDScript.
- Error típico de Godot 4.7: `Cannot infer the type of "x"` → `var x := dict["k"]` necesita tipo explícito (`var x: float = ...`).
- Si agregas una regla nueva a la escena del partido (algo que el jugador pueda romper), agrega su comprobación en `tests/smoke_match.gd`.
- `exit 1` del script termina la sesión de PowerShell actual: no encadenes comandos de limpieza después en la misma llamada.
- No mates procesos Godot por nombre: el usuario puede tener el editor abierto.
