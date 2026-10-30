# Slay the Spire traducido al fútbol (análisis, 2026-10-30)

Pedido del usuario: "traducir StS a un juego de fútbol". Este documento compara la estructura del
juego y de la pantalla con StS y otros juegos de cartas parecidos, y dice qué mejorar. Maqueta de
referencia: lienzo "Dirección visual", fila **v5** (https://claude.ai/artifact/TxaUdVLTzGyWHzVjyD4jhm).
Nada de esto es una decisión: lo que se acepte pasa por `ideas.md` y `decisiones.md`.

## 1. La traducción, pieza por pieza
| Slay the Spire | Futbolista 2006 | Estado |
|---|---|---|
| Combate | Partido | Existe |
| Tu turno | Tu Momento (ataque) | Existe |
| Turno del enemigo | Ataque del rival (tu defensa) | Existe, pero se juega oculto → I-60 |
| Energía | PA | Existe |
| Vida que se arrastra entre combates | Estamina en el partido + fatiga de la semana | Existe (del equipo); por jugador en D-31 |
| Bloqueo | Presión y Bloqueo de tu defensa | Existe |
| Intención del enemigo | Marcas del rival y su ataque anunciado | D-40, I-41 |
| Tu personaje | El que tiene la pelota (cambia con cada pase) | D-40 |
| Elegir a qué enemigo atacar | Elegir a qué compañero pasar, según sus marcas | D-40 |
| Poderes (duran todo el combate) | Instrucciones (una a la vez) | D-39 |
| Cartas de estado (Herida, Aturdido) | Cartas de penalización (nervios, funa) | Existe |
| Personajes distintos | Estilos del DT (Tiki-Taka, Directo, Catenaccio...) | Existe |
| Mapa del acto | Calendario de la temporada | Existe (mesa del DT) |
| Evento "?" | Prensa y vestuario | Existe, con un solo evento → I-57 |
| Fogata: descansar o mejorar | Entrenamiento físico o táctico, y sesión de video ("+") | Existe |
| Recompensa de cartas | Oferta del entrenamiento | Existe |
| Tienda | Mercado de pases | No existe (sin economía de fichajes) |
| Élite y jefe | Clásicos y la final de la rueda | No existe: idea a conversar |
| Reliquias | Cábalas del DT | I-53, en espera |
| **Pociones** | **Los 3 cambios del partido**, de un solo uso | **Nueva: I-62** |

Lo que más falta para sentirse como StS, en orden: **ver al rival** (su intención y su turno), **elegir
objetivo** (D-40) y **pocas cifras en pantalla**. El resto de la estructura ya calza.

## 2. La pantalla del partido contra el estándar del género
Referencias: StS (la base), Monster Train (varias zonas a la vez), Marvel Snap (3 lugares con su total
a la vista), Inscryption (la mesa como mundo, como nuestra mesa del DT), Balatro (cada punto se cuenta
en vivo y "se siente") y NUTMEG! (fútbol por fases con cartas).

**Prioridad alta**
1. **Un número por carta.** StS muestra costo y un número (daño o bloqueo), y ese número cambia de
   color cuando algo lo modifica: verde si sube, rojo si baja. Nuestra lámina tenía bono, %, robo y
   desgaste. En v5 quedan el costo y el %, más una línea (a FERNÁNDEZ ▼, ROBA 1). Falta pintar el %
   de verde o rojo cuando un efecto lo mueve (el Flow, una instrucción).
2. **La intención del rival se ve en la cancha, no en un texto.** En StS el ícono va sobre la cabeza del
   enemigo. Aquí: puntos del color del rival junto a tus jugadores (●● = doble marca) y, al defender, un
   ícono sobre el que va a rematar con cuántas jugadas le faltan (I-41).
3. **El turno del rival se mira** (I-60): sus cartas, su % y su tirada, con botón para acelerar.
4. **Mazo y descarte a la vista**, con su cantidad, abajo a la izquierda y abajo a la derecha. Sin eso,
   un jugador de deckbuilders no puede planificar. Hoy no existen en `match_view`.
5. **Un botón principal para terminar** (CEDER JUGADA, como "Terminar turno"). Aguantar pasa a ser una
   acción secundaria más chica, junto al mazo, porque da una mano nueva.
6. **Que cada jugada se sienta** (lo que Balatro hace con los puntos): la carta vuela al jugador, el balón
   viaja, la tirada se ve como una aguja contra el % (I-58) y el gol tiene su repetición y su grito.

**Prioridad media**
7. **Palabras clave con explicación al pasar el mouse** (ROBA, ATRÁS, AVANZA 2), como en StS.
8. **La cámara sigue la jugada:** encuadra la zona en juego, y las otras quedan como el camino de arriba
   (Salida ● — Medio — Área). Así las zonas se marcan solas, sin cajas ni números.
9. **Mostrar por excepción:** la estamina de cada jugador solo aparece cuando importa (una gota naranja si
   está cansado), como StS, que no llena la pantalla de barras que no cambian nada.
10. **Barra de arriba fija:** marcador, minuto y camino; más adelante, las cábalas (I-53) y los cambios
   que te quedan (I-62).

**Prioridad baja**
11. **El costo arriba a la izquierda,** como en StS (hoy la moneda va arriba a la derecha y el sello del
   bono a la izquierda, D-37). Cambiarlo es menor, pero toca la anatomía de la lámina: decidirlo junto
   con T-11.
12. **Jugadores con vida:** respiran y miran la pelota aunque nadie juegue.

**La cuenta de cifras** (cuántos números ve el jugador a la vez, en el mismo momento del pase): v4 más de
30; v5 unos 6 (marcador, minuto, PA, mazo, descarte y el % de la carta que apuntas).

## 3. La cancha en 3D, low poly (idea del usuario: estilo Unturned)
**Por qué calza:** los juegos de fútbol de 2006 eran 3D de pocos polígonos vistos como TV, así que una
cancha 3D simple encaja con D-35 (TV de 2006) mejor que una 2D. En Godot 4 la cancha 3D puede vivir
dentro de la pantalla 2D (un `SubViewport`): las láminas, la barra de TV y los botones siguen en 2D, y
el motor (`core/`) no cambia.

**Lo que cuesta:** un modelo de jugador (los colores del club por material, sin caras, D-35), la pelota,
la cancha, una cámara de TV y animaciones mínimas (quieto, correr, pasar, rematar, barrer, celebrar).
Hay paquetes de personajes low poly con licencia libre (por ejemplo de Kenney o Quaternius): revisar la
licencia de cada uno antes de usarlo.

**Riesgo:** el arte 3D se come el tiempo de un desarrollador solo (lo que D-35 quería evitar). Por eso,
antes de T-11, conviene una **prueba técnica de una sesión**: una zona, 8 jugadores low poly con los
colores de dos clubes, la cámara de TV, la pelota viajando entre dos jugadores, a 1280×720 y midiendo
el rendimiento (pensando en Steam Deck).
- Si sale bien, T-11 hace la cancha en 3D con las reglas de pantalla de v5.
- Si no, T-11 la hace en 2D con las mismas reglas, y el 3D vuelve a esperar (I-54).

## 4. Qué sigue
1. Prueba técnica 3D (una sesión, rama propia, sin tocar el motor).
2. Motor de D-40: el que tiene la pelota, las marcas y las 5 habilidades (tarea nueva, puede ir en la nube).
3. T-11 con lo que salga de 1 y 2, siguiendo v5.
