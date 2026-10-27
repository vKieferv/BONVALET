# T-06 · Los rivales crecen durante la temporada

Brief para una sesión autónoma (skill `tarea-autonoma`). **Depende de T-04** (`decks.json` con
`"crecimiento"` y `season_templates`). Conviene después de T-05: las dos tocan `scripts/career.gd`.

- **Hito:** M2
- **Rama:** `tarea/t-06-rivales-crecen`
- **Decisiones:** D-22 (paridad: los rivales también suman cartas de su estilo), D-23

## Objetivo
Que el rival de la semana N juegue con su mazo estándar + las primeras N−1 cartas de su lista de
`crecimiento` (tope 20), igual que lo que mide `sim.gd` en sus etapas. Así no te vuelves imparable a
mitad de torneo y el simulador sigue representando la carrera.

## Alcance
1. `Career.rival_templates(rival_id)` (o equivalente) = `season_templates(rival_id, week - 1)`:
   determinista, sin guardar nada nuevo (se deriva de la semana).
2. `match_view`: en la carrera, el motor del rival usa ese mazo; en partido rápido el rival juega con el
   mazo de inicio (como tras T-04).
3. La pantalla previa al partido (Bloque 3 del calendario) puede mostrar el tamaño del mazo del rival
   ("Audax · mazo de 15 cartas"), si es simple.
4. **Pruebas** (`career_rules`): semana 1 = mazo de inicio (12 con la firma); semana 5 = inicio + 4; nunca
   más de 20; las cartas agregadas son las primeras de su lista y en ese orden.
5. **Documentación:** `CLAUDE.md` (Rival en `match_view`, Modo carrera) y GDD 3.4.

## Fuera de alcance
- Que los rivales **mejoren** cartas (D-22 dice "suma o mejora"): esta tarea solo suma. Mejorar queda
  como idea para después; anótalo en el PR.
- El mazo del jugador (T-05), las listas de `crecimiento` y el balance.

## Definición de terminado
- [ ] `godot-check` en verde; `-Balance` igual que tras T-04 (las etapas de `sim.gd` ya medían esto).
- [ ] Pruebas del punto 4 en verde.
- [ ] PR con qué cambia para el jugador (los rivales de la segunda mitad son más difíciles) y lo que
      quedó sin verificar.

## Preguntas abiertas
- Con más de 9 semanas, la lista de 8 se agota y el rival queda en 20 cartas desde la semana 9: si el
  torneo es más largo, ¿se repite la lista o se queda así? Por defecto se queda en 20; anótalo.
