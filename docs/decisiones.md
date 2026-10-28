# Registro de decisiones

Cada decisión de diseño o de balance que cierra un debate. Antes de reabrir algo, se lee su entrada;
para cambiarlo se agrega una entrada nueva que la reemplace (no se borra la vieja).

Formato: **D-NN · fecha · título** — qué se decidió, por qué, qué se descartó, cómo se mide.
Estado: VIGENTE, REEMPLAZADA (por D-NN) o EN REVISIÓN (con el hito donde se revisa).

---

**D-01 · 2026-10-26 · Marcas siempre parodiadas** · VIGENTE
Sponsors, diarios, canales y marcas nunca usan nombres reales: parodias nostálgicas (Cerveza
Glaciar, Telnet, Diario El Chisme, Televisora Nacional). Clubes, DT y jugadores sí son reales por
ahora (ver I-20 sobre licencias antes de vender).

**D-02 · 2026-10-26 · Datos históricos solo con fuente** · VIGENTE
Si un dato de 2006 no se puede confirmar, va `null` y una entrada en `review`; el juego tiene textos
por defecto. Fuente que funcionó: Wikidata (P54, P569, P27).

**D-03 · 2026-10-26 · Mazo unificado con filtro de posesión** · VIGENTE
Un solo mazo de 18-20 cartas; `DeckManager.possession` filtra qué se roba en ataque y en defensa.
Despeje de Emergencia fuera del mazo. Descartado: mazos separados de ataque y defensa. El tamaño
pasó a 10-20 con D-23 (se arranca con 12; implementado en T-04).

**D-04 · 2026-10-26 · PA por turno y Estamina Global separados** · VIGENTE
Los PA (LOW 3, NORMAL 3, HIGH 4; defensa 2) limitan qué se juega en un turno; la estamina es el
desgaste del partido. **La estamina nunca toca el % de acierto ni bloquea jugadas**: solo cambia el
robo (−0/−1/−2 cartas), las lesiones y las cartas de penalización. Por qué: un solo recurso mezclaba
decisiones de turno y de partido y castigaba dos veces el cansancio. Descartado: penalizar el
acierto por zona de estamina.

**D-05 · 2026-10-26 · LOW conserva 3 PA** · VIGENTE
Su identidad es gastar menos estamina (×0.75), el −15 en remates y el tope de Momentos, no tener
menos acciones. Descartado: LOW con 2 PA (no podía jugar élites).

**D-06 · 2026-10-26 · Funado = +50% de desgaste en sus cartas** · VIGENTE
Reemplaza el "+1 de estamina" del GDD original, que no escalaba con el nuevo desgaste.

**D-07 · 2026-10-26 · Una sola fuente de probabilidad** · VIGENTE
`chance_breakdown(card)` arma el % mostrado y el tirado (`roll < success_chance`). Todo modificador
nuevo entra ahí. Lo comprueban `engine_rules` y `smoke_match` (pilar 2).

**D-08 · 2026-10-26 · Paridad del rival** · VIGENTE
El rival arma su mazo con `SquadManager` igual que tú, activa el Ejecutor Natural y defiende tus
ataques según su perfil. Por qué: un rival con reglas propias no se puede balancear con el simulador.

**D-09 · 2026-10-26 · Ceder Jugada se mantiene junto a Aguantar** · VIGENTE
Ceder sigue siendo la salida sin riesgo; Aguantar es la apuesta. Descartado: que Aguantar
reemplazara a Ceder.

**D-10 · 2026-10-26 · Aguantar el Balón** · VIGENTE
Una vez por Momento, 1 PA (0 si no quedan, y entonces el éxito da +1 PA), 3 de estamina, 80% menos
la Presión rival. Éxito: mano nueva según la zona y Flow cortado sin la penalización del 15%.
Fallo: el rival roba y queda con contragolpe. Por qué: en el playtest muchas manos no podían armar
jugada y la única salida era ceder.

