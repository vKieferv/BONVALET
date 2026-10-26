# Hoja de ruta

Etapa actual: **prototipo jugable, entrando a vertical slice** (2026-10-26).

Cada hito tiene un criterio de salida. Al cerrarlo, sus reglas se congelan: cambiarlas exige una
entrada en `decisiones.md`. Las ideas nuevas van a `ideas.md`, no al hito en curso.

| Hito | Objetivo | Criterio de salida |
|---|---|---|
| **Sprint 0 · Cimientos** | Cerrar Aguantar, documentos de diseño, skills, GitHub y pruebas en la nube | El repo está en GitHub, las pruebas corren solas en cada PR y el GDD vive en el repo |
| **M1 · El partido es divertido** | Decidir y congelar las reglas del partido + mínimo de sensación de juego | 5 playtests seguidos (`docs/playtests/`) sin cambios grandes de reglas |
| **M2 · Deckbuilder de verdad** | Ganar, quitar y mejorar cartas; perfiles de DT; canteranos | Dos carreras distintas terminan con mazos claramente distintos |
| **M3 · Una temporada** (vertical slice) | Apertura 2006 completo: fixture, tabla, guardado, fin del torneo | Se juega de principio a fin con un club |
| **M4 · Identidad** | Dirección de arte, sonido, menú, tutorial | Hay GIFs y video para una página de Steam |
| **M5 · Contenido** | Más planteles, Primera B, Clausura, eventos | Demo pública |

## Sprint 0 · Cimientos
- [x] Aguantar el Balón, remates a 2 PA, constructibilidad (D-10 a D-13)
- [x] Pilares, GDD vivo, buzón de ideas, registro de decisiones, esta hoja de ruta
- [x] `balance-lab` permanente y skills de proceso (`idea-nueva`, `playtest`, `tarea-autonoma`)
- [ ] Repo privado en GitHub (lo crea el usuario; luego push)
- [ ] Versión Linux de la verificación (Godot 4.7.2 headless) + GitHub Actions en cada PR
- [ ] Probar una tarea autónoma de punta a punta (sesión en la nube → PR → revisión desde el celular)

## M1 · El partido es divertido (borrador)
Preguntas a cerrar, cada una con playtest y medición:
- Largo de jugada: ¿3 fijas (D-12) o por arquetipo (I-07)?
- Kamikaze: ¿~22% de lesiones es aceptable o se vuelve al "hasta 15%"?
- Catenaccio: es el que menos marca (−15 en remates en LOW); ¿es su identidad o un problema?
- Contragolpe: su Intercepción deja a U. de Chile y UC por sobre Colo-Colo; ¿se ajusta?
- Sensación de juego mínima: ritmo de animaciones, feedback de acierto/fallo, lectura de la mano.

## Trabajo autónomo vs. juntos
- **Autónomo** (sesión en la nube, termina en PR): tareas con brief cerrado y verificables con
  pruebas o el simulador. Plantilla: `docs/tareas/_plantilla.md`.
- **Juntos:** decisiones de reglas, sensación de juego, prioridades, revisión de playtests.
