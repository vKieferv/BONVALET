---
name: balance-lab
description: Experimentos de balance de Futbolista Deckbuilder - corre la matriz neutral bot vs bot con variantes lado a lado (costos de cartas, jugadas por Momento, dificultad, desgaste, sin Aguantar) para separar el efecto de cada cambio y medir palancas antes de tocar constantes. Úsalo cuando una métrica de godot-check -Balance quede fuera de rango, antes de proponer un ajuste de balance, o cuando el usuario pregunte "qué pasaría si" con números del partido.
---

# balance-lab

Responde "¿qué pasa si…?" con números, en minutos y sin tocar el código del juego.

## Cómo correrlo
Desde la raíz del repo (`futbolista/`):

```powershell
..\Godot_v4.7.2-stable_win64_console.exe --headless --path . -s res://tests/balance_lab.gd -- --variants=res://tests/lab/ejemplo.json
```

- Sin `--variants` corre solo la línea base. `--per-pair=N` cambia los partidos por cruce (400 por defecto, igual que `sim.gd`; 200 sirve para descartar rápido, pero decide con 400).
- Cada variante tarda unos 20-25 s con 400 por cruce.
- Los clubes juegan con el **mazo estándar** de `data/decks.json` (D-23), igual que el juego. La línea base reproduce **exacto** la matriz de inicio de `sim.gd` (y `"picks": 4` / `8`, la de mitad y final): si no coincide con el último `godot-check -Balance`, algo cambió en el motor o en los datos; aclara eso antes de seguir.
- `"deck": "clasico"` vuelve al mazo clásico de 19 de `cards.json` (el de antes de M2; `tests/lab/m1.json`, `m2_cartas.json` y `m2_estandar.json` lo piden en sus `defaults` para seguir midiendo lo mismo).

## Variantes
Un JSON con una lista; formato y claves en la cabecera de `tests/balance_lab.gd`:
`no_hold`, `steps`, `steps3_p`, `steps_by_archetype`, `diff_add`, `stamina_mult`, `cards` (por id; `@sello` = la firma genérica), `profile` (campos del `BotProfile` por arquetipo), `cards_for` y `player_for` (cambios a un solo club: sirven para medir cuánto vale ganar, quitar o mejorar una carta), y para mazos completos `picks` (etapa de la temporada: suma las primeras N cartas del `crecimiento` de `decks.json`; es el `extra` de `SquadManager.season_templates`), `deck` (`"clasico"` o una lista que reemplaza el mazo estándar; `@rasgo` según `rasgos` por arquetipo), `rasgos` y `pick_pools` (cambian los de `decks.json` por arquetipo) y `card_defs` (cartas nuevas o redefinidas sobre el catálogo). Partido por zonas (D-36, T-10): `zonas: true`, `zone` (`steal_salida`, `steal_medio`, `numbers_pts`, `line_factor`, `long_shot_penalty`, `low_shot_penalty`) y `extra_clubs` (clubes que juegan contra la matriz para ver la jerarquía); la línea "por partido" da robos, contragolpes, Momentos sin cartas, atajadas y rebotes (ejemplo: `tests/lab/zonas.json`). Un elemento `{"defaults": {...}}` se aplica a las variantes que lo siguen.
Para medir una carta nueva de un arquetipo sin mezclar efectos, dásela solo a ese arquetipo (los demás reciben una básica en su lugar): si todos cambian a la vez, los goles en contra de un club reflejan las cartas de sus rivales. Ejemplo completo: `tests/lab/m2_rasgos_2.json`.
Además del total, imprime una línea por club (goles a favor-en contra, % con lesión, ataques cortados, tamaño del mazo y constructibilidad con su propio perfil): úsala para ver a quién afecta una palanca, no solo el promedio.
Ojo: `profile_for_team` le pone al perfil el nombre del club; el arquetipo sale de `teams_chile_2006.json` (el laboratorio ya lo resuelve así). Una variante que da exactamente la línea base casi siempre es una clave que no se aplicó: revísala antes de concluir "no tiene efecto". Los bonos de carta negativos se ignoran (`effective_bonus`).
Escribe los experimentos de una tarea en `tests/lab/<tema>.json` y bórralos al terminar, salvo que sirvan de referencia.

Las **constantes del motor** (`INJURY_CHANCE_*`, `HOLD_*`, `AP_BY_POSTURE`, `STAMINA_SCALE`…) no se varían desde el JSON: cámbiala en `core/match_engine.gd`, corre el laboratorio y **restáurala** en el mismo comando, comprobando al final con `Select-String` que quedó como estaba.

## Método
1. **Hipótesis:** qué métrica está fuera y qué cambio sospechas (ej. "los remates a 2 PA suben los goles").
2. **Descomponer:** una variante por cambio, sin combinar, para ver cuánto aporta cada uno.
3. **Palancas:** prueba 2-4 combinaciones que no contradigan lo que el usuario especificó. Prefiere palancas que no cambien los % que ve el jugador (pilar 2 de `docs/pilares.md`).
4. **Confirmar** las candidatas con 400 por cruce y deja margen respecto del borde del rango: la implementación real cambia la secuencia del RNG y puede mover ±0.5% las lesiones.
5. **Reportar** una tabla (variante | goles | lesiones | cansancio 1T/2T) con una recomendación y su costo en sensación de juego. **No apliques la palanca** si el usuario no la eligió (ver `docs/decisiones.md`); al aplicarla, agrega su entrada D-NN.
6. Verifica con `godot-check -Balance` después de aplicar: es la medición oficial.

## Objetivos vigentes
Ver D-14 en `docs/decisiones.md`: 2.3-2.6 goles totales, 2-5% de lesiones, cansancio en el 2T, constructibilidad ≥85%.