**D-11 · 2026-10-26 · Costos de PA de los remates** · VIGENTE
Desmarque 0 PA (física, desgaste alto), Tiro de lejos 1, Remate de primera y el genérico "Sello de
[figura]" 2, firmas con nombre propio 3 (Zapatazo, Arremetida; Sangre fría 2). Mide: constructibilidad
de mano ≥85% (Momentos de 3 jugadas, estamina llena). Resultado: 87%.

**D-12 · 2026-10-26 · 4 Momentos por equipo, de 3 jugadas** · VIGENTE (precisada por D-16)
4 Momentos propios (LOW 3, HIGH puede sumar) y todos piden 3 jugadas; los de 2 salen solo del
contragolpe o del espacio rival. Por qué: con remates a 2 PA y Aguantar, la matriz subió a 2.96
goles; 3 jugadas fijas la dejan en rango sin bajar los % que ve el jugador. Descartado: dificultad
+7 pts (bajaba todos los % mostrados). **Choca con el GDD** (largo de jugada por arquetipo:
Tiki-Taka 3-4, Directo 1-2, Catenaccio 1): se decide en M1.

**D-13 · 2026-10-26 · Desgaste y lesiones tras Aguantar** · VIGENTE
`STAMINA_SCALE` 2.0 → 1.6 y `INJURY_CHANCE_MAX` 0.012 → 0.009. Por qué: Aguantar suma jugadas
estando agotado. Descartado: `STAMINA_SCALE` 1.5 (no alcanzaba y adelgazaba el cansancio).

**D-14 · 2026-10-26 · Objetivos de balance** · VIGENTE
Matriz neutral bot vs bot (`godot-check -Balance`): 2.3-2.6 goles totales por partido, 2-5% de
equipos lesionados, cansancio concentrado en el 2T, constructibilidad ≥85%. Son barandas del
simulador; la diversión se valida con playtests humanos (`docs/playtests/`).

**D-15 · 2026-10-26 · Proceso de desarrollo** · VIGENTE
Pilares (`pilares.md`), GDD vivo con estados (`gdd.md`), buzón de ideas (`ideas.md`), este
registro y hitos con criterio de salida (`roadmap.md`). Las ideas nuevas no entran al sprint en
curso. Las sesiones autónomas implementan tareas decididas; las reglas del partido se deciden juntos.

**D-16 · 2026-10-26 · Largo de jugada: 3 para todos, 2 para Catenaccio** · VIGENTE
Los Momentos piden 3 jugadas salvo Catenaccio, que pide 2 (su identidad "ultra corta" del GDD). Vale
para bots y para el jugador: si diriges un club Catenaccio, tus Momentos son de 2. Por qué
(`tests/lab/m1.json`): Catenaccio 2 sube a Palestino de 0.72 a 1.18 goles y la matriz queda en 2.57.
Descartado: largo del GDD por arquetipo (3.46 goles) y el GDD suavizado (2.72), porque alargar la
jugada sin compensación hunde a Tiki-Taka (Colo-Colo 0.63-1.01 goles). Tiki-Taka 3-4 queda en I-09,
atado a una mecánica que premie el pase largo. Cierra también la pregunta "Catenaccio marca poco"
(cambiar cuándo remata el bot no movía nada).

**D-17 · 2026-10-26 · Kamikaze: lesión tardía ×2.5** · VIGENTE
`late_injury_mult` de Kamikaze baja de 4.0 a 2.5: La Serena pasa de 21% a 14-15% de partidos con
lesión (el "hasta 15%" del diseño) y el total de la liga de 4.5% a ~3.2%, sin cambiar los goles.
Descartado: ×2 (~12%) y dejar ×4.

**D-18 · 2026-10-26 · La Intercepción no se toca** · VIGENTE
Los datos no la señalan: corta ~0.9 ataques por partido a Colo-Colo y quitarla o encarecerla casi
no cambia la tabla. La ventaja de la UC (Contragolpe) es de ataque (1.58 goles). La jerarquía entre
clubes (el Colo-Colo de 2006 debería ser el mejor) se resuelve con la fuerza del plantel (I-06),
no con el arquetipo. Nota: la Intercepción ya tiene bono 0 y el motor ignora los bonos negativos.

