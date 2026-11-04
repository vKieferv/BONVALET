# Playtest 2026-11-04 · pantalla del partido T-11 (rama `tarea/t-11-pantalla-partido`, 93405bf)

- **Modo:** partido rápido, modo duelos, cancha 3D · **Club:** Colo-Colo · **Rival:** sin registrar
- El usuario lo mira como "un mockup": se evalúa la idea, no el acabado.

## Momentos que se sintieron bien
- Se entiende quién tiene la pelota.
- Arrastrar el pase "se siente bien".
- La tirada se entiende (aunque él la entiende porque la está programando).

## Momentos que se sintieron mal o confusos
- El % está solo en la lámina: "debería estar cerca del jugador al que le pasaremos el balón".
- "No me deja jugar cartas de pase entre jugadores de la misma zona."
- La barra de la tirada es delgada.
- El ataque del rival "se hace largo, pero es porque solo vemos sus acciones".

## Hallazgos
| # | Hallazgo | Pilar | Tipo | Severidad |
|---|---|---|---|---|
| 1 | El % del pase no aparece junto al receptor apuntado | 2 | UI | media |
| 2 | No se puede pasar dentro de la misma zona | 1 | regla | alta |
| 3 | La barra de la tirada es delgada | 2 | UI | baja |
| 4 | Mirar el ataque rival sin hacer nada se hace largo | 1 | UI / regla | media |

## Propuestas
- 1 y 3 → arreglos en T-11.
- 2 → **D-46** (pase en la misma zona, sin avanzar), en T-11 con el mínimo cambio en el motor.
- 4 → corto plazo: el ataque rival más rápido por defecto y una pausa solo en lo importante (pase clave,
  remate, gol). De fondo lo resuelve **D-44**: tú defiendes jugando cartas durante su ataque.
