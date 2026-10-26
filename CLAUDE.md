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

- **Modelo de partido actual:** un solo jugador (`PlayerStats`: energía, zonas SAFE/TIRED/EXHAUSTED, Visión → tamaño de mano, `player_id` = quién ejecuta) juega 2-5 "Momentos Clave" de ataque. Cada momento exige 2-4 jugadas exitosas terminando en una carta SHOT; 2 fallos lo pierden. Rachas activan Flow (la carta se queda en la mano y cuesta más cada reuso). La postura LOW/NORMAL/HIGH cambia la regeneración entre momentos y el número de momentos.
- **Posesión:** el mazo es unificado (18-20 cartas, `DeckManager.DECK_MIN/MAX`) y `DeckManager.possession` (`POSSESSION_ATTACK`/`POSSESSION_DEFENSE`) filtra qué se roba; las cartas de la otra fase se quedan en la pila. Antes de cada ataque rival, `MatchEngine.begin_defense()` abre una mano defensiva (PRESS/BLOCK/INTERCEPT/CLEARANCE, máx. `DEFENSE_MAX_PLAYS` jugadas) o el Despeje de Emergencia (fuera del mazo). `end_defense()` devuelve `{pressure, block, cancelled, emergency}`, que quien arma el partido aplica al motor atacante (`opponent_pressure`/`opponent_block`, `skip_moment()` si se cortó, `grant_extra_moment()` tras un despeje de emergencia).
- **Probabilidad de éxito:** `chance_breakdown(card)` es la única fuente; `success_chance()` lo suma, lo acota (5-95%) y lo redondea a puntos enteros, y la carta muestra ese mismo número con el desglose en el tooltip. La tirada es `roll < success_chance` con la energía de *antes* de pagar la carta. Cualquier modificador nuevo se agrega en `chance_breakdown`, nunca directo en la tirada; `engine_rules` y `smoke_match` comprueban que lo mostrado y lo tirado coincidan.
- **Ejecutor Natural:** `card.owner_id == player.player_id` → `+NATURAL_EXECUTOR_BONUS` en `success_chance()`, racha de Flow x2 y señal `natural_executor_played` (la UI la usa para el resplandor). El nombre de la función es `success_chance`, no `calculate_success_chance`.
- **El GDD va por delante del código.** Los 11 titulares existen pero el partido sigue teniendo un solo `PlayerStats` (los titulares solo activan el Ejecutor Natural; sus atributos aún no afectan al motor). Tampoco existen los perfiles de DT con tamaños de mazo distintos, la economía de fichajes ni que los bots defiendan (en `SimRunner` los bots solo atacan, así que el simulador no mide la fase defensiva). Antes de implementar una mecánica del GDD, revisa qué hace el código realmente.
- **Arquetipos = `BotProfile`** (Resource con presets estáticos `tiki_taka()`, `catenaccio()`, etc.). `configure_engine(e)` es el único lugar que pasa el perfil al motor (apertura, desgaste tardío de Kamikaze, bono de castigo a la pasividad). `CoachBot.choose()` elige carta según el perfil. El mismo `MatchEngine` sirve para el jugador humano y para los bots.
- **Rival en `match_view`:** un segundo `MatchEngine` "fantasma" movido por `CoachBot`, que juega un Momento cada vez que le toca en la línea de tiempo (`_rival_event` → `_defend` → `_play_rival_moment`). Los momentos de ambos se intercalan por minuto en `_next_step`. Paridad: el rival arma su mazo con `SquadManager` igual que tú (cartas firma de sus titulares, canteranos) y sus titulares activan el Ejecutor Natural. Para medir a un club en `SimRunner`, pásale `SquadManager.build_match_templates(id, ...)` y `cfg["lineup"]`.
- **Dificultad por club:** vive en `LeagueManager` (`attack_difficulty_vs`, `team_attack_difficulty`, `defense_difficulty_vs`, clubes grandes que castigan tu LOW en `profile_for_team`). `match_view` y `core/sim.gd` usan esas mismas funciones para que el simulador mida lo que se juega; no dupliques constantes de dificultad en escenas.
- **Data-driven:** `data/cards.json` (cartas con `count`, `owner_id`, `nationality`/`foreign`, `age` opcionales), `data/league_config.json` (reglas de liga, salarios) y `data/teams_chile_2006.json` (32 clubes con arquetipo, DT `dt`/`dt_start`, carta firma, colores, presupuesto, instalaciones; las fuentes están en su `_notes`). `scripts/league_manager.gd` los carga, traduce arquetipo → `BotProfile` y valida mazos (`validate_deck`: máx. 6 extranjeros, mín. 2 Sub-21). `league_config.json` tiene campos que todavía nadie lee (ver su `_notes`).
- **`SimRunner` usa semillas 1..n**, así dos perfiles juegan exactamente los mismos partidos (comparación pareada). No introducir aleatoriedad fuera del `rng` del motor o se rompe esa comparación.
- **Modo carrera:** la escena principal es `scenes/calendar_view.tscn` (bloques: sponsor/evento social, entrenamiento/kinesiología, partido). Las reglas viven en `scripts/career.gd` (`Career`); `Career.current` es una variable estática que sobrevive al cambio de escena calendario → `match_view` → calendario (no hay autoload). `match_view` detecta `Career.current.pending_match`: arranca solo contra `rival_id`, aplica la semana con `configure_match()` antes de `engine.start()` y al final llama `record_match()`. Sin carrera, `match_view` es un partido rápido con `QUICK_TEAM_ID`.
- **Planteles:** `data/squads_2006.json` tiene los planteles reales (Colo-Colo, U. de Chile, UC); el resto los genera `SquadGenerator` de forma determinista (semilla = hash del id del club), sin guardarlos. `SquadManager` elige los 11 titulares (`FORMATION`) y arma el mazo: `cards.json` (cartas del DT; las `canterano` pasan a un Sub-21 del plantel) + la carta firma de cada titular (`data/signature_cards.json`, o la plantilla genérica para la figura del club). El Ejecutor Natural se activa si el dueño está en `PlayerStats.lineup`.
- **Masa salarial:** con los presupuestos actuales casi ningún club cabe bajo el tope de `league_config.json`, así que el Bloque 3 la muestra como aviso y no bloquea. `validate_deck` se llama sin `team_id` para las reglas que sí bloquean.
- **Pruebas:** `tests/career_rules.gd` (planteles de los 32 clubes, mazo por club, reglas de la semana), `tests/smoke_career.gd` (dos semanas completas calendario → partido → calendario), `tests/engine_rules.gd` (reglas del motor y de los datos, sin escena), `tests/smoke_match.gd` (partidos completos de `match_view`, incluidas defensas) y `tests/check_scripts.gd` (compila todo). Si agregas una regla, agrégale su comprobación en `engine_rules.gd`.