**D-19 · 2026-10-26 · Cerrar el juego a mitad de partido: se repite el partido** · VIGENTE
Como funciona desde T-01: al volver, el partido se juega desde el principio. Se acepta que se
pueda abusar (juego para un jugador). Descartado: perder por secretaría 0-3 y guardar a mitad de
partido (caro: estado completo del motor).

**D-20 · 2026-10-27 · Las cartas nuevas salen del entrenamiento: elegir 1 de 3** · VIGENTE
En el Bloque 2, el entrenamiento táctico ofrece 3 cartas de tu estilo y te quedas con una (ritmo de
una carta por semana, como Slay the Spire). Si el mazo está en su tope, la nueva reemplaza a otra:
así también se quitan cartas. Descartado: premio por resultado (el que pierde se queda atrás) y
mercado con presupuesto (economía que todavía no existe). Fichajes y canteranos serán otra fuente (M3).

**D-21 · 2026-10-27 · Bloque 2: elegir UNA entre carta, mejora o kinesiología** · VIGENTE
Entrenamiento táctico (carta nueva, D-20), sesión de video (mejorar una carta: +10 pts o −1 PA) o
kinesiología (−25 de fatiga). Crecer el mazo compite con descansar (pilar 3). La forma +3% del
entrenamiento táctico actual se reemplaza por la carta. Descartado: carta gratis todas las semanas.

**D-22 · 2026-10-27 · Los rivales también crecen durante la temporada** · VIGENTE
Cada semana el mazo del rival suma o mejora una carta de su arquetipo (paridad, D-08), para que el
simulador siga midiendo el juego real y el jugador no se vuelva imparable a mitad de torneo.
Descartado: mazo fijo con dificultad que sube por fecha.

**D-23 · 2026-10-27 · Mazo inicial estándar y cartas de rasgo del DT** · VIGENTE · EN PRUEBA
Todos los clubes empiezan con el mismo mazo estándar de 11 cartas del DT (Pase corto ×4, Promesa:
Control ×2, Remate simple ×1, Marca ×2, Despeje ×1) + una carta de rasgo según el arquetipo + la carta
firma de su figura (12 en total). Rasgos: Toque-toque (Tiki-Taka), Pelotazo (Directo), Cerrojo
(Catenaccio), Remate en carrera (Kamikaze) y Anticipo (Contragolpe); valores en GDD 3.5. Por qué:
idea del usuario (identidad desde la semana 1 y un mazo que crece con las elecciones, como Slay the
Spire). Medido en `tests/lab/m2_propuesta.json`: 2.47 / 2.71 / 2.61 goles al inicio, a mitad y al
final de la temporada. Reemplaza I-04 (perfiles de DT con mazos de 12-22). Los números de las cartas
son iniciales y se validan con playtests. Descartado: rasgos de Presión o Bloqueo reforzados (diluyen
el Despeje y empeoraban la defensa de su propio club) y 2 Remates simples (constructibilidad 99-100%).

**D-24 · 2026-10-27 · Temporada fiel al formato 2006** · VIGENTE (el descenso lo corrige D-33)
Apertura y Clausura como en 2006: 19 clubes (Deportes Concepción suspendido), todos contra todos a una
vuelta (19 fechas, 18 partidos y una fecha libre por club), 4 grupos para clasificar (los 2 mejores de
cada grupo, repechaje si un tercero supera en puntos a un segundo de otro grupo), cuartos, semis y final
a ida y vuelta (penales si hay empate global) y descenso por tabla acumulada del año (último directo,
penúltimo a liguilla de promoción). El calendario es el real de 2006 (mismo orden, local y fecha libre),
para poder comparar con la realidad (I-36). Descartado: playoffs a partido único y liga sin playoffs.
Fuente del formato: es.wikipedia, "Torneo Apertura 2006 (Chile)" y "Torneo Clausura 2006 (Chile)".

