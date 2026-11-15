# T-18 · El triángulo de estilos — informe

## Qué cambió (en lenguaje de juego)
- **Tiki-Taka vence a Catenaccio, Catenaccio vence a Contragolpe, Contragolpe vence a Tiki-Taka.** Directo y Kamikaze no ganan ni pierden con nadie.
- Cada carta del partido por duelos muestra una línea **"Ventaja de estilo"**: **+3** si tu estilo le gana al del rival, **−3** si él le gana al tuyo, y nada si no hay ventaja. También cuenta en las cartas de defensa.
- En la previa del partido, bajo el rival, sale un cartel dorado: por ejemplo *"Contragolpe · te conviene Catenaccio (con Tiki-Taka sufres)"* (captura `0_menu.png`). En la semana de la carrera, el post-it del rival suma la línea "te conviene X".
- La tabla y el valor viven en `data/estilos.json` (`activo`, `puntos`, `vence_a`). Apagarla (`"activo": false`) deja el partido como antes.

## Mediciones (150 partidos por cruce, modo de duelos, mazo de hoy)
Cómo se midió: Colo-Colo contra sí mismo, mismo plantel y mismo mazo, cambiando solo el estilo de cada lado (su bot y su forma de marcar). Puntos = % de los puntos en juego (3-1-0) que se lleva el primer estilo. Cada cruce se midió en los dos sentidos.

| Cruce (el que debería ganar primero) | Sin ventaja | N = 6 | **N = 3 (final)** |
|---|---|---|---|
| Tiki-Taka vs Catenaccio | 56,5% | 78,1% | **66,2%** |
| Catenaccio vs Tiki-Taka (inverso) | 48,4% | 26,9% | 42,7% |
| Catenaccio vs Contragolpe | 31,7% | 39,4% | **36,9%** |
| Contragolpe vs Catenaccio (inverso) | 78,3% | 71,9% | 75,0% |
| Contragolpe vs Tiki-Taka | 62,2% | 79,4% | **71,9%** |
| Tiki-Taka vs Contragolpe (inverso) | 52,7% | 33,5% | 38,9% |

Goles totales por partido en estos cruces: entre 0,85 y 1,84 (más bajos que la liga, porque es Colo-Colo contra sí mismo; no es la matriz de 2,3-2,6). La ventaja casi no los mueve.

**Valor final de N = 3.** Con 6, dos cruces pasaban de 78% (demasiado). Con 3, Tiki-Taka sobre Catenaccio queda en ~62% promediando los dos sentidos y Contragolpe sobre Tiki-Taka en ~66%.

## Lo que no quedó bien (decisión para el usuario)
- **Catenaccio contra Contragolpe sigue perdiendo aunque tenga la ventaja** (37% con N = 3, 39% con N = 6). Ya sin ventaja, el bot de Contragolpe le gana 78-32 al de Catenaccio: es el perfil de juego de los bots, no el valor de N. El brief decía ajustar solo N, así que no lo toqué; para que el triángulo sea parejo habría que subir a Catenaccio (cartas o perfil del bot), que es una decisión de balance.
- 150 partidos por cruce dejan un margen de ±4 puntos aproximadamente: los porcentajes son orientativos.

## Verificación
- `godot-check` (compila todo, pruebas, partidos de humo): **verde**.
- Pruebas nuevas: `engine_rules` (línea solo con ventaja, simétrica, Directo/Kamikaze sin línea, N cambia el %, defensa, apagada = sin línea) y `data_rules` (triángulo cerrado, cada estilo vence a uno y pierde con otro).
- Las pruebas viejas de duelos, que cuentan porcentajes exactos, ahora corren con la ventaja apagada (`_duel_engine`); así no cambian.
- `-Balance`: pasó; goles totales en los partidos de Colo-Colo 2,55, igual a la línea base de `docs/arquitectura.md` (el modo normal no usa la ventaja).
- Capturas: `0_menu.png` (previa con la recomendación) y `4_cuenta.png` (la cuenta de Toque-toque con "Ventaja de estilo −3"). Las demás son las de siempre del partido.

## Sin verificar
- **El post-it de la semana en la carrera** (`calendar_view`) no se capturó: con 4 líneas de texto puede quedar apretado en el papel de 150×104.
- Los córners y Aguantar el Balón no llevan la línea (tienen su propia cuenta).
- No se midió la temporada ni otros estilos (el usuario lo pidió así).
- El motor avisa "Se pidió un tamaño negativo" al armar la pantalla de duelos; es anterior a esta tarea.
