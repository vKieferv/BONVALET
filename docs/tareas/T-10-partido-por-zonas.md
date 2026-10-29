# T-10 · Partido por zonas: motor, bots y medición

Brief para una sesión autónoma (skill `tarea-autonoma`). Puede correr en la nube: no necesita ver la
pantalla. La pantalla nueva del partido es T-11.

- **Hito:** M1/M2 (primer paso de los duelos, I-45)
- **Rama:** `tarea/t-10-partido-por-zonas`
- **Decisiones / ideas:** **D-36** (las reglas de esta tarea), D-30 (formaciones), D-31, D-32, D-04,
  D-16, I-48. Detalle y simulación previa: `docs/cartas.md`, secciones "Partido por zonas" y
  "Formaciones".
- **Mejor después de mezclar T-06** (los rivales crecen), porque las dos tocan la medición de `sim.gd`.
  Si T-06 sigue abierta, parte de `main` y anota en el PR qué habría que rehacer.

## Objetivo
Que el motor tenga un **modo de zonas** que se puede activar, con las reglas de D-36, que los bots lo
jueguen bien y que `balance-lab` lo compare lado a lado con el modo actual. **El modo actual no cambia**
(con el modo apagado, la línea base de `docs/arquitectura.md` ("Versión actual") tiene que dar lo mismo).

## Alcance
1. **Modo de zonas en `MatchEngine`** (un campo, por ejemplo `zone_mode`, apagado por defecto), que
   pasan quienes arman el partido (`DuelRunner`, `SimRunner`, `match_view`).
   - Zona según el avance del Momento: Salida → Medio → Área. Momento de 2 jugadas (Catenaccio) =
     Salida y Área; contragolpe y espacio rival = arranca en el Medio; Pelotazo (`steps` 2) salta una
     zona.
   - **Remates solo en el Área** (`can_play` los rechaza fuera, con el motivo para la UI). Las cartas de
     tiro lejano se marcan en `data/cards.json` con un campo nuevo (por ejemplo `"lejano": true`; hoy
     solo `tiro_de_lejos`) y se juegan desde el Medio con castigo de la distancia (valor de prueba −15,
     una línea del desglose), sin los números del Área.
   - **Números de la zona** en `chance_breakdown` (nunca directo en la tirada): formación (cuántos de cada
     lado según el arquetipo, D-30, con la postura moviendo un jugador del medio: HIGH arriba, LOW atrás;
     el 5-3-2 nunca más de 3 arriba; 6 pts por jugador de diferencia) y fuerza de línea (promedio de
     `skill_rating` de los titulares de esa línea: atrás = DFC y LAT, medio = MCD, MCO y EXT, arriba =
     DEL; la diferencia tuya contra la suya × 0,5). El motor no conoce planteles: quien arma el partido
     le pasa las 3 fuerzas de cada equipo y su formación (desde `SquadManager`), como ya pasa el
     `lineup`. Los valores (6 pts, ×0,5, −15) van como constantes comentadas, para que `balance-lab`
     los varíe.
   - **Fallos (D-36, regla 2):** sin `MAX_FAILS`. Un fallo en la Salida es robo con probabilidad 1/4,
     en el Medio 1/6: el Momento se pierde y el rival queda con contragolpe (como el robo de Aguantar,
     `ev["stolen"]`). Un fallo cuesta además la mitad del desgaste de la carta. Remate fallado: 1/2 el
     arquero se queda (fin, sin contragolpe), 1/2 rebote (sigues en el Área). Sin carta jugable: Aguantar
     si queda; si no, se pierde sin contragolpe.
   - **Riesgo de robo visible:** una función (por ejemplo `steal_chance(card)`) es la única fuente del
     "robo %" que mostrará la carta (prob. de fallar × prob. de robo de la zona), igual que
     `success_chance` para el %.
2. **Bots (`CoachBot`):** el planificador respeta las zonas (no planea remates fuera del Área salvo los
   lejanos), valora el riesgo de robo en la Salida (prefiere la carta más segura) y, sin remate en la
   mano al llegar al Área, aguanta. En defensa, sin cambios.
3. **`DuelRunner`, `SimRunner`, `sim.gd` y `match_view`:** pasan el modo y los datos de las líneas.
   En `match_view` basta una casilla "Partido por zonas (prueba)" en el menú del partido rápido y una
   línea de texto con la zona, los números y el robo % (sin rediseñar: eso es T-11), para que el usuario
   pueda probarlo. La carrera usa el modo actual hasta que el usuario decida.
4. **Medición (`balance-lab`, `tests/lab/zonas.json`):** modo actual contra modo de zonas, y dentro del
   modo de zonas: robo 1/4-1/6 contra 1/3-1/5; fuerza de línea ×0 contra ×0,5; 6 pts por jugador contra
   0; con y sin `LOW_SHOT_PENALTY`. En cada variante: goles por partido (inicio, mitad, final), lesiones,
   cansancio 1T/2T, **robos y contragolpes por partido**, Momentos perdidos sin cartas, constructibilidad
   y la jerarquía (Colo-Colo, U. de Chile y UC contra la matriz). Recuerda la advertencia del skill: una
   variante idéntica a la base = clave no aplicada.
5. **Ajuste:** si el modo de zonas queda fuera de 2.3-2.6 goles, se ajustan **solo los valores nuevos**
   (robo, factor de línea, pts por jugador, castigo del tiro lejano), nunca las constantes del modo
   actual. Si no se llega al rango con ellos, se reporta y no se fuerza.
6. **Pruebas en `engine_rules.gd`** para cada regla: zona según el avance, remate rechazado fuera del
   Área, tiro lejano con su castigo, robo con contragolpe, costo de estamina del fallo, rebote o atajada,
   sin cartas, números de zona en el desglose y `steal_chance` igual a lo que se tira.

## Fuera de alcance
- La pantalla nueva del partido (T-11) y cualquier cambio visual más allá de la casilla y la línea de texto.
- Duelos contra un jugador concreto y habilidades por jugador (D-29, paso 2 de los duelos).
- Cansancio por jugador (D-31, regla 6): el costo del fallo va a la estamina del equipo.
- Cambiar el modo actual o su línea base.

## Definición de terminado
- [ ] `godot-check -Balance` en verde; con el modo apagado, la matriz igual a la línea base.
- [ ] Tabla de `balance-lab` con todas las variantes del punto 4 en el PR.
- [ ] Pruebas nuevas en `engine_rules.gd`.
- [ ] `docs/arquitectura.md` (el modo de zonas) y `docs/gdd.md` (2.1, modo en prueba) actualizados.
- [ ] PR con recomendación de valores y lo que quedó sin verificar.

## Preguntas abiertas
- **Sangre fría** (firma de Aróstegui: +10 cuando un fallo más pierde el Momento) no tiene sentido sin
  `MAX_FAILS`. Opción conservadora: en el modo de zonas da +10 después de cualquier fallo del Momento.
  Anotarlo en el PR para que el usuario decida.
- Cualquier otra duda de diseño: no se inventa; opción conservadora y nota en el PR.
