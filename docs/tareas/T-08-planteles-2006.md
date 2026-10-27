# T-08 · Planteles 2006 de los clubes de Primera A (Wikidata)

Brief para una sesión autónoma (skill `tarea-autonoma`). Tarea **de datos**: no toca el código del
juego, así que puede correr en paralelo con las tareas de M2.

- **Hito:** M3 (prepara el terreno)
- **Rama:** `tarea/t-08-planteles-2006`
- **Decisiones:** D-27 (Wikidata y atributos propios; nada copiado de otros juegos), D-02 (solo con
  fuente), D-26 (en desarrollo se usan nombres reales; deben salir de datos reemplazables)

## Objetivo
Que los 16 clubes de Primera A 2006 que hoy tienen plantel generado tengan su **plantel real de 18
jugadores**, con hechos verificables y atributos de juego calculados con una fórmula nuestra y
documentada, en el mismo formato que Colo-Colo, U. de Chile y UC.

## Alcance
1. **Clubes:** los de Primera A en `data/teams_chile_2006.json` que no están en `data/squads_2006.json`
   (sin Deportes Concepción, suspendido en 2006).
2. **Hechos desde Wikidata** (`query.wikidata.org`, SPARQL), igual que los 3 clubes actuales (ver
   `_notes` de `squads_2006.json`): jugadores con membresía en el club (P54) cuyas fechas incluyen 2006,
   nombre, nacimiento (P569, edad al 1 de julio de 2006), nacionalidad (P27, código de 3 letras) y
   posición (P413) para la línea (POR, DEF, MED, DEL). Cruza con el plantel publicado en Wikipedia
   cuando exista. Si un jugador tiene datos contradictorios, va a `review`.
3. **Atributos propios** (`role`, `stamina_max` 40-100, `skill_rating` 40-99): una fórmula
   determinista y explicada en `_notes` (por ejemplo, según edad, posición, nivel del club por
   instalaciones y si fue seleccionado nacional en Wikidata), en los mismos rangos que los 3 clubes
   actuales. **No uses puntajes de Football Manager, PES ni otros juegos.**
4. **18 por club:** elige los 18 con mejor respaldo (más fuentes, más partidos). La figura del club de
   `teams_chile_2006.json` tiene que estar en el plantel. Si un club no llega a 18 jugadores con fuente,
   **no lo completes inventando**: déjalo generado (fuera de `squads_2006.json`) y anota en `review` lo
   que encontraste.
5. **Reglas:** `tests/career_rules.gd` ya revisa los planteles de los 32 clubes (18 jugadores, Sub-21,
   extranjeros, ids únicos, 11 titulares) y el mazo de cada club contra `validate_deck`: tiene que seguir
   en verde. Si un plantel real no cumple una regla de liga (por ejemplo, menos de 2 Sub-21), anótalo
   en el PR en vez de cambiar la regla.

## Fuera de alcance
- Código del juego, cartas firma nuevas, Primera B, fichajes.
- Cambiar el formato de `squads_2006.json` o mover los nombres a un paquete de datos (eso es I-37).

## Definición de terminado
- [ ] `godot-check` en verde (en especial `career_rules`).
- [ ] Cada jugador nuevo con fuente; lo dudoso en `review`; la fórmula de atributos en `_notes`.
- [ ] PR con: cuántos clubes quedaron reales y cuáles no (y por qué), la fórmula de atributos y lo que
      quedó en `review`.

## Si no hay acceso a Wikidata
Si `query.wikidata.org` no responde desde el entorno, **no uses otras fuentes de memoria ni inventes**:
abre el PR con una nota del bloqueo y nada más. Esta tarea ya funcionó desde el PC del usuario, y se
puede correr ahí.

## Intentos
- **2026-10-27, sesión en la nube: bloqueada.** La política de red del entorno rechaza
  `query.wikidata.org` (el proxy responde 403 al CONNECT), así que no hubo consultas SPARQL. Siguiendo
  "Si no hay acceso a Wikidata", no se tocó `data/squads_2006.json` ni se usó otra fuente. Para
  reintentar en la nube hay que agregar `query.wikidata.org` en *Allowed domains* del entorno (o subir
  su nivel de acceso a la red); si no, correrla desde el PC del usuario.