**D-25 · 2026-10-27 · Los demás partidos de la fecha se simulan** · VIGENTE
Los partidos entre otros clubes se juegan con los bots (`DuelRunner`), no se copian de 2006. La
realidad se muestra solo como comparación (I-36). Descartado: repetir los resultados reales.

**D-26 · 2026-10-27 · Nombres reales en desarrollo, inventados al lanzar, y datos reemplazables** · VIGENTE
Mientras se desarrolla, el juego usa clubes, DT y jugadores reales para que sea familiar. La versión
que se publique (y todo lo público: página de Steam, tráiler, demo) usa nombres inventados, y la
comunidad podrá cargar sus propias bases con equipos reales (Steam Workshop). Por eso **todo nombre de
club, DT y jugador tiene que salir de datos fáciles de reemplazar**, nunca del código. Reemplaza la
parte de I-20 sobre qué nombres llevar; la consulta con un abogado sigue pendiente (I-20). Paquetes de
datos y Workshop: I-37.

**D-27 · 2026-10-27 · Base de jugadores: Wikidata y atributos propios** · VIGENTE
Los hechos (club en 2006, posición, nacimiento, nacionalidad) salen de fuentes libres: Wikidata (CC0)
y, para cruzar, Wikipedia. Los atributos de juego (rol, estamina, nivel) los calcula una fórmula propia
y documentada. Sin fuente, `null` y una entrada en `review` (D-02). Descartado: copiar bases de otros
juegos (Football Manager, archivos de PES): son propiedad de sus estudios o de origen dudoso, y sus
puntajes son trabajo creativo ajeno.

**D-28 · 2026-10-27 · Complejidad progresiva, como Slay the Spire** · VIGENTE
Se empieza con jugadas básicas: el mazo inicial solo tiene cartas cuyo efecto es su verbo y su %, sin
texto extra. Las cartas con más texto y combinaciones (transición, saltar una línea, marcaje al hombre)
se desbloquean jugando. Por qué: decisión del usuario; agregar mecánicas puede enredar el partido, y
así cada mecánica llega cuando el jugador ya domina las anteriores. Mecanismo propuesto: el nivel del
DT, que sube con la experiencia (I-46). Coincide con el mazo estándar de D-23.

**D-29 · 2026-10-27 · Habilidades de los jugadores** · VIGENTE (diseño de I-45, sin código)
Cinco habilidades de campo (Pase, Regate, Remate, Quite, Lectura) y la Atajada del arquero; el Físico es
el `stamina_max` que ya existe. En el duelo, el regate se mide con el quite, el pase con la lectura y el
remate con la atajada, así cada defensa tiene un lado débil. Salen de una fórmula propia: nivel
(`skill_rating`) + ajuste del puesto + perfil (+10). Solo la élite lleva perfil (1-2 por club): es lo que
separa a los buenos de la élite. Valor de prueba: cada punto de diferencia vale 0,5 pts de acierto. Por
qué: que importen los jugadores reales (pilares 1 y 4) con una lámina que se lee de un vistazo.
Descartado: 3 habilidades (sin lado débil) y 8 o más (no caben en una lámina y habría que asignarlas a
~340 jugadores). Detalle y ejemplos: `cartas.md`.

**D-30 · 2026-10-27 · Cinco formaciones, una por estilo** · VIGENTE (diseño de I-45, sin código)
5-3-2, 4-4-2, 4-1-2-1-2, 4-3-3 y 3-5-2, una por estilo de DT. Dicen cuántos hay en cada línea (la
superioridad numérica de cada jugada, I-44) y a quién enfrentas. Más adelante se podrán mezclar estilos
(I-47). Asignación (confirmada por el usuario): Catenaccio 5-3-2, Directo 4-4-2, Tiki-Taka 4-1-2-1-2,
Contragolpe 4-3-3, Kamikaze 3-5-2. Salen del estilo, no de la formación real de cada club en 2006.

