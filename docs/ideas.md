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
| I-10 | Fixture completo del Apertura 2006, tabla y fin del torneo | GDD original | 3 | DECIDIDA: formato fiel 2006 (D-24), otros partidos simulados (D-25) | M3 |
| I-11 | Guardar y cargar la carrera | Necesario | — | ACEPTADA · implementada en T-01 | M3 |
| I-12 | Clausura y Primera B (ascensos/descensos) | GDD original | 4 | Clausura y descenso entran en M3 (D-24); Primera B jugable sigue EN ESPERA | M5 |
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
| I-36 | Comparar con la realidad: tras cada fecha, el resultado real de 2006 del mismo partido; al final, tu tabla contra la real y titulares de "historia alternativa" (Diario El Chisme); objetivos de la directiva sacados de la historia (Colo-Colo: bicampeonato; U. de Chile: ganar la final que perdió; Santiago Morning: no descender) | Usuario (2026-10-27) | 3, 4 | ACEPTADA | M3 |
| I-37 | Paquetes de datos reemplazables: clubes, DT, jugadores, cartas firma y textos con nombres en un paquete (por defecto, uno inventado), cargable desde Steam Workshop (GodotSteam) para bases con equipos reales (D-26) | Usuario (2026-10-27) | 4 | ACEPTADA | antes de M4 |
| I-38 | Familias de cartas con variantes de nombre: mismos números, otro nombre según el jugador, DT o club (p. ej. la firma genérica "Sello de [figura]" con nombres distintos); la carta muestra su familia bajo el nombre. Los números viven una vez en la familia, así afinar una afina todas sus variantes (`docs/cartas.md`) | Usuario (2026-10-27) | 1, 4 | NUEVA | nombres: ya (solo datos); campo de familia en los JSON: después de T-04 |
| I-39 | Cartas especiales con efecto propio (DT famosos, fichajes, canteranos, eventos): se diseñan cuando el bucle del mazo esté cerrado (T-04, T-05) y haya playtests, para llenar lo que falte y medirlas con `balance-lab` | Usuario (2026-10-27) | 1, 3 | EN ESPERA | M2 (tras T-05) / M3 |
| I-40 | Transición: carta de la mano defensiva que no frena al rival, pero si sale tu próximo Momento arranca mejor. Rápida = una jugada hecha (ya existe: contragolpe, campo `counter`); elaborada = "Transición +X" en el desglose de tu próximo Momento (campo nuevo, regla de `CLAUDE.md` para efectos). Con 2 PA, cortar su ataque o preparar el tuyo | Usuario (2026-10-27) | 1, 2 | NUEVA | M2 (en las ofertas de T-05); medir goles con `balance-lab` |
| I-41 | Intención del rival visible antes de defender (como Slay the Spire). Cuánto ves depende del nivel de tu DT frente al del rival (usuario): de "atacan 4-5" a "atacan 5 · jugada de 3 · remata Suazo con el Zapatazo". El nivel del DT no existe todavía (¿fijo por club, sube en la carrera?). Hoy solo ves "ATACA X". Cambia el flujo de `match_view` y `DuelRunner` (el rival roba antes de tu defensa). Pregunta de playtest: ¿la defensa es una decisión o un trámite? | Usuario + análisis (2026-10-27) | 1, 2 | NUEVA | M1 (antes de los playtests, o según lo que digan) |
| I-42 | Cartas exclusivas por arquetipo en las ofertas del entrenamiento (3-4 por estilo: defensa, transición y ataque), para que la personalidad del DT viva en su mazo como las clases de Slay the Spire. Hoy las listas de crecimiento son las mismas cartas genéricas en otro orden. Bocetos en `docs/cartas.md`; incluye I-08 | Usuario (2026-10-27) | 1, 3 | ACEPTADA (2026-10-27) | M2 |
| I-43 | Un verbo por tipo de carta: pase avanza, control prepara, regate ignora la Presión, centro mejora el próximo remate, remate cierra; en defensa presión, bloqueo, intercepción, despeje y transición (`docs/cartas.md`). Hoy pase, control, regate y centro solo cambian el bono | Usuario + análisis (2026-10-27) | 1 | ACEPTADA como dirección (sin código; se mide con `balance-lab` al implementarla) | M2 |
| I-44 | Superioridad numérica: en cada jugada se compara tu línea con la de ellos (salida: tu defensa contra sus delanteros; medio contra medio; definición: tus delanteros contra su defensa). Los números salen de la formación del estilo (D-30) y de la postura, con azar de ±1 como los encuentros de Slay the Spire; la formación pone el tope (Catenaccio en HIGH no pasa de 3 arriba). 1 jugador = 6 pts para pruebas (una Presión) | Usuario (2026-10-27) | 1, 2 | EN DISEÑO (D-30) | M2/M3 |
| I-45 | Duelos por línea, como los enemigos de Slay the Spire: cada jugada del Momento cruza una línea del rival (salida contra sus delanteros, medio contra sus volantes, definición contra defensas y arquero) y enfrenta a un jugador concreto; tu carta usa un atributo de tu jugador contra el de él (regate contra quite, pase contra anticipación, remate contra arquero). Ejemplo del usuario: Matías Fernández (M14) pasa fácil a Kalule Meléndez con un regate; a Felipe Flores le conviene un pase largo que se salte a Kalule. Siempre queda chance para el defensor (el % sigue acotado a 5-95). Es el diseño de I-06 y resuelve la jerarquía entre clubes (D-18). Hoy cada jugador tiene un solo número (`skill_rating`). Habilidades propuestas (Pase, Regate, Remate, Quite, Lectura, Atajada, salidas de nivel + puesto + perfil): `docs/cartas.md` | Usuario (2026-10-27) | 1, 2, 4 | EN DISEÑO (D-29, D-30) · cambio grande del partido: por pasos (ver `docs/cartas.md`) | M2/M3 |
| I-46 | Nivel del DT: el tuyo sube con la experiencia y cada nivel muestra más de la intención del rival (I-41) y suma cartas más complejas a las ofertas del entrenamiento (D-28); cada DT rival tiene un nivel estimado para la IA, asignado en los datos como el arquetipo | Usuario (2026-10-27) | 2, 3 | NUEVA | M2 |
| I-47 | Mezclar estilos: formación y estilo por separado (por ejemplo, Tiki-Taka con 3-5-2) o perfiles de DT híbridos; podría desbloquearse con el nivel del DT (D-28) | Usuario (2026-10-27) | 1, 3 | EN ESPERA | después de M2 |
