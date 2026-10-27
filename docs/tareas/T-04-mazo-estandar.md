# T-04 · Mazo estándar, cartas de rasgo y balance por etapa de la temporada

Brief para una sesión autónoma (skill `tarea-autonoma`). Primera de las tres tareas que implementan M2
(después vienen T-05 y T-06, que dependen de esta).

- **Hito:** M2
- **Rama:** `tarea/t-04-mazo-estandar`
- **Decisiones:** D-23 (mazo estándar y rasgos), D-22 (los rivales crecen), D-14 (objetivos de balance)
- **Referencia medida:** `tests/lab/m2_crecimiento.json` y `tests/lab/m2_propuesta.json` (las cartas y
  listas de abajo salen de ahí); GDD 3.5.

## Objetivo
Que todo el juego use el **mazo estándar**: cada club arranca con las 11 cartas básicas del DT + la
carta de rasgo de su arquetipo + la firma de su figura (12 cartas), las cartas nuevas se vean bien en
pantalla, y `godot-check -Balance` mida el sistema nuevo al inicio, a mitad y al final de la temporada.

## Alcance
1. **Cartas nuevas en `data/cards.json`**, con `"count": 0` (así no entran al mazo clásico de 19 que
   usan las pruebas y el panel de simulación). Valores exactos:
   | id | nombre | tipo | clase | PA | desgaste | bono | efectos |
   |---|---|---|---|---|---|---|---|
   | `remate_simple` | Remate simple | basic | shot | 1 | 4 | 0.10 | — |
   | `marca` | Marca | basic | press | 1 | 2 | 0.04 | — |
   | `toque_toque` | Toque-toque | tactical | pass | 0 | 2 | 0.20 | `"draw": 1` |
   | `pelotazo` | Pelotazo | tactical | pass | 1 | 3 | 0.00 | `"steps": 2` |
   | `cerrojo` | Cerrojo | tactical | clearance | 1 | 2 | 0.00 | — |
   | `remate_en_carrera` | Remate en carrera | tactical | shot | 1 | 10 | 0.25 | tags `["fisica"]` |
   | `anticipo` | Anticipo | tactical | intercept | 1 | 4 | 0.00 | — |
   Actualiza el `_notes` de `cards.json` (catálogo + mazo clásico; el mazo de juego sale de `decks.json`).
2. **`data/decks.json` nuevo** con `_notes` y:
   - `"estandar"`: `pase_corto` ×4, `promesa_control` ×2, `remate_simple`, `marca` ×2, `despeje`, `"@rasgo"`.
   - `"rasgos"`: Tiki-Taka `toque_toque`, Directo `pelotazo`, Catenaccio `cerrojo`, Kamikaze
     `remate_en_carrera`, Contragolpe `anticipo`.
   - `"crecimiento"` (8 cartas por arquetipo, en orden; las usa `sim.gd` ahora y T-06 para los rivales):
     - Tiki-Taka: `pase_filtrado, presion, intercepcion, remate_primera, amague, despeje, tiro_lejano, centro`
     - Directo: `tiro_lejano, despeje, remate_primera, presion, centro, intercepcion, chilena, pase_al_pie`
     - Catenaccio: `bloqueo, tiro_lejano, despeje, remate_primera, pausa, intercepcion, presion, pase_al_pie`
     - Kamikaze: `presion, remate_primera, despeje, amague, chilena, intercepcion, bloqueo, movimiento`
     - Contragolpe: `intercepcion, pase_filtrado, tiro_lejano, despeje, remate_primera, bloqueo, movimiento, presion`
3. **Constructores** (en `CardDB` o `SquadManager`, donde encaje mejor; documenta la elección):
   catálogo de cartas por id (ignora `count`), `starter_templates(team_id)` (estándar + rasgo del
   arquetipo del club, resuelto contra el catálogo) y `season_templates(team_id, extra)` (estándar +
   las primeras `extra` cartas de su `crecimiento`, sin pasar de `DeckManager.DECK_MAX`). Después,
   `build_match_templates` sigue igual: asigna las Promesas a Sub-21 y suma las firmas de los titulares.
4. **Todo el juego pasa al mazo estándar:** la carrera (`Career.build_deck`), `match_view` (tu equipo y
   el rival, en carrera y en partido rápido) y las herramientas (`core/sim.gd`, `tests/balance_lab.gd`,
   `scenes/sim_dashboard.gd` si es simple). En esta tarea todos juegan con el mazo de inicio (`extra` 0):
   el crecimiento del tuyo llega con T-05 y el de los rivales con T-06.