**D-31 · 2026-10-27 · Reglas de los duelos** · VIGENTE (diseño de I-45, sin código)
Respuestas del usuario a la maqueta de la pantalla (`cartas.md`, "Pantalla de duelos"):
1. A quién enfrentas se decide al empezar el Momento; cualquier rival puede salirte, pero es más
   probable el más cercano.
2. **Fallar no corta el Momento:** sigues hasta que se te acaben los PA o te la roben. Reemplaza, en el
   modelo de duelos, el "2 fallos lo pierden" de GDD 2.1; el juego actual lo mantiene hasta implementarlo.
3. Los remates solo se juegan en la definición, salvo las cartas de tiro lejano, que se juegan desde más
   atrás con castigo por la distancia.
4. Duelos de defensa: Presión y Bloqueo con el Quite, Despeje con la Lectura.
5. La carta la juega el que tiene el balón; al pasar se elige a quién; los rechazos caen al azar.
6. Cada jugador se cansa por separado, para obligar a rotar.
Los valores (probabilidades de quién te sale, parte de los fallos que son robo, castigo por distancia,
cómo actúa el cansancio sin romper D-04) son propuestas de prueba en `cartas.md`.

**D-32 · 2026-10-27 · Ajustes de los duelos tras la maqueta** · VIGENTE (diseño de I-45, sin código)
- **Fórmula de habilidades más corta:** ajuste del puesto hasta +3, perfil +6, tope 95. Reemplaza los
  números de D-29 (+5, +10, tope 99). Por qué: Alcázar con 95 de Remate era excesivo (usuario). Quedan
  Alcázar 89, Suazo 95, M14 90 de Regate.
- **Bravo lleva perfil** de arquero (Atajador): Atajada 86.
- **El Ejecutor Natural se mantiene, más chico:** es la carta del jugador, pero +15 era mucho (usuario).
  Valor de prueba: +5. En el modelo de duelos reemplaza el +15 de GDD 2.5.
- **Robo según la línea:** en la salida 1 de cada 3 fallos, en el medio 1 de cada 5 (usuario). La
  definición queda por decidir (propuesta en `cartas.md`).
- **El cansancio quita PA** (idea del usuario, a probar): las cartas de un jugador cansado cuestan +1 PA.
  No toca el % de acierto; amplía D-04, que hasta ahora solo dejaba al cansancio cambiar el robo de
  cartas, las lesiones y las penalizaciones.

**D-33 · 2026-10-28 · El descenso es el real de 2006** · VIGENTE
Reemplaza el descenso de D-24 ("penúltimo a liguilla"), que se anotó mal al leer el resumen de
Wikipedia. Lo que pasó y lo que hará el juego, según `data/history_2006.json` (T-07): por tabla
acumulada del año, el **último baja directo** (Santiago Morning) y el **17.º y el 18.º juegan liguilla
de promoción** a ida y vuelta contra el 3.º y el 4.º de Primera B (Rangers perdió por penales con Lota
Schwager y bajó; Palestino se salvó contra Fernández Vial). Deportes Concepción bajó castigado sin
jugar (no participó en 2006). Subieron Deportes Melipilla, Ñublense y Lota Schwager. Por qué: el
usuario pidió fidelidad completa (D-24) y aprobó corregirlo al formato real.

**D-34 · 2026-10-27 · Planteles: es.wikipedia fecha lo que Wikidata deja sin fechas** · VIGENTE
Amplía D-27 (T-08). Si Wikidata registra que un jugador fue del club (P54) pero sin fecha de inicio o
de fin, la trayectoria de la ficha de su artículo en es.wikipedia (años por club) decide si estuvo en
2006. La ficha también afina una posición genérica de Wikidata en la misma línea (defensa → lateral),
da la posición si Wikidata no la tiene y desempata nacimiento y nacionalidad cuando Wikidata se
contradice o no los tiene. Los hechos siguen saliendo de fuentes libres. Por qué: con fechas, Wikidata
solo alcanzaba para 3 de los 16 clubes. Descartado: Transfermarkt (no es una fuente libre: sus
condiciones prohíben la extracción automatizada y su base está protegida; además bloquea las
consultas). Se mide en T-08: cuántos clubes de Primera A llegan a 18 jugadores con fuente.

