# Pilares de diseño

Cuatro frases que filtran toda idea y toda decisión. Si una propuesta no sirve a ningún pilar, va al
buzón (`ideas.md`) como "no encaja" o se descarta. Si choca con uno, gana el pilar salvo que se
cambie el pilar con una entrada en `decisiones.md`.

Versión 1 · 2026-10-26

## 1. Cada mano es una jugada de fútbol que se entiende
Las cartas se leen como fútbol (pase, desmarque, remate, presión), no como abstracciones. Una
jugada se arma en pasos y termina en un remate; elegir el orden y el momento es la decisión central.
- **Sí:** Momentos que piden construir la jugada, Aguantar el Balón para reorganizar, posesión que
  cambia la mano entre ataque y defensa.
- **No:** efectos que no tienen traducción futbolera ("roba 2 cartas" sin contexto), combos que
  solo funcionan por matemática.

## 2. Lo que ves es lo que se tira
El jugador nunca pierde por un número escondido. El % de cada carta es el que se tira, con su
desglose; el costo en PA y el desgaste de estamina están impresos y cambian de color si se alteran.
- **Sí:** `chance_breakdown` como única fuente, tooltips con el desglose, avisos de zona de estamina.
- **No:** modificadores ocultos en la tirada, penalizaciones que solo se ven en el resultado.

## 3. La semana pesa en el partido
Lo que haces fuera de la cancha (sponsor, evento social, entrenamiento, kinesiología, fichajes)
se siente en el partido siguiente, y lo que pasa en el partido vuelve a la semana (fatiga,
popularidad, presupuesto). Ninguna de las dos mitades es decorado.
- **Sí:** funa que encarece las cartas de un jugador, fatiga que define la estamina inicial.
- **No:** menús de gestión sin efecto en cancha, partidos que no dejan consecuencias.

## 4. Nostalgia chilena 2006, con humor
El Torneo Nacional 2006 visto con cariño y picardía: clubes, DT y planteles de la época, cultura
del fútbol chileno (bautizazos, funas, la prensa de farándula) y marcas siempre parodiadas.
- **Sí:** Cerveza Glaciar, Telnet, Diario El Chisme; eventos que un hincha de la época reconoce.
- **No:** marcas, diarios o canales reales; datos históricos inventados (sin fuente → `null`).
- Las mecánicas deben funcionar para alguien que nunca vio la liga chilena: la nostalgia atrae,
  el deckbuilding retiene.