5. **`DeckManager.DECK_MIN` pasa de 18 a 10** (`DECK_MAX` sigue en 20). Revisa los mensajes y pruebas
   que mencionan 18.
6. **`CardUI` muestra los efectos** (pilar 2): una línea visible corta y el detalle en el tooltip para
   `steps > 1` ("Avanza 2"), `draw > 0` ("Si sale, robas 1 carta"), `counter` ("Si sale, contragolpe"),
   `effect` propio, y las clases que cortan el ataque (Despeje, Cerrojo, Anticipo, Intercepción: "Corta el
   ataque"; la intercepción además deja el contragolpe). Si `smoke_match` puede comprobar algo de esto
   barato, agrégalo.
7. **Balance oficial (`core/sim.gd`)**: la matriz neutral, los duelos de Colo-Colo y la constructibilidad
   pasan al mazo estándar. La matriz se imprime en **tres etapas**: inicio (`extra` 0), mitad (4) y final
   (8), cada una con goles, lesiones y cansancio; la línea "EN RANGO / FUERA DE RANGO" de goles se aplica a
   cada etapa. La tabla de arquetipos puede usar el mazo estándar con el rasgo de cada preset.
8. **`tests/balance_lab.gd`**: su línea base tiene que reproducir la matriz nueva (inicio). Deja una
   forma de pedir el mazo clásico (`"deck": "clasico"` o similar) y la de `extra` (las claves `picks` y
   `pick_pools` pueden pasar a leer `crecimiento` por defecto). Actualiza `.claude/skills/balance-lab/SKILL.md`.
9. **Pruebas:** `engine_rules` revisa que todas las cartas del catálogo (también las de `count` 0)
   declaren PA y desgaste, y que el mazo de inicio de cada arquetipo tenga su rasgo y 12 cartas con la
   firma. `career_rules` revisa que el mazo de inicio de los 32 clubes pase `validate_deck` (máx. 6
   extranjeros, mín. 2 Sub-21) y el tamaño 10-20, y que `season_templates(..., 8)` no pase de 20.
10. **Documentación:** `CLAUDE.md` (Data-driven, Planteles, Pruebas y "Versión actual" con la línea base
    nueva en tres etapas) y GDD 3.5 (preguntas 1 y 3 resueltas o actualizadas con lo medido).

## Fuera de alcance
- El Bloque 2 nuevo y el mazo propio guardado del jugador (T-05).
- El crecimiento de los rivales durante la carrera (T-06).
- Cambiar números de cartas, constantes del motor o las listas de crecimiento para "arreglar" el balance.

## Definición de terminado
- [ ] `godot-check -Balance` en verde (`check.sh --balance` en Linux). Esperado según el laboratorio
      (`tests/lab/m2_crecimiento.json`): **inicio ~2.47 goles**, lesiones ~2.8%, cansancio ~16% / 49%;
      **mitad ~2.73 y final ~2.65** (sobre el rango, es la curva que se conoce: los mazos mejoran y se
      ataca mejor); constructibilidad de Colo-Colo ≥85%. Si el inicio sale fuera de 2.3-2.6 o algo se
      aleja más de ±0.1 de lo esperado, **no recalibres**: repórtalo con la tabla.
- [ ] La línea base de `balance_lab` coincide con la matriz de inicio de `-Balance`.
- [ ] Pruebas nuevas de los puntos 9 en verde; `smoke_match` y `smoke_career` en verde con mazos de 12.
- [ ] PR con: qué cambia para el jugador (mazo chico con su carta de estilo, cartas nuevas a la vista),
      la tabla de las tres etapas antes/después y lo que quedó sin verificar (en particular, cómo se ven
      los textos nuevos de `CardUI`: las pruebas no miran la pantalla).

## Preguntas abiertas
- **Curva de la temporada:** mitad y final quedan sobre 2.6. No la arregles en esta tarea: se decide
  con el usuario con la medición oficial de esta tarea (aceptar la curva, bajar el inicio o un ajuste
  global). Anótala en el PR.
- Si algún constructor queda raro por la forma de `build_match_templates` (canteranos/firmas), explica
  la alternativa en el PR en vez de reescribir `SquadManager`.
