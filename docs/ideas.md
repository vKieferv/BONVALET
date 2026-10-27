# Buzón de ideas

Toda idea nueva entra aquí, **no al sprint en curso**. Se revisa al planificar el siguiente sprint.
Una idea pasa a `roadmap.md` (y su diseño a `gdd.md`) solo si responde las tres preguntas:

1. **¿A qué pilar sirve?** (`pilares.md`)
2. **¿Qué problema resuelve?** (de un playtest, una métrica o una brecha del género)
3. **¿Cómo sabremos si funciona?** (métrica del simulador o pregunta de playtest)

Estados: NUEVA · ACEPTADA (con hito) · EN ESPERA · DESCARTADA (con motivo).
Para agregar una, la skill `idea-nueva` hace el análisis y la anota aquí.

| ID | Idea | Origen | Pilar | Estado | Hito |
|---|---|---|---|---|---|
| I-01 | Ganar cartas: los entrenamientos de la semana generan cartas tácticas para el mazo (60% DT / 40% plantel) | GDD original | 3 | DECIDIDA: elegir 1 de 3 en el Bloque 2 (D-20) | M2 |
| I-02 | Quitar cartas del mazo (con costo: dinero, semana o moral) | Género | 1 | DECIDIDA: la carta nueva reemplaza a otra si el mazo está en su tope (D-20) | M2 |
| I-03 | Mejorar cartas (subir % o bajar PA/desgaste) | Género | 1 | DECIDIDA: sesión de video en el Bloque 2 (D-21) | M2 |
| I-04 | Perfiles de DT con tamaño de mazo y mano propios; Catenaccio con casillero defensivo fijo; Kamikaze con Descarte Agresivo (2 cartas → +25%) | GDD original | 1 | REEMPLAZADA por el mazo estándar + carta de rasgo (D-23) | M2 |
| I-05 | Progresión de canteranos: suben atributos y desbloquean su carta privada | GDD original | 3 | ACEPTADA | M2 |
| I-06 | Atributos de los titulares afectan el motor (hoy solo activan el Ejecutor Natural); carta jugada por un compañero usa sus atributos. También define la jerarquía entre clubes (D-18) | GDD original | 1, 4 | ACEPTADA | M2/M3 |
| I-07 | Largo de jugada por arquetipo (Tiki-Taka 3-4, Directo 1-2, Contragolpe 2, Catenaccio 1) en vez de 3 fijas | GDD / pizarra | 1 | DESCARTADA en su forma literal (D-16: solo Catenaccio 2) | — |
| I-08 | Kamikaze: "Presión Asfixiante", en HIGH el rival gasta +1 de estamina para responder | Pizarra | 1 | NUEVA | — |
| I-09 | Tiki-Taka con jugadas de 3-4 pases que premien el pase largo (p. ej. Flow o acierto que crece con cada pase) — sin compensación, alargar la jugada lo hunde (D-16) | M1 | 1 | EN ESPERA | M2 |
| I-10 | Fixture completo del Apertura 2006, tabla y fin del torneo | GDD original | 3 | ACEPTADA | M3 |
| I-11 | Guardar y cargar la carrera | Necesario | — | ACEPTADA · implementada en T-01 | M3 |
| I-12 | Clausura y Primera B (ascensos/descensos) | GDD original | 4 | EN ESPERA | M5 |
| I-13 | Ojeo por niveles (nivel 1: edad, posición, promedio; máximo: stats, arquetipo ideal, fragilidad) | Pizarra | 3 | NUEVA | M3+ |
| I-14 | Agentes que ofrecen jugadores en eventos (joyas baratas o conflictivos que suben el riesgo de funa) | Pizarra | 3, 4 | NUEVA | M3+ |
| I-15 | Infraestructura: grandes invierten en estadio y cracks; chicos en gimnasio y centro médico (menos fatiga y lesiones) | GDD original | 3 | NUEVA | M3+ |
| I-16 | Evento "Conferencia polémica": provocas al rival, +precisión en HIGH, riesgo de sanción arbitral | GDD / pizarra | 3, 4 | NUEVA | — |
| I-17 | Charla técnica antes del partido | GDD original | 3 | NUEVA | — |
| I-18 | Funa que prohíbe la carta firma del jugador por 1 fecha (alternativa a +50% de desgaste) | Pizarra | 3 | EN ESPERA | — |
| I-19 | Más eventos sociales con humor de época | GDD original | 4 | NUEVA | M5 |
| I-20 | Licencias: nombres ficticios para la versión comercial + datos editables por la comunidad (como PES); consultar a un abogado antes de anunciar; el juego debe funcionar completo con un paquete de datos ficticio (`mercado.md` §4) | Análisis comercial | 4 | ACEPTADA (consulta del usuario) | antes de M4 |
| I-21 | Otras ligas o épocas como expansiones (otro conjunto de JSON) | Análisis comercial | 4 | EN ESPERA | post-lanzamiento |
| I-30 | Dirección de arte: transmisión de TV 2006 + cartas como láminas de álbum | Análisis | 4 | NUEVA | M4 |
| I-31 | Cinemática o resplandor más fuerte para el Ejecutor Natural (`FxLayer`) | GDD original | 1 | NUEVA | M4 |
| I-32 | Indicador de "jugada armable": avisar si la mano puede llegar al gol con los PA del turno (y cuál), usando `CoachBot.best_plan` | M1 (sensación de juego) | 1, 2 | NUEVA | M1 (si los playtests lo piden) |
| I-33 | Textos traducibles (tablas de traducción de Godot) y demo en inglés + español: el público hispanohablante es ~5% de Steam (`mercado.md`) | Estudio de mercado | 4 | ACEPTADA (tarea autónoma) | antes de M4 |
| I-34 | Modo Copa: partida corta de 5-6 partidos con mazo que crece, para la demo y el público roguelike (como Clutchtime, Goaldeck, Super Kickmen) | Estudio de mercado | 1, 3 | ACEPTADA | M2 |
| I-35 | Resumen post-partido con el % de cada jugada y goles esperados vs. reales, para que el azar se vea justo (queja n.º 1 contra NUTMEG y FT&G) | Estudio de mercado | 2 | ACEPTADA | M1 |
