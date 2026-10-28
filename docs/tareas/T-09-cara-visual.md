# T-09 · Cara visual: la lámina, los íconos y la semana como mesa del DT

Brief para una sesión (skill `tarea-autonoma`). **Se corre en el PC del usuario**, no en la nube: para
revisar el resultado hay que ver la pantalla, y `tools/capturas.gd` necesita una (no corre con
`--headless`).

- **Hito:** M2 (antes de los playtests de M1, para que den ganas de jugar)
- **Rama:** `tarea/t-09-cara-visual`
- **Decisiones / ideas:** **D-37** (el concepto y sus reglas: léelo primero), D-35, I-30, I-49
- **Maquetas (referencia):** lienzo "Dirección visual", https://claude.ai/artifact/TxaUdVLTzGyWHzVjyD4jhm,
  **fila v3**: "v3 · Prensa", "v3 · Entrenamiento" y "v3 · Anatomía de la lámina e íconos". El tablero
  "v3 · Partido por zonas" es para T-11. Las filas de más arriba son versiones descartadas.

## Objetivo
Que la semana se vea como la mesa del DT de la maqueta v3 y que las cartas sean las láminas nuevas (en
la semana y en el partido), **sin cambiar ninguna regla ni número del juego**.

## Alcance
1. **Letras** en `assets/fonts/`, con su licencia al lado, desde el repositorio oficial
   `github.com/google/fonts`: Barlow y Barlow Condensed (`ofl/barlow`, `ofl/barlowcondensed`, OFL),
   Permanent Marker (`apache/permanentmarker`, Apache 2.0, solo para lo escrito a mano por el DT) y
   Playfair Display (`ofl/playfairdisplay`, OFL, solo para el nombre del diario).
2. **Tema y paleta:** un `Theme` del proyecto (`gui/theme/custom`) y una clase con las constantes de color
   y de material (sombras de papel, de lámina, de post-it; tintas de timbre) para no repetirlas en cada
   escena. Las texturas (madera, grano del papel, trama de puntos, líneas de TV) se generan en Godot
   (`NoiseTexture2D`/`FastNoiseLite` o un shader), sin imágenes bajadas de internet.
3. **Íconos propios** como recursos del proyecto (SVG o dibujados por código), nunca emojis: PA, estamina
   (gota), robo (pelota que se escapa), fatiga (batería), acierto (mira), popularidad (megáfono),
   disciplina (tarjeta) y riesgo (dado). Formas en el tablero de anatomía.
4. **La lámina nueva** (`scenes/card_ui.gd`/`.tscn`), como en el tablero de anatomía:
   - doble marco impreso del color del tipo, banda con el tipo, moneda de PA arriba a la derecha;
   - **sello negro con el bono** (+20) arriba a la izquierda de la ventana, igual en la semana y en el
     partido;
   - ventana con trama de puntos y el dibujo de la jugada según el tipo de carta; en el partido, además, la
     silueta del jugador que la juega (camiseta con los colores del club y su puesto, sin cara; no hay
     dorsales en los datos);
   - nombre, palabras clave en vez de oraciones ("AVANZA · ROBA 1");
   - en el partido, **placa de TV con el %** (verde ≥60%, dorada 40-59%, coral <40%; el número siempre
     visible) y pie con desgaste y robo (el robo existe recién con T-10: mientras tanto, solo desgaste);
   - las cartas que no se pueden jugar llevan una cinta con el motivo en vez de verse apagadas.
   Los textos que comprueba `smoke_match` (PA, desgaste, % y efecto) se mantienen o se actualiza la prueba
   para que siga comprobando lo mismo.
5. **La semana como mesa del DT** (`scenes/calendar_view.gd`, construida en código como hoy):
   - **Separadores de archivador** arriba para los pasos (1 Prensa, 2 Entrenamiento, 3 Partido).
   - **Prensa:** hoja de calendario ("SEMANA N"), libreta con caja, popularidad, disciplina y fatiga (con
     íconos), diario El Chisme con el evento, contratos de los sponsors y las dos decisiones del evento
     como post-its con timbres. Los valores salen de `career_2006.json`, no se escriben a mano.
   - **Entrenamiento:** portapapeles (táctico), cassette VHS (video) y ficha médica (kinesiología) con su
     timbre de fatiga; el táctico abre el **sobre de láminas** con las 3 ofrecidas; el video muestra tu
     mazo como láminas para mejorar; televisor de tubo con la promo del domingo; pizarra con tu once (★ en
     los que tienen carta propia) y la fatiga del plantel; post-it con el informe del rival (solo datos que
     existen: estilo, figura); **IR AL PARTIDO** como entrada al estadio, apagada y con "falta el paso N"
     mientras falte algo.
   - **Una acción a la vez:** chinchetas numeradas en lo pendiente, ✓ en lo hecho, y la luz de la lámpara
     sobre lo que toca decidir.
   - **Pantalla inicial** (sin carrera): selector de club, Comenzar y Continuar, en el mismo estilo.
6. **Escudos generados:** un `Control` que dibuja un escudo con una forma y los dos colores del club
   (`primary_color`, `secondary_color`); la forma sale del id del club de forma determinista. Nunca el real.
7. **Partido, solo lo mínimo:** usa las láminas nuevas y el escudo en el marcador; el texto de depuración
   de la postura pasa a un tooltip. La pantalla del partido se rehace en T-11.
8. **Capturas** con `tools/capturas.gd` antes de empezar y al terminar; las de antes y después van en el
   PR (o la ruta donde quedaron), junto a la maqueta para comparar.

## Fuera de alcance
- Reglas del partido, números de balance, datos de `data/*.json`.
- El partido por zonas (T-10) y la pantalla nueva del partido (T-11).
- Sonido, menú principal, tutorial, retratos de jugadores.

## Definición de terminado
- [ ] `godot-check` en verde (`smoke_career` y `smoke_match` siguen probando los mismos flujos).
- [ ] Capturas de antes y después de la semana (inicio, prensa, entrenamiento táctico) y del partido.
- [ ] Letras con su licencia en `assets/fonts/`.
- [ ] Ningún texto de juego bajo 14 px a 1280×720.
- [ ] `CLAUDE.md` actualizado (dónde viven el tema, la paleta, los íconos, la lámina y los escudos).
- [ ] PR con el resumen y lo que se apartó de la maqueta y por qué.

## Preguntas abiertas
Si algo de la maqueta no calza con lo que el juego sabe hacer (por ejemplo, un dato que no existe), no
se inventa: se muestra lo que hay y se anota en el PR.
