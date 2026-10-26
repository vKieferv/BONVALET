---
name: idea-nueva
description: Analiza una idea nueva de diseño para Futbolista Deckbuilder (mecánica, carta, evento, cambio de reglas, contenido) contra los pilares, el GDD vivo y las decisiones tomadas, estima su impacto y la anota en docs/ideas.md SIN tocar código. Úsalo siempre que el usuario proponga algo nuevo o un cambio a algo ya decidido ("se me ocurrió", "qué tal si", "deberíamos agregar"), sobre todo a mitad de un sprint.
---

# idea-nueva

Objetivo: que ninguna idea se pierda y que ninguna entre al código sin pasar por el filtro. El
usuario itera rápido y muchas ideas contradicen otras ya implementadas; esta skill evita corregir
a cada rato.

## Pasos
1. **Entender la idea.** Reformúlala en una frase con términos del juego (Momento, PA, estamina,
   posesión, semana). Si es ambigua, pregunta solo lo indispensable.
2. **Buscar choques.** Lee `docs/pilares.md`, la sección correspondiente de `docs/gdd.md` y
   `docs/decisiones.md`. Señala:
   - qué pilar sirve (o ninguno);
   - qué decisión VIGENTE contradice (D-NN) o qué idea existente se parece (I-NN);
   - qué partes del código toca (revisa el código real; el GDD puede ir por delante).
3. **Responder las tres preguntas** de `docs/ideas.md`: pilar, problema que resuelve, cómo se mide
   (métrica de `godot-check -Balance` / `balance-lab`, o pregunta de playtest).
4. **Estimar:** tamaño (S/M/L), riesgo para el balance (¿mueve goles, lesiones, constructibilidad?) y
   el hito donde encaja según `docs/roadmap.md`.
5. **Anotar** una fila en `docs/ideas.md` con el siguiente I-NN libre y estado NUEVA (o EN ESPERA si
   choca con una decisión vigente). Si mejora o reemplaza una idea existente, edita esa fila.
6. **Recomendar** en el chat: aceptarla para un hito, dejarla en espera o descartarla, en 3-6 líneas.

## Reglas
- **No implementes** la idea en esta skill, aunque sea chica. Implementarla es una tarea aparte que
  el usuario aprueba (y que pasa a `docs/roadmap.md` o a `docs/tareas/`).
- Si el usuario insiste en cambiar algo del sprint en curso, explica qué se rompe del sprint y deja
  que decida; si decide cambiar, registra la decisión en `docs/decisiones.md`.
- Si la idea cambia una decisión VIGENTE, la entrada nueva la REEMPLAZA (no se borra la vieja).
- Marcas reales nunca (D-01); datos históricos solo con fuente (D-02).
