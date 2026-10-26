# CLAUDE.md

This file provides guidance to Claude Code (claude.ai/code) when working with code in this repository.

Futbolista Deckbuilder 2006: deckbuilder de fútbol chileno (Torneo Nacional 2006) en Godot 4.7.2 / GDScript. El usuario habla español; código, comentarios y textos de UI van en español.

## Dónde está cada cosa
- Este directorio (`futbolista/`) es a la vez el proyecto Godot (escena principal `res://scenes/match_view.tscn`) y la raíz del repositorio git.
- La carpeta padre (fuera del repo) guarda el binario `Godot_v4.7.2-stable_win64_console.exe`, `versiones/` y zips históricos que el usuario recibe de otras fuentes. Esos zips pueden venir escritos para Godot 4.3 y no compilar en 4.7: compáralos con el repo antes de copiarlos encima, porque pueden pisar correcciones. Las copias sueltas de `league_manager.gd` y los JSON de liga que hay ahí están desactualizadas; la versión que vale es la del repo.

## Comandos
Verificación completa (compila todo + juega partidos en headless). Úsala tras cualquier cambio en `.gd`, `.tscn` o `data/*.json`; detalles en el skill `godot-check`:
```powershell
& .\.claude\skills\godot-check\check.ps1            # -SkipSmoke solo compila, -Balance agrega métricas por arquetipo
```
Pruebas individuales (desde la raíz del repo; `--import` primero si creaste o renombraste scripts con `class_name`):
```powershell
..\Godot_v4.7.2-stable_win64_console.exe --headless --path . --import
..\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/check_scripts.gd
..\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/smoke_match.gd -- --matches=3
..\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://core/sim.gd   # métricas de balance
```
`scenes/sim_dashboard.tscn` es la versión visual de la simulación (duelo 1v1 y liga todos contra todos con hilos), para abrir en el editor.

## Arquitectura
**`core/` es lógica pura (`RefCounted`, sin nodos) y `scenes/` es la UI.** Mantener esa separación: el motor se ejecuta miles de veces en hilos desde `SimRunner`/`LeagueRunner`, así que `core/` no puede depender de escenas, del árbol ni del RNG global (cada motor recibe su `RandomNumberGenerator`).

- **Modelo de partido actual:** un solo jugador (`PlayerStats`: energía, zonas SAFE/TIRED/EXHAUSTED, Visión → tamaño de mano) juega 2-5 "Momentos Clave". Cada momento exige 2-4 jugadas exitosas terminando en una carta SHOT; 2 fallos lo pierden. Rachas activan Flow (la carta se queda en la mano y cuesta más cada reuso). La postura LOW/NORMAL/HIGH cambia la regeneración entre momentos y el número de momentos. Todo esto vive en `MatchEngine`; `DeckManager` solo maneja las pilas.
- **El GDD va por delante del código.** El documento de diseño describe 11 jugadores, posesión ataque/defensa, Ejecutor Natural, perfiles de DT con tamaños de mazo distintos y modo carrera; nada de eso existe todavía, y algunos números del GDD difieren de las constantes (`RECOVERY_RATIO`, `INJURY_CHANCE_*` en `match_engine.gd`). Antes de implementar una mecánica del GDD, revisa qué hace el código realmente.
- **Arquetipos = `BotProfile`** (Resource con presets estáticos `tiki_taka()`, `catenaccio()`, etc.). `CoachBot.choose()` es el cerebro que elige carta según el perfil. El mismo `MatchEngine` sirve para el jugador humano y para los bots.
- **Rival en `match_view`:** un segundo `MatchEngine` "fantasma" movido por `CoachBot`, que juega un Momento cada vez que le toca en la línea de tiempo (`_play_rival_moment`) para reaccionar a la postura actual del jugador. Los momentos de ambos se intercalan por minuto en `_next_step`. No hay interacción directa entre los dos motores más allá de la postura y la dificultad.
- **Dificultad por rival:** `SimRunner.difficulty_vs()` (defensa del arquetipo) + `facilities_level` del club; `exploit_rival_space` (perfiles con `punishes_passivity` contra postura LOW). `match_view` y `SimRunner` deben aplicar las mismas reglas para que el simulador mida lo que se juega.
- **Data-driven:** `data/cards.json` (cartas con `count`, `foreign`, `age`, `player_id` opcionales), `data/league_config.json` (reglas de liga, salarios) y `data/teams_chile_2006.json` (32 clubes con arquetipo, colores, presupuesto, instalaciones). `scripts/league_manager.gd` los carga, traduce arquetipo → `BotProfile` y valida mazos (`validate_deck`). `league_config.json` tiene campos que todavía nadie lee (ver su `_notes`).
- **`SimRunner` usa semillas 1..n**, así dos perfiles juegan exactamente los mismos partidos (comparación pareada). No introducir aleatoriedad fuera del `rng` del motor o se rompe esa comparación.

## Convenciones
- Godot 4.7 no infiere el tipo desde un `Variant` (`var x := dict["k"]` no compila): usa tipo explícito (`var x: float = dict["k"]`).
- La indentación varía por archivo: tabs en `core/` y `tests/` (salvo `bot_profile.gd`, `coach_bot.gd` y `league_runner.gd`), 4 espacios en `scenes/` y `scripts/`. Respeta la del archivo que editas; GDScript no admite mezclarlas dentro de un archivo.
- Las constantes de balance se comentan con su efecto en el juego (ver cabecera de `match_engine.gd`); al cambiarlas, corre `godot-check -Balance` y compara.
- No mates procesos Godot por nombre: el usuario suele tener el editor abierto.
