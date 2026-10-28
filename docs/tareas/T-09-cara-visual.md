# T-09 · Cara visual: tema del juego y semana nueva

Brief para una sesión (skill `tarea-autonoma`). **Se corre en el PC del usuario**, no en la nube: para
revisar el resultado hay que ver la pantalla, y `tools/capturas.gd` necesita una (no corre con
`--headless`).

- **Hito:** M2 (antes de los playtests de M1, para que den ganas de jugar)
- **Rama:** `tarea/t-09-cara-visual`
- **Decisiones / ideas:** D-35 (dirección visual), I-30, I-49 (informe del rival: solo con lo que ya existe)
- **Maquetas:** lienzo "Dirección visual", https://claude.ai/artifact/TxaUdVLTzGyWHzVjyD4jhm
  (tableros "Semana · Bloque 2", "Semana · Bloque 1" y "Guía de estilo"; el de "Partido por zonas" es
  para T-10, no se implementa aquí)

## Objetivo
Que la semana se vea como las maquetas y que todo el juego comparta un tema (letras, colores, cartas
como láminas, escudos generados), **sin cambiar ninguna regla ni número del juego**.

## Alcance
1. **Tema común.** Las letras Barlow y Barlow Condensed (archivos `.ttf` del repositorio oficial
   `github.com/google/fonts`, carpetas `ofl/barlow` y `ofl/barlowcondensed`, con su `OFL.txt`) en
   `assets/fonts/`. Un `Theme` del proyecto (`gui/theme/custom` en `project.godot`) con los colores de
   la guía de estilo: noche `#0b111b`, tablero `#111a28`, oro `#f2b63d` (PA y lo importante), celeste
   `#5cc8ff` (estamina), verde `#4fd18b` (sale bien), coral `#ff7a6b` (falla), papel `#f4efe3` (cartas y
   diario). Los colores que el código usa en varias escenas van a un solo lugar (por ejemplo una clase
   `Paleta` con constantes) en vez de repetirse.
2. **Escudos generados:** un `Control` que dibuja un escudo con una forma (partido, franja, banda,
   rayas, círculo) y los dos colores del club de `teams_chile_2006.json` (`primary_color`,
   `secondary_color`); la forma sale del id del club de forma determinista. Nunca el escudo real.
3. **Cartas como láminas** (`scenes/card_ui.gd`/`.tscn`): papel crema, banda superior con el color de su
   tipo (pase azul, control verde, centro violeta, remate naranja, defensa gris, corte gris oscuro), moneda
   dorada con el costo en PA, nombre grande, %, efecto y desgaste. Al pasar el mouse la carta se levanta.
   Los textos que comprueba `smoke_match` (insignia de PA, desgaste, % y línea de efecto) se mantienen, o
   se actualiza la prueba para que siga comprobando lo mismo.
4. **Semana nueva** (`scenes/calendar_view.gd`, construida en código como hoy):
   - **Cabecera:** escudo, club, "Apertura 2006 · Semana N", DT, y presupuesto, popularidad y
     disciplina (con barras) y fatiga.
   - **Pasos** 1 Prensa → 2 Entrenamiento → 3 Partido: se ve un paso a la vez; los resueltos quedan
     como resumen de una línea ("Telnet · Dar permiso").
   - **Bloque 1:** los sponsors como dos fichas con sus términos en etiquetas; el evento como portada
     de Diario El Chisme con sus dos botones y lo que da y arriesga cada uno, sacado de
     `career_2006.json` (no se escriben números a mano).
   - **Bloque 2:** tres fichas grandes (táctico, video, kinesiología) con su efecto en etiquetas; las
     cartas ofrecidas y el mazo de la sesión de video se muestran como láminas; "Ver mazo" igual.
   - **Columna derecha:** próximo partido como promo de TV (escudos, estadio, estilo y DT del rival, su
     figura) e informe del rival con lo que ya existe (estilo, figura, cuántas cartas tiene su mazo); tu
     once en una cancha chica, con ★ en los que tienen carta propia; IR AL PARTIDO grande, que dice qué
     falta si está deshabilitado.
   - **Pantalla inicial** (sin carrera): selector de club, Comenzar y Continuar con el mismo estilo.
5. **Partido, solo lo mínimo para que no desentone:** usa el tema (letras y colores), las láminas nuevas
   y el escudo en el marcador; se quita el texto de depuración de la postura
   ("[FIJA DURANTE LA JUGADA]…", pasa a un tooltip). La pantalla del partido se rehace en T-10.
6. **Capturas:** `tools/capturas.gd` (ver su cabecera) antes de empezar y al terminar. Las de antes y
   después van en el PR (o, si no se pueden adjuntar, la ruta donde quedaron).

## Fuera de alcance
- Reglas del partido, números de balance, datos de `data/*.json`.
- El partido por zonas (T-10, en diseño) y la pantalla nueva del partido.
- Sonido, menú principal, tutorial, arte de jugadores (D-35: sin caras).

## Definición de terminado
- [ ] `godot-check` en verde (`smoke_career` y `smoke_match` siguen probando los mismos flujos).
- [ ] Capturas de antes y después de la semana (inicio, Bloque 1, entrenamiento táctico) y del partido.
- [ ] Las letras con su licencia en `assets/fonts/`.
- [ ] `CLAUDE.md` actualizado (dónde viven el tema, la paleta y los escudos).
- [ ] PR con el resumen y lo que se apartó de la maqueta y por qué.

## Preguntas abiertas
Si algo de la maqueta no calza con lo que el juego sabe hacer (por ejemplo, un dato que no existe), no
se inventa: se muestra lo que hay y se anota en el PR.
