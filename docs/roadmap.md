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
- [x] Repo privado en GitHub (`vKieferv/BONVALET`)
- [x] Versión Linux de la verificación (`check.sh`) + GitHub Actions en cada push y PR
- [x] Probar una tarea autónoma de punta a punta: T-01 (sesión en la nube → PR #1 → revisión → mezcla)

## M1 · El partido es divertido
Preguntas, medidas con `balance-lab` (`tests/lab/m1.json`) y decididas el 2026-10-26:
- [x] Largo de jugada → 3 para todos, 2 para Catenaccio (D-16). Tiki-Taka 3-4 en espera (I-09).
- [x] Kamikaze → lesión tardía ×2.5, ~15% (D-17).
- [x] Catenaccio marca poco → se resuelve con sus 2 jugadas (D-16).
- [x] Contragolpe sobre Colo-Colo → no se toca la Intercepción; jerarquía con el plantel, I-06 (D-18).
- [x] Guardado: cerrar a mitad de partido → se repite el partido (D-19).
- [ ] Sensación de juego: 5 playtests con `docs/playtests/_plantilla.md`, foco en: ¿entiendo por qué
      gané o perdí cada jugada?, ¿el ritmo de las animaciones cansa?, ¿sé cuándo mi mano puede armar
      un gol? (si no, I-32).

Tareas:
- [x] T-02 · aplicar D-16 y D-17 (autónoma, mezclada: 2.55 goles, 3.3% lesiones, Kamikaze 14.7%)
- [ ] Playtests 1-5 (usuario) → skill `playtest`; los arreglos que salgan, como tareas nuevas

## Trabajo autónomo vs. juntos
- **Autónomo** (sesión en la nube, termina en PR): tareas con brief cerrado y verificables con
  pruebas o el simulador. Plantilla: `docs/tareas/_plantilla.md`.
- **Juntos:** decisiones de reglas, sensación de juego, prioridades, revisión de playtests.
