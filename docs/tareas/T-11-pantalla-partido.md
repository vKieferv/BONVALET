# T-11 · Pantalla del partido por zonas

Brief para una sesión (skill `tarea-autonoma`). **Se corre en el PC del usuario**: necesita ver la
pantalla (`tools/capturas.gd`).

- **Hito:** M1/M2
- **Rama:** `tarea/t-11-pantalla-partido`
- **Decisiones / ideas:** D-35 (dirección visual), D-36 (reglas por zonas), I-48, I-41 (intención del rival)
- **Requisitos:** T-09 (tema, láminas, escudos) y T-10 (modo de zonas en el motor) mezcladas en `main`.
- **Maqueta:** lienzo "Dirección visual", tablero "Partido por zonas"
  (https://claude.ai/artifact/TxaUdVLTzGyWHzVjyD4jhm)

## Objetivo
Que `match_view` se vea como la maqueta: la cancha dividida en Salida, Medio y Área, el marcador como
gráfica de TV, el relato abajo y la mano de láminas con su % y su robo %. Sin cambiar reglas.

## Alcance
- **Marcador de TV:** "Televisora Nacional", escudos generados, goles, minuto, "EN VIVO"; "Tu Momento N
  de 4 · jugada N de 3"; postura como selector bloqueado durante la jugada (lo de "fija durante la
  jugada" va en un tooltip).
- **Cancha por zonas** (en el modo de zonas): cada zona con su nombre, estado (hecha, ahora, falta),
  los puntos de cada equipo ("4 contra 2"), lo que suma o resta y una línea corta (la fuerza de la línea,
  "aquí se remata"). La pelota se mueve de zona en zona con una animación corta. En el modo actual, la
  cancha muestra el avance de la jugada sin números.
- **Defensa:** la misma franja muestra el camino del rival por tus líneas (sus números en cada zona).
- **Relato:** una línea abajo de la cancha con lo que pasó y lo que pasa (los textos que hoy van en el
  registro del partido).
- **Mano:** las láminas de T-09 con "% · robo %"; los remates fuera del Área se ven apagados con "Se
  juega en el Área"; al pasar el mouse, el desglose (base, carta, línea, números) sobre la carta.
- **Lateral:** PA (orbe dorado), estamina con su zona y la mano que da, Aguantar el Balón (con su % y lo
  que da) y Ceder la jugada.
- `smoke_match` sigue comparando lo mostrado con el motor (orbe, insignias, desgaste, zona); si cambian
  los textos, se actualiza la prueba para que compruebe lo mismo, y se le suma el robo %.

## Fuera de alcance
- Reglas y números (T-10 los dejó medidos), sonido, arte de jugadores (sin caras, D-35).

## Definición de terminado
- [ ] `godot-check` en verde.
- [ ] Capturas de antes y después (ataque y defensa, en los dos modos) con `tools/capturas.gd`.
- [ ] `CLAUDE.md` actualizado si cambia la estructura de `match_view`.
- [ ] PR con lo que se apartó de la maqueta y por qué.