**D-35 · 2026-10-28 · Dirección visual: transmisión de TV 2006 + láminas de álbum** · VIGENTE
Fondo oscuro; marcador y relato como gráficas de TV de la época ("Televisora Nacional"); cartas como
láminas de papel crema con una banda de color por tipo y una moneda dorada para los PA; eventos de la
semana como portadas de Diario El Chisme. Letras Barlow y Barlow Condensed (libres, SIL OFL: se
incluyen en el juego). **Jugadores sin caras:** camiseta o silueta con los colores del club, número y
nombre. **Escudos generados** por el juego con una forma y los colores del club, nunca los reales. Lo
visual va **antes** del partido por zonas, para no rediseñar la pantalla del partido dos veces.
Por qué: el usuario (2026-10-28): "el menú de semana es horrible y ni ganas dan de probarlo"; las
reseñas de la competencia castigan la presentación de los proyectos chicos (`mercado.md`); es
sostenible para un desarrollador solo, y sin caras ni escudos reales sirve igual para la versión con
nombres inventados (D-26). Descartados: álbum de papel claro y pizarra del DT (menos ambiente de
partido); retratos ilustrados (~340 jugadores, quedan para después). Maquetas (privadas del usuario):
lienzo "Dirección visual", https://claude.ai/artifact/TxaUdVLTzGyWHzVjyD4jhm. Acepta I-30.

**D-36 · 2026-10-28 · Partido por zonas, primer paso de los duelos** · VIGENTE (diseño; se implementa en T-10 como modo que se puede activar)
Las 3 jugadas del Momento son 3 zonas: **Salida** (tu línea de atrás contra sus delanteros), **Medio**
(medio contra medio) y **Área** (tus delanteros contra su defensa). Reglas, con valores de prueba que se
miden con `balance-lab`:
1. **Remates en el Área.** Desde fuera, solo cartas especiales de tiro lejano (hoy, el Tiro de lejos),
   con castigo por la distancia. Precisa la regla 3 de D-31.
2. **Fallar no corta el Momento: el límite es tu mano** (D-31, regla 2), en el espíritu de Slay the
   Spire: el riesgo se ve antes y los errores desgastan en vez de matar de golpe.
   - Un fallo puede ser **robo**: 1 de cada 4 en la Salida y 1 de cada 6 en el Medio; el robo deja
     contragolpe al rival. La carta muestra el riesgo ("61% · robo 10%") y sale de una sola función,
     como el %.
   - **Fallar cuesta estamina:** la mitad del desgaste de la carta fallada, además del normal.
   - **Remate fallado:** la mitad de las veces el arquero se queda con la pelota (se acaba el Momento,
     sin contragolpe); la otra mitad hay rebote y sigues en el Área.
   - **Sin cartas para seguir:** puedes Aguantar el Balón (mano nueva, una vez por Momento); si no, el
     Momento se pierde sin contragolpe.
3. **Los números de cada zona salen de la formación del estilo** (D-30; "4 contra 2", 6 pts por jugador
   de diferencia) **y de la fuerza de la línea** (promedio de `skill_rating` de los titulares de esa
   línea, tuya contra la suya, ×0,5). Valores chicos, para medir; la fuerza de línea trae la jerarquía
   entre clubes (D-18).
4. **La postura mueve un jugador entre líneas** (HIGH: uno del medio sube; LOW: uno baja; el 5-3-2 nunca
   pasa de 3 arriba), **sin contar dos veces**: se mide con y sin el castigo plano que hoy pone LOW a
   los remates (`LOW_SHOT_PENALTY`).
