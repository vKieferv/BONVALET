# T-11 · Pantalla del partido: la señal de TV por zonas

Brief para una sesión (skill `tarea-autonoma`). **Se corre en el PC del usuario**: necesita ver la
pantalla (`tools/capturas.gd`).

- **Hito:** M1/M2
- **Rama:** `tarea/t-11-pantalla-partido`
- **Decisiones / ideas:** **D-37** (concepto visual: léelo primero), D-35, D-36 (reglas por zonas), I-48,
  I-41 (intención del rival)
- **Requisitos:** T-09 (tema, letras, íconos, láminas, escudos) y T-10 (modo de zonas en el motor)
  mezcladas en `main`.
- **Maqueta (referencia):** lienzo "Dirección visual", https://claude.ai/artifact/TxaUdVLTzGyWHzVjyD4jhm,
  tablero **"v3 · Partido por zonas"** (y "v3 · Anatomía de la lámina e íconos" para las láminas).

## Objetivo
Que `match_view` se vea como la maqueta v3: la señal de TV arriba (cancha en perspectiva con las zonas,
marcador y relato como gráficas de 2006) y tus láminas en la mano abajo, sobre la mesa. Sin cambiar
reglas.

## Alcance
- **Cancha como cámara de TV:** perspectiva (la línea lejana más angosta), franjas de césped, público
  oscuro con grano arriba, carteles de los sponsors parodia junto a la línea lejana, líneas de TV y
  viñeta. Los jugadores son discos con los colores del club (sin caras).
- **Zonas con telestrador:** límites de Salida, Medio y Área en trazo amarillo discontinuo; la zona actual
  iluminada; la jugada hecha como trazo amarillo con flecha y la que sigue punteada; un círculo amarillo
  en el que tiene la pelota. Cada zona con una gráfica inclinada de TV de **un solo dato**: "SALIDA ✓",
  "MEDIO 4 vs 4 +2", "ÁREA 2 vs 4 −12" (el detalle de la fuerza de línea va en el desglose). En el modo
  actual (sin zonas), la cancha muestra el avance de la jugada sin números.
- **Marcador de TV** (arriba a la izquierda): canal, escudos generados o siglas en los colores del club,
  goles, minuto; debajo "TU MOMENTO N DE 4 · JUGADA N DE 3". Arriba a la derecha, "EN VIVO" y la postura
  como selector inclinado, bloqueado durante la jugada.
- **Desglose como gráfica de TV:** al pasar el mouse sobre una lámina, una barra sobre el relato muestra
  "NOMBRE · BASE · CARTA · ZONA = % · efecto si sale", con el % en la placa de su color. No tapa la cancha.
- **Relato:** barra inclinada abajo de la cancha.
- **Defensa:** la misma cancha muestra el camino del rival por tus zonas, con sus números.
- **Mano:** las láminas de T-09 casi derechas (±4°), la que está bajo el mouse levantada con borde dorado;
  placa de TV con el % y pie con desgaste y robo; los remates fuera del Área llevan la cinta "solo en el
  área".
- **Lateral:** moneda grande de PA ("3 DE 3 PA"), barra de estamina por segmentos con su zona y la mano
  que da, AGUANTAR (con PA, % y "mano nueva") y CEDER como gráficas inclinadas, y una nota a mano con los
  fallos del Momento.
- `smoke_match` sigue comparando lo mostrado con el motor (PA, insignias, desgaste, zona, robo); si cambian
  los textos, se actualiza la prueba para que compruebe lo mismo.

## Fuera de alcance
- Reglas y números (T-10 los dejó medidos), sonido, retratos de jugadores (sin caras, D-35).

## Definición de terminado
- [ ] `godot-check` en verde.
- [ ] Capturas de antes y después (ataque y defensa, en los dos modos) con `tools/capturas.gd`.
- [ ] Ningún texto de juego bajo 14 px a 1280×720.
- [ ] `CLAUDE.md` actualizado si cambia la estructura de `match_view`.
- [ ] PR con lo que se apartó de la maqueta y por qué.
