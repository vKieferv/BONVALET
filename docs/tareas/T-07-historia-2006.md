# T-07 · Datos históricos del Apertura y Clausura 2006

Brief para una sesión autónoma (skill `tarea-autonoma`). Tarea **de datos**: no toca el código del
juego, así que puede correr en paralelo con las tareas de M2.

- **Hito:** M3 (prepara el terreno)
- **Rama:** `tarea/t-07-historia-2006`
- **Decisiones:** D-24 (temporada fiel a 2006), D-25 (los demás partidos se simulan; la realidad es
  comparación), D-02 (datos históricos solo con fuente), D-26 (los nombres salen de datos)
- **Ideas:** I-10, I-36

## Objetivo
Un archivo `data/history_2006.json` con todo lo que pasó en el Apertura y el Clausura 2006 de Primera
División de Chile, **verificado contra sí mismo** por una prueba: calendario real fecha por fecha
(local, visita, fecha libre, día), resultados, grupos, tablas, repechaje, playoffs, campeones,
goleadores, tabla acumulada, descenso y liguilla. Con esto, M3 podrá usar el calendario real y mostrar
"en la realidad pasó esto".

## Alcance
1. **Fuentes:** es.wikipedia ("Torneo Apertura 2006 (Chile)", "Torneo Clausura 2006 (Chile)" y sus
   anexos de resultados de la fase regular) y RSSSF (rsssf.org, Chile 2006) para cruzar. Cita cada
   fuente en `_notes`/`sources`. Copia **hechos** (equipos, fechas, marcadores), no textos.
2. **Formato** (ajústalo si hace falta, pero documéntalo en `_notes`):
   ```
   {"_notes": "...", "sources": [...],
    "apertura": {"inicio": "2006-01-27", "fin": "2006-07-02", "equipos": [ids],
                 "grupos": {"A": [ids], ...},
                 "fechas": [{"numero": 1, "libre": id, "partidos": [{"local": id, "visita": id,
                             "goles_local": n, "goles_visita": n, "dia": "AAAA-MM-DD", "estadio": "..."}]}],
                 "tabla": [{"club": id, "pj": n, "pg": n, "pe": n, "pp": n, "gf": n, "gc": n, "pts": n}],
                 "repechaje": [...], "playoffs": {"cuartos": [...], "semis": [...], "final": {...}},
                 "campeon": id, "goleador": {"nombre": "...", "club": id, "goles": n}},
    "clausura": {...igual...},
    "tabla_acumulada": [...], "descenso": {"directo": id, "liguilla": {...}}, "ascensos": [...],
    "review": ["dudas o datos sin fuente"]}
   ```
   Cada llave de playoffs: ida, vuelta, global, penales si hubo, y quién avanzó.
3. **Ids de clubes:** los de `data/teams_chile_2006.json` (si un club de 2006 no está, anótalo en
   `review`, no lo agregues).
4. **Prueba nueva `tests/data_rules.gd`** (y súmala a `check.ps1` y `check.sh`): en cada torneo, cada
   fecha tiene 9 partidos y un club libre; cada club juega 18 partidos y enfrenta una vez a cada uno;
   **la tabla calculada desde los resultados coincide con la tabla publicada** (si no coincide por una
   sanción o un punto descontado, que esté explicado en `review` y la prueba lo acepte solo en ese
   caso); las llaves de playoffs son coherentes con sus marcadores; todos los ids existen.
5. **Documentación:** `CLAUDE.md` (Data-driven: el archivo nuevo y su prueba) y una línea en GDD 5.4.

## Fuera de alcance
- Usar los datos en el juego (fixture, tabla o comparación en la carrera): eso es M3.
- Planteles y jugadores (T-08). Copa Libertadores, Sudamericana y Primera B (solo los ascensos).

## Definición de terminado
- [ ] `godot-check` en verde con `tests/data_rules.gd` incluida.
- [ ] Ningún dato inventado: lo que no se pudo confirmar va `null` y en `review`.
- [ ] PR con: qué contiene el archivo, fuentes usadas, qué quedó en `review` y cualquier discrepancia
      entre fuentes.

## Si no hay acceso a las fuentes
Si desde el entorno no se puede abrir Wikipedia ni RSSSF (solo el buscador), **no armes el archivo con
datos sueltos**: abre el PR solo con el formato, la prueba y una nota explicando el bloqueo. Esta tarea se
puede correr después desde el PC del usuario.
