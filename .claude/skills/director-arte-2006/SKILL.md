---
name: director-arte-2006
description: Reglas de estilo visual de Futbolista Deckbuilder ("transmisión de TV 2006 + láminas de álbum", D-35 y D-37) - paleta, letras, materiales, anatomía de la lámina, íconos y lo prohibido. Úsalo antes de tocar cualquier UI (scenes/, card_ui, calendar_view, match_view, temas, íconos) o de hacer una maqueta, en vez de pedir capturas para recordar el estilo.
---

# director-arte-2006

Fuente: D-35 y D-37 en `docs/decisiones.md`. Referencia visual: lienzo "Dirección visual"
(https://claude.ai/artifact/TxaUdVLTzGyWHzVjyD4jhm), **fila v3** (las filas de arriba son descartes).
Solo mira capturas si este resumen no alcanza.

## Concepto
- **La semana es la mesa del DT** vista desde arriba: cada cosa es un objeto con su material (calendario,
  libreta, diario El Chisme, contratos, post-its, portapapeles, cassette VHS, ficha médica, sobre de
  láminas, televisor de tubo, pizarra con imanes, entrada al estadio). Pasos = separadores de archivador.
- **El partido es la señal de TV:** cancha en perspectiva de cámara, telestrador amarillo, gráficas
  brillantes inclinadas (skew −12°), carteles de sponsors parodia. Las láminas se sostienen abajo.

## Paleta
| Nombre | Hex | Uso |
|---|---|---|
| Noche | `#0b111b` | fondo de TV y paneles oscuros |
| Tablero | `#111a28` | paneles, barras de TV |
| Oro | `#f2b63d` | PA, lo importante, zona actual |
| Celeste | `#5cc8ff` | estamina |
| Papel | `#f4efe3` (lámina `#f6f0e1`) | cartas, diario |
| Césped | `#1e6439` (franjas `#2d6a3a`/`#3f8a4b`) | cancha |
| Madera | `#2a1b11` + veta | la mesa |
| Verde / Coral | `#4fd18b` / `#ff7a6b` | sale bien / falla |
Tinta de timbres: verde `#1c6b3e`, rojo `#b3261e`, azul `#1d4f9e`. Plumón: `#1b2a6b`.
Banda por tipo: pase `#2f6fd6`, control `#1f8a5c`, centro `#7a4fc2`, remate `#d0562a`, defensa `#5d6b80`.

## Letras
- **Barlow Condensed:** 800 cursiva con sombra dura (0 2px 0 negro) en la TV; 800 recta en láminas y
  números grandes (% 46-56 px); 700 en mayúsculas espaciadas para rótulos.
- **Barlow:** textos y relato. **Permanent Marker:** solo lo escrito a mano por el DT.
  **Playfair Display 900:** solo el nombre del diario.
- Texto de juego **14 px o más** a 1280×720 (Steam Deck).

## Materiales (cada uno su sombra; nunca la misma para todo)
Papel: sombra de contacto + elevación, esquinas rectas, levemente girado (±1-4°). Lámina: borde blanco
troquelado de 6 px, radio 10, brillo diagonal. Post-it: curva abajo. Cinta: translúcida, sin sombra.
Barras de TV: degradado con corte al 50%, borde superior claro, sombra dura. Grano de película encima.

## La lámina
Doble marco del color del tipo · banda con el tipo · moneda dorada de PA arriba a la derecha · **sello
negro con el bono** arriba a la izquierda (igual en semana y partido) · ventana con trama de puntos y el
dibujo de la jugada (en el partido, silueta del que la juega con camiseta del club y su puesto, sin cara)
· nombre + palabras clave · **placa de TV con el %** (verde ≥60, dorada 40-59, coral <40; el número
siempre visible) · pie con desgaste (gota) y robo. Carta no jugable: cinta con el motivo.

## Íconos (propios, nunca emojis)
PA (moneda), estamina (gota), robo (pelota con líneas de movimiento; no un círculo con flecha, que parece
el símbolo de masculino), fatiga (batería), acierto (mira), popularidad (megáfono), disciplina (tarjeta),
riesgo (dado).

## Prohibido
Tarjetas tipo web, etiquetas tipo píldora, barras de app arriba, retículas perfectas · emojis · escudos,
marcas o caras reales (escudos generados con forma + colores del club; marcas siempre parodia) · prosa
larga en cartas y objetos (palabras clave) · más de una acción encendida a la vez (chinchetas numeradas y
la luz de la lámpara sobre lo pendiente).