Lo que ya calza: el Catenaccio (2 jugadas) juega Salida y Área; el contragolpe y el espacio rival
arrancan en el Medio; el Pelotazo (avanza 2) se salta una zona. Reemplaza, en el modo de zonas, el "2
fallos lo pierden" de GDD 2.1; el modo actual sigue igual hasta que el usuario elija tras medir y jugar.
Por qué: el usuario quiere que cada zona se sienta distinta (2026-10-28). Una simulación simple
(`cartas.md`, "Partido por zonas") mostró que con "fallar no corta" se marca casi lo mismo que hoy,
porque el límite real es la mano; lo que cambia es cuántos contragolpes hay (por eso el robo 1/4 y 1/6
en vez de 1/3 y 1/5 de D-32) y cuánto pesa el cansancio. Descartados: retroceder una zona al fallar
(marca mucho menos y deja sin cartas) y quitar los porcentajes como en Slay the Spire puro (rompe los
duelos de D-29 a D-31 y lo futbolero de que una jugada pueda salir mal).

**D-37 · 2026-10-28 · Concepto visual: la mesa del DT y la señal de TV (maqueta v3)** · VIGENTE
Amplía D-35 con el concepto elegido tras tres propuestas y tres versiones de maqueta (lienzo
"Dirección visual", fila v3, https://claude.ai/artifact/TxaUdVLTzGyWHzVjyD4jhm):
- **La semana es la mesa del DT, vista desde arriba:** cada cosa es un objeto con su material (hoja de
  calendario, libreta, diario El Chisme, contratos, post-its, portapapeles, cassette VHS, ficha médica,
  sobre de láminas, televisor de tubo, pizarra con imanes, entrada al estadio). Los pasos de la semana
  son los separadores de un archivador. Nada de barras de app, tarjetas web ni etiquetas tipo píldora:
  los efectos son timbres de tinta, cinta Dymo y plumón.
- **El partido es la señal de TV:** cancha en perspectiva de cámara, zonas marcadas con telestrador
  amarillo, marcador, zonas y relato como gráficas brillantes inclinadas de 2006, y carteles de los
  sponsors parodia. Tus láminas se sostienen frente al televisor; el desglose del % es una gráfica de TV
  sobre el relato.
- **La lámina:** doble marco impreso, banda de color por tipo, moneda dorada de PA (arriba a la derecha),
  sello negro con el bono (igual en la semana y en el partido), ventana con el dibujo de la jugada y, en el
  partido, la silueta del que la juega (camiseta del club y puesto, sin cara; no hay dorsales en los
  datos), placa de TV con el % (verde 60% o más, dorada 40-59%, coral menos de 40%; el número siempre
  visible) y pie con desgaste y robo. Las cartas que no se pueden jugar llevan una cinta que dice por qué.
- **Íconos propios** (nunca emojis): PA, estamina (gota), robo (pelota que se escapa), fatiga (batería),
  acierto (mira), popularidad (megáfono), disciplina (tarjeta) y riesgo (dado). Palabras clave en vez de
  oraciones.
- **Una acción a la vez:** chinchetas numeradas en lo pendiente (✓ en lo hecho) y la luz de la lámpara
  sobre lo que toca decidir; lo demás queda en penumbra. Texto de juego de 14 px o más (Steam Deck).
- **Letras:** Barlow y Barlow Condensed (cursiva con sombra dura en la TV, recta en las láminas),
  Permanent Marker solo para lo escrito a mano por el DT y Playfair Display solo para el nombre del diario.
Por qué: el usuario pidió cruzar la gráfica de TV del Apertura 2006 con la mesa de un DT llena de
recortes y láminas, sin tarjetas tipo web; la maqueta v1 se criticó (parecía un panel web con fondo de
madera), la v2 sumó materiales, sombras y TV, y la v3 aplicó una revisión externa (láminas vacías, número
grande que cambiaba de significado, demasiada prosa, decisiones sin orden). Descartados: el concepto
sobrio de planilla impresa y el puramente televisivo; emojis como íconos; etiquetas tipo píldora.

### Descartadas (para no reabrirlas sin datos nuevos)
- **Tempo ofensivo +7 / regen +3** (2026-10-26): no llegaba al objetivo de goles y quedó obsoleto con
  PA + Estamina; el stash se borró.
- **Dificultad base +7 pts** como palanca de goles (2026-10-26): ver D-12.