## Contenido
- Clubes, DT y jugadores son reales (2006). Marcas, sponsors, diarios y canales **nunca** usan nombres reales: siempre parodias nostálgicas (p. ej. Cerveza Glaciar por Cristal, Telnet por Entel, Diario El Chisme por La Cuarta, Televisora Nacional por TVN).
- Datos históricos solo con fuente; si no se puede confirmar, `null` (el juego tiene textos por defecto) y una entrada en `review`. Para planteles, Wikidata (membresía P54 con fechas, nacimiento P569, ciudadanía P27) vía `query.wikidata.org` funcionó bien; Transfermarkt bloquea las consultas.
- Los jugadores generados tienen nombres ficticios; solo la figura del club (de `teams_chile_2006.json`) es real, y su edad queda en `null` si no tiene fuente.

## Convenciones
- Godot 4.7 no infiere el tipo desde un `Variant` (`var x := dict["k"]` no compila): usa tipo explícito (`var x: float = dict["k"]`).
- La indentación varía por archivo: tabs en `core/` y `tests/` (salvo `bot_profile.gd`, `coach_bot.gd` y `league_runner.gd`), 4 espacios en `scenes/` y `scripts/`. Respeta la del archivo que editas; GDScript no admite mezclarlas dentro de un archivo.
- Las constantes de balance se comentan con su efecto en el juego (ver cabecera de `match_engine.gd`); al cambiarlas, corre `godot-check -Balance` y compara.
- No mates procesos Godot por nombre: el usuario suele tener el editor abierto.
