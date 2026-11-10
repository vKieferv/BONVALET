# T-16 · Pulido visual del partido

Brief para una sesión (skill `tarea-autonoma`). **Se corre en el PC del usuario**: necesita pantalla para
las capturas y la prueba con mouse simulado.

- **Hito:** M1 (sensación de juego)
- **Rama:** `tarea/t-16-pulido-visual-partido`
- **Decisiones / ideas:** D-35, D-37 y D-41 (estilo: TV de 2006 + mesa del DT, cancha 3D). Guía: skill
  `director-arte-2006` (léela antes de tocar nada). Origen: análisis del 2026-11-09 sobre las capturas de
  `..\capturas-t15\v2\` y `..\capturas-t14\despues\`.
- **Requisitos:** **T-15 mezclada en `main`** (las dos tocan `match_view`). Si no lo está, detente y avisa.

## Objetivo
Que ninguna pantalla del partido se vea "vieja" o ilegible. La semana y el inicio ya están al día; lo que
falta está en el partido. No cambia ninguna regla ni ningún número: solo cómo se ve.

## Alcance (en este orden; cada punto es un commit)
1. **Cartel de gol.** Hoy es una caja verde redondeada con letra común (`6_gol.png`). Debe ser una gráfica
   de TV como "¡AL CÓRNER!" pero más grande: Barlow Condensed 800 cursiva, sombra dura, inclinada, con el
   nombre del goleador y el marcador nuevo. Entrada animada por código.
2. **Menú del partido rápido.** Hoy muestra la cancha plana 2D, el marcador antiguo ("FLOW", "BALÓN EN
   DISPUTA") y un panel tipo web (`0_menu.png`). Rehacerlo con el estilo de la previa de TV: los dos
   escudos, el rival y el modo para elegir, y la entrada "IR AL PARTIDO". Nada del partido viejo debe verse
   detrás.
3. **Mano legible.** Las láminas se tapan y cortan nombres y % (`1_ataque_apuntando.png`: "ELIG", "REMATE
   SIMPL"). Abanico que reparte el ancho disponible: de cada lámina siempre se ven el tipo, el costo, el
   nombre completo y la placa del %. La lámina bajo el cursor sube y pasa al frente. Probar con 5, 7 y 10
   láminas.
4. **Mesa en el turno del rival.** Hoy queda solo madera y la tirada (`8_ataque_rival.png`). Las láminas de
   defensa siguen visibles y la tirada no las tapa (va sobre la cancha o a un costado).
5. **Jugadores y etiquetas en la cancha.** Los jugadores de una zona quedan en fila y las etiquetas se pisan
   o se salen del borde (`3_tirada.png`, Suazo cortado en `1_ataque_apuntando.png`). Repartirlos en la zona
   con separación mínima, cada marcador junto a su marcado, y etiquetas que no se pisen ni salgan de la
   pantalla.
6. **Textos en español.** "LOW / NORMAL / HIGH" y "FLOW" (y cualquier otro texto en inglés a la vista).
   Usa los nombres que ya da `docs/gdd.md`; si no hay, "BAJO / NORMAL / ALTO" y anótalo.
7. **Pantallas sin revisar.** Captura el final del partido, la tabla y "ver mazo". Arregla lo chico (letra,
   colores, materiales de la guía); lo grande, solo anótalo en el informe con su captura.

## Fuera de alcance
- Reglas, probabilidades, bots y balance. `chance_breakdown` no se toca.
- Mazo nuevo y cartas v2 (D-45, D-47).
- La semana y la pantalla de inicio.
- Modelos 3D nuevos, sonido, traducción a otros idiomas.

## Definición de terminado
- [ ] `godot-check` en verde (con `smoke_match` y `mouse_duelos`); `-Balance` igual que `main`.
- [ ] Texto de juego de 14 px o más a 1280×720 en todo lo tocado.
- [ ] Capturas antes y después de cada punto en `C:\Users\vicen\Desktop\bonvalet\capturas-t16\`.
- [ ] Rama subida e informe (`capturas-t16\informe.md`) con lo que quedó sin verificar.

## Preguntas abiertas
- Cualquier duda de estilo: lo que diga `director-arte-2006`; si no lo cubre, la opción más sobria y nota
  en el informe.
