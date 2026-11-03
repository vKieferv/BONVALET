# T-11 · Pantalla del partido: TV de 2006, cancha 3D y duelos

Brief para una sesión (skill `tarea-autonoma`). **Se corre en el PC del usuario**: necesita ver la
pantalla (`tools/capturas.gd`). Reescrito el 2026-11-03 con todo lo decidido después de la v3.

- **Hito:** M2
- **Rama:** `tarea/t-11-pantalla-partido`
- **Decisiones / ideas:** **D-41** (cancha 3D low poly), **D-40 a D-43** (portador, marcas, habilidades,
  transición, jugada corta, presión), D-37 y D-35 (TV de 2006, láminas, sin caras), I-60 (el ataque del
  rival se ve), I-63 (la línea del pase es la trayectoria), I-58 (la tirada se ve).
- **Referencias, en este orden:**
  1. `scenes/prueba_3d/` (T-12, mezclada): cancha 3D, jugadores low poly, flecha-trayectoria por carta,
     etiquetas que no se tapan, CON EL BALÓN, láminas simples. **Es la base: se reutiliza, no se rehace.**
  2. Maqueta **v5** del lienzo "Dirección visual" (https://claude.ai/artifact/TxaUdVLTzGyWHzVjyD4jhm) y
     `docs/sts-futbol.md` (la estructura de Slay the Spire y la cuenta de cifras: unos 6 números en pantalla).
  3. El motor: modo de duelos de T-13 (`MatchEngine.duel_mode`, mezclado), con su `chance_breakdown`.
- **Requisitos:** T-12 y T-13 mezcladas en `main`.

## Objetivo
Que el usuario juegue un partido completo **a mano** con el modo de duelos y lo vea como la prueba 3D:
arrastrar el pase a un compañero, ver las marcas, ver jugar al rival. El partido de siempre no se rompe.

## Alcance
1. **El modo de duelos se juega en el partido real.** En el partido rápido, el menú permite elegir el modo
   (actual, zonas o duelos), con **duelos por defecto**. En la carrera, un ajuste en la mesa del DT con
   duelos por defecto. La pantalla nueva es la de duelos; los otros modos pueden seguir con la pantalla
   de hoy, siempre que funcionen.
2. **Cancha 3D (D-41)** dentro de la señal de TV: los 11 titulares de cada lado ubicados por zona según su
   formación (D-30) y su postura, con la cámara siguiendo la pelota de zona en zona. Al fondo, las zonas
   que no están en juego. Telestrador, nombres de zona y carteles, como en T-12.
3. **Tu ataque, conectado al motor:**
   - **CON EL BALÓN** con el portador real; sus láminas con su puesto en la silueta.
   - **Marcas** del rival en la zona siguiente (puntos del color del rival, LIBRE en verde), leídas del motor.
   - **Pase:** se arrastra la lámina; la línea es la trayectoria de esa carta (I-63) desde la pelota hasta el
     receptor apuntado. El % de la lámina se calcula para ese receptor con el motor y es el que se tira.
   - **Regates, controles y remates** se arrastran sobre el portador (o se sueltan en la cancha), con su %.
   - **La tirada se ve** (I-58): una aguja o un número contra el % ("Sacaste 34, necesitabas menos de 53").
   - Robo, atajada y rebote se ven en la cancha.
4. **El ataque del rival se mira (I-60):** cada jugada del bot se anima en la cancha (quién la tiene, a quién
   pasa, su % y su tirada), con botón para acelerar y otro para saltar. Tu defensa sigue con las cartas de
   hoy; la defensa nueva es D-44, en otra tarea.
5. **Estructura de Slay the Spire (v5):** marcador y camino del Momento arriba; PA abajo a la izquierda; mazo y
   descarte con su cantidad; un botón grande para terminar (CEDER JUGADA); Aguantar como acción secundaria.
   **Láminas simples:** costo, nombre, una línea (a FERNÁNDEZ ▼, ROBA 1) y un solo %. Los pases muestran ELIGE
   hasta que apuntas. La cuenta completa aparece al mantener la carta, como gráfica de TV.
6. **`smoke_match`** juega partidos completos en el modo de duelos con mouse simulado (como la prueba de T-12)
   y sigue comparando lo mostrado con el motor: PA, %, portador, marcas, desgaste y robo.

## Fuera de alcance
- Reglas y números del motor (T-13 los dejó medidos). Si algo de la pantalla pide una regla nueva, se anota.
- La defensa con habilidades (D-44), el mazo nuevo y las cartas v2 (D-45): tareas aparte.
- Remate, barrida, celebración y arquero animados más allá de lo mínimo (estirarse o quedarse con la pelota).
- Sonido.

## Definición de terminado
- [ ] `godot-check` en verde (y `-Balance` sin cambios con el modo apagado).
- [ ] Un partido completo jugado con mouse simulado en duelos, más capturas: ataque apuntando, pase en el aire,
      tirada, robo, gol y ataque del rival, en `C:\Users\vicen\Desktop\bonvalet\capturas-t11\`.
- [ ] Ningún texto de juego bajo 14 px a 1280×720; probado también a 1080p y 1440p.
- [ ] Cuadros por segundo con 22 jugadores.
- [ ] `docs/arquitectura.md` actualizado (estructura de `match_view` y la cancha 3D).
- [ ] Rama subida e informe con lo que se apartó de la v5 y lo que quedó sin verificar.

## Preguntas abiertas
- Si una parte de la v5 choca con el motor, gana el motor (lo que se tira) y se anota.
