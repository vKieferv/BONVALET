# Estudio de mercado · Futbolista Deckbuilder 2006

Investigación del 2026-10-27 para decidir posicionamiento, precio y manejo de nombres reales.
Complementa la sección 8 del GDD ("Comercial") y la idea I-20 (licencias).

> **Cómo leer este documento.** **Dato** = cifra publicada por la tienda, el estudio o un medio,
> con enlace. **Estimación** = cálculo de terceros (Gamalytic/VG Insights/Raijin, con ±30% de error
> según el propio Gamalytic) o mío, siempre marcado. **Límite de esta investigación:** desde el
> entorno en la nube solo funcionó el buscador web; no se pudo abrir Steam, SteamDB ni las reseñas
> directamente. Las cifras de Steam vienen de instantáneas indexadas de la tienda y de agregadores
> en distintas fechas (por eso a veces se da un rango). **Antes de decidir un precio o anunciar,
> hay que revisar las páginas en vivo.** Nada de lo que sigue es asesoría legal.

## Resumen ejecutivo

1. El nicho "deckbuilder de fútbol" **ya no está vacío**: NUTMEG! (marzo 2026, US$24,99, ~90% positivas en ~350-400 reseñas) y Goaldeck (agosto 2026, US$9,99) están a la venta, y Super Kickmen y Rogue Striker llegan entre fines de 2026 y 2027.
2. Ninguno tiene gestión semanal con consecuencias en el partido (pilar 3) ni un ancla latinoamericana. **Ese es el hueco**: "deckbuilder táctico + semana de DT + liga chilena 2006".
3. Los competidores venden poco. Estimaciones: NUTMEG ~4,5-9 mil copias, Clutchtime (básquetbol) ~12 mil. Un deckbuilder deportivo **no es un éxito asegurado** aunque el género sea el más rentable de Steam.
4. La crítica más repetida al género deportivo es **el azar que se siente injusto** ("pierdo el 90% de los partidos que debería ganar"). Nuestro pilar 2 (lo que ves es lo que se tira) es un argumento de venta, no solo una regla.
5. NUTMEG recibió críticas porque **simula 4 de cada 5 partidos**. Jugar siempre el partido con cartas nos diferencia.
6. El público hispanohablante en Steam es **~4,8%** de los usuarios (España 4,1% + Latinoamérica 0,75%, encuesta de septiembre 2026). La nostalgia chilena atrae, pero sola no sostiene un lanzamiento: **hace falta inglés**.
7. Precio sugerido: **US$14,99** (más que la mediana del género, US$9,99, y menos que NUTMEG), con el precio regional recomendado por Valve para Chile (CLP) y la región LATAM-USD.
8. Steam PC primero (con Steam Deck), demo **en Steam** para entrar a un Next Fest; itch.io solo para prototipos y devlog. Móvil después, si funciona.
9. Página de Steam al cerrar M4 (cuando haya GIFs y arte), pero **solo después de resolver los nombres** (I-20) con un abogado, porque la página ya es publicación.
10. Los tres riesgos: nombres e imagen de jugadores y clubes reales, un público doblemente de nicho (deporte + Chile 2006) y la sobreoferta de deckbuilders (224 en 2025, 316 a septiembre de 2026) con competidores de fútbol directos.

---

## 1. Competencia directa

### 1.1 Lanzados

| Juego | Estudio | Lanzamiento | Precio (US$) | Reseñas Steam | Nombres | Elogian | Critican |
|---|---|---|---|---|---|---|---|
| [NUTMEG! A Nostalgic Deckbuilding Football Manager](https://store.steampowered.com/app/3590560/NUTMEG_A_Nostalgic_Deckbuilding_Football_Manager/) | Sumo Digital Academy / Secret Mode (Reino Unido) | 26-03-2026 | 24,99 (salió con −40%) | **Dato:** "Muy positivas", 90% de 343 (otra instantánea: 400). Demo: 90% de 40. Metacritic 66, OpenCritic 75 (12 críticos) | Clubes ingleses y nombres de jugadores reales, sin rostros; descargo de "uso descriptivo", no licencia | Estética 80-90, álbum de láminas; mecánica de ratings ingeniosa; sin microtransacciones; "alternativa a Football Manager para quien no tiene tiempo" (Forbes, citado en la tienda) | Simula 4 de 5 partidos y el jugador se desconecta; poco profundo como deckbuilder; sistemas opacos; rachas "contra las probabilidades"; repetitivo; bugs |
| [Goaldeck](https://store.steampowered.com/app/4638590/Goaldeck/) | Pro Nobis Studio | 24-08-2026 | 9,99 | **Dato:** 91% de 12 (muy pocas para opinar) | "Leyendas" (no se pudo confirmar si con nombres reales) | Roguelike de 8 copas; cartas de DT; decisiones tipo *Reigns* para el ego de los jugadores; demo; español de España | Sin reseñas de prensa encontradas |
| [Clutchtime: Basketball Deckbuilder](https://store.steampowered.com/app/2995450/Clutchtime_Basketball_Deckbuilder/) (básquetbol, referente deportivo) | Bigosaur | 24-07-2025 | 19,99 (salió a 15,99) | **Dato:** 73-81% de 133-204 según la fecha ("Mayormente positivas") | No verificado | "Hace funcionar el básquetbol como deckbuilder" ([Steam Deck HQ](https://steamdeckhq.com/game-reviews/clutchtime-basketball-deckbuilder/)); modo Eliminación (roguelike) y Temporada clásica | Le falta profundidad, "nunca tan atrapante como los grandes del género", sonido repetitivo ([Loot Level Chill](https://lootlevelchill.com/?p=8078)) |
| [Football Drama](https://open-lab-games.itch.io/football-drama) | Open Lab Games + Demigiant (Italia) | 2019 (PC/móvil) | 9,99 (iOS 0,99) | % de Steam no encontrado; Metacritic 63; itch.io 4,0/5 (35) | DT ficticio (Rocco Galliano) | Temporada de **18 semanas** con narrativa, cartas tácticas en el partido y varios finales (incluido terminar preso) | "Muchas ideas, no cumple todas" ([Den of Geek](https://www.denofgeek.com/?p=386868)); recepción dividida |
| [Football, Tactics & Glory](https://store.steampowered.com/app/375530/Football_Tactics__Glory/) (por turnos, no deckbuilder) | Creoteam | PC ~2018 | 24,99 | **Dato:** "Muy positivas" (1,5-4,3 mil según la instantánea); recientes "Mixtas" | Ligas y equipos vía mods de la comunidad | Concepto original, profundidad táctica, "los goles se sienten" ([PlayStation Country](https://www.playstationcountry.com/football-tactics-and-glory/)) | Presentación pobre, UI torpe, **más suerte que estrategia**, progreso lento ([Xbox Tavern](https://www.xboxtavern.com/football-tactics-and-glory-review/)) |
| [Action Card Football](https://store.steampowered.com/app/848470/Action_Card_Football/) | Astral Pastimes | 18-01-2019 | 4,99 | **Dato:** 4 reseñas | — | — | Ejemplo de fútbol con cartas que nadie vio |

Fuentes de precios y reseñas de NUTMEG: [Steam](https://store.steampowered.com/app/3590560), [demo](https://store.steampowered.com/app/4018930/NUTMEG_A_Nostalgic_Deckbuilding_Football_Manager_Demo/), [Metacritic](https://www.metacritic.com/game/nutmeg-a-nostalgic-deckbuilding-football-manager/critic-reviews/), [OpenCritic](https://opencritic.com/game/20250/nutmeg-/reviews), [reseñas negativas en Steam](https://steamcommunity.com/app/3590560/negativereviews/?browsefilter=toprated), [Rogueliker](https://rogueliker.com/nutmeg-review/), [Thumb Culture (nombres reales sin rostros)](https://www.thumbculture.co.uk/nutmeg-a-nostalgic-deckbuilding-football-manager-pc-review), [VGC](https://www.videogameschronicle.com/news/nutmeg-is-a-deck-based-football-manager-game-based-on-80s-and-90s-sticker-albums), [Secret Mode](https://wearesecretmode.com/news/nutmeg-kicks-off-on-26-march-2026). Clutchtime: [SteamDB](https://steamdb.info/app/2995450/), [PCGamesN](https://www.pcgamesn.com/clutchtime/basketball-roguelike-deckbuilder). Football Drama: [DekuDeals](https://www.dekudeals.com/items/football-drama), [GameCritics](https://gamecritics.com/damiano-gerli/football-drama-review/). FT&G: [press kit](https://creoteam.com/football-tactics-glory-press-kit/).

**Ventas (estimaciones de terceros, ±30% o más):**
- NUTMEG: ~4,5 mil copias y ~US$112 mil brutos al 28-03-2026 ([Vaporlens](https://vaporlens.app/app/3590560/nutmeg_a_nostalgic_deckbuilding_football_manager/stats/details)); ~9,1 mil copias y ~US$137 mil al 22-07-2026, con un pico de 418 jugadores simultáneos ([Raijin](https://raijin.gg/app/3590560/NUTMEG_A_Nostalgic_Deckbuilding_Football_Manager)). Con un estudio grande detrás (Sumo) y prensa internacional.
- Clutchtime: ~12 mil copias, ~US$154 mil, pico de 198 jugadores ([SteamPulse/VGI](https://steampulse.org/game/2995450)).

### 1.2 Anunciados o en desarrollo

| Juego | Estudio | Estado | Qué es | Fuente |
|---|---|---|---|---|
| Super Kickmen | Reeecook Studio (Japón) / Crico | Demo en Steam desde el 09-09-2026; salida prevista para el 4T 2026 | Roguelike de mazo y fútbol por turnos en un tablero de 7×5, partidos de ~6 min, draft con presupuesto entre partidos; perder termina la partida | [Ludens Media](https://www.ludens.com.tw/super-kickmen-demo/) |
| [Rogue Striker](https://store.steampowered.com/app/4787010/Rogue_Striker/) | Zyg Studios (dev solo) | Lista de deseos desde junio de 2026; 1T 2027 según la tienda | Fútbol arcade + draft roguelite, estructura de Mundial (clasificatorias, grupos, eliminación) | [Game Developer](https://www.gamedeveloper.com/press-release/rogue-striker-announced-for-steam-a-soccer-roguelite-made-in-one-month-for-world-cup-season) |
| [Ole - Card Game](https://store.steampowered.com/app/1329210/Ole__Card_Game/) | Magitech Games | Sin fecha | Cartas de jugadores + formación; ambientación galáctica | Ficha de Steam (vía buscador) |
| [Match Deck: Football](https://store.steampowered.com/app/4589640/Match_Deck_Football/) | One Joyful Day | Prototipo | Mazo + combates contra IA por turnos | Ficha de Steam (vía buscador) |
| [5 Star Soccer](https://extramile.itch.io/5-star) | Extra Mile Studios | Prototipo web en itch.io (4 valoraciones) | Deckbuilder roguelite de fútbol retro | itch.io |
| [Retro Fútbol](https://store.steampowered.com/app/4783350/Retro_Futbol/) (no deckbuilder) | Laevum Games | 4T 2026 | Mánager de los 90 con 20 ligas de Europa y **Sudamérica** (temporada 1995-96) | Ficha de Steam (vía buscador) |
| [Walk-Off 199X](https://store.steampowered.com/app/4945620/) (béisbol) | — | Próximamente | Deckbuilder roguelike; cada partido empieza en la novena entrada | Ficha de Steam (vía buscador) |

**Móvil:** no apareció ningún deckbuilder de fútbol relevante en iOS/Android. Lo más cercano en tono
es [Retro Goal](https://apps.apple.com/app/id1535765855) de New Star Games (arcade + gestión ligera,
4,4/5 con ~28 mil valoraciones en App Store, gratis con modo ilimitado de pago desde 2023, sin
publicidad, según [New Star](https://www.newstargames.com/post/08-feb-2023-retro-goal-goes-free-to-play)).

### 1.3 Qué nos dice la competencia
- **Diferencias a favor:** ninguno combina partido jugado siempre con cartas + semana de DT con consecuencias + liga y época concretas en Latinoamérica. NUTMEG es lo más cercano en promesa ("nostalgia + deckbuilding + mánager") y sus críticas apuntan a lo que nuestros pilares 1-3 ya resuelven en el diseño.
- **Diferencias en contra:** NUTMEG y Goaldeck llegan antes, en inglés y con presentación terminada. Super Kickmen y Rogue Striker ocupan la versión "run corta" del fútbol roguelike.
- **Lo que repiten las reseñas:** (a) el azar que se siente injusto o es opaco; (b) poca profundidad del mazo; (c) repetición a mitad de temporada; (d) presentación y UI en los proyectos chicos.

---

## 2. Referentes del género

| Juego | Datos | Por qué funcionó (según fuentes) |
|---|---|---|
| **Slay the Spire** (Mega Crit) | Acceso anticipado a US$15,99 → 24,99 en 1.0. ~800 copias en los 3 primeros días; ~700 mil a abril de 2018; >1,5 millones en GDC 2019 ([Gamasutra](https://gamasutra.com/business/after-a-worrisome-start-i-slay-the-spire-i-has-sold-more-than-1-5-million-copies), [GamesBeat](https://gamesbeat.com/slay-the-spire-passes-1-5-million-copies-sold/)). Slay the Spire 2: acceso anticipado el 05-03-2026 a US$24,99, **3 millones en una semana** ([FullCleared](https://fullcleared.com/news/slay-the-spire-2-confirms-3m-sold-in-first-week/), [Shacknews](https://www.shacknews.com/article/147940/slay-the-spire-2-early-access-release-date)) | Intenciones del enemigo visibles (decisiones con información completa), partidas cortas con mapa de rutas, balance guiado por métricas ([GDC 2019](https://www.gamedeveloper.com/design/learn-i-slay-the-spire-i-s-metrics-driven-approach-to-game-balancing-at-gdc-2019)). Despegó por un streamer chino: China fue 30-43% de las ventas **antes de traducir el juego**; la lección del estudio fue localizar |
| **Balatro** (LocalThunk / Playstack) | US$14,99; ~97% positivas de ~160 mil reseñas ([GameGeeker](https://gamegeeker.com/games/balatro?market=US)). 5 millones de copias en enero de 2025 ([Shacknews](https://shacknews.com/article/142804/balatro-5-million-copies-sold?amphtml=1)) | Plan de marketing de Playstack: **demo** (>100 mil descargas en 3 meses), streamers ("la mejor forma de atraer gente es mostrar a otros jugando") y comunidad; picos en Next Fest, The Game Awards y la salida en móvil (sept. 2024) ([WN Hub](https://wnhub.io/news/investment/item-46849)). Regla base conocida por todos (póker) + combos que rompen el juego = muy "streameable" |
| **Monster Train** (Shiny Shoe) | US$24,99, mayo 2020, >1,5 millones ([Cosmocover](https://www.cosmocover.com/newsroom/monster-train-2-announced-for-2025-launch-on-pc-and-consoles-play-the-debut-demo-today-for-a-heavenly-successor-to-the-acclaimed-million-selling-hit)). Monster Train 2: 21-05-2025, US$24,99, Metascore 87 ([PCGamesN](https://www.pcgamesn.com/monster-train-2/release-date), [GG.deals](https://gg.deals/game/monster-train-2/)) | Una vuelta de tuerca espacial clara (tres pisos que defender) sobre la base de Slay the Spire, promoción cruzada con StS y modo competitivo (Hell Rush) |

**Mercado del género (dato agregado):** 224 juegos con la etiqueta *Roguelike Deckbuilder* salieron
en 2025 (143 en 2024, 83 en 2023) y 316 a septiembre de 2026. Del lote ene-2024/jun-2025, el 7,8%
llegó a 1000 reseñas (contra 4,2% de todo Steam); la mediana es de 52 reseñas y el precio de lista
mediano, **US$9,99** ([Steam Page Analyzer](https://www.steampageanalyzer.com/niches/roguelike-deckbuilder)).
Es el género que más vende en mediana ([Game World Observer, 2022](https://gameworldobserver.com/2022/04/22/roguelike-deckbuilders-beat-all-indie-genres-on-steam-in-terms-of-sales-but-only-99-such-titles-released-since-2019)),
pero la oferta se triplicó desde entonces.

**Qué elementos aplican a un deckbuilder de fútbol con semana de DT:**

| Elemento del bucle | En los referentes | Cómo aplica aquí | Estado en el juego |
|---|---|---|---|
| Información completa antes de decidir | Intenciones del enemigo (StS); puntaje visible (Balatro) | Pilar 2: % y desglose de cada carta, presión rival visible | Hecho (`chance_breakdown`) |
| Partida corta, "una más" | Run de 1-2 horas (StS), ciegas de minutos (Balatro) | Un partido son 4 Momentos; falta una partida corta que no sea la temporada completa | Falta (ver I-34) |
| El mazo crece y se rompe | Quitar/mejorar cartas, combos que escalan | Entrenamiento genera cartas, quitar y mejorar | **Falta: M2** (es la mayor brecha) |
| Vuelta de tuerca clara en una frase | "Póker roguelike", "StS con tres pisos" | "Cada mano es una jugada de fútbol que se arma en pasos" + la semana pesa en el partido | Diseñado |
| Mapa entre combates con decisiones | Rutas, eventos, tiendas | La semana: sponsor, evento social, entrenamiento, kinesiología | Hecho en mínimo |
| Se entiende mirando un stream | Reglas conocidas (póker) | Fútbol: todo el mundo sabe qué es un gol y una chilena | A favor |
| Localización temprana | StS creció en China antes de traducir | Inglés como mínimo para la demo | Falta (I-33) |

---

## 3. Nostalgia futbolera y mercado latinoamericano

### 3.1 Juegos que explotaron nostalgia o una liga concreta
- **Retro Bowl** (New Star Games): fútbol americano sin licencia NFL; usa nombres de ciudades en vez de equipos, sin jugadores reales. 7 millones de descargas y n.º 1 gratis en iOS EE. UU. según [PocketGamer.biz](https://www.pocketgamer.biz/news/77425/uk-based-new-star-games-takes-us-by-storm-with-retro-bowl/); "decenas de millones de jugadores sin licencia" según [Awful Announcing](https://awfulannouncing.com/gaming/while-ea-fights-over-nfl-licenses-retro-bowl-is-winning-football-gaming-without-one.html). Después salió una versión con licencia (NFL Retro Bowl '25, Apple Arcade). **Es la prueba más fuerte de que la nostalgia funciona sin nombres reales.**
- **NUTMEG!**: nostalgia del fútbol inglés de los 80-90 y los álbumes de láminas, con nombres reales (ver 1.1).
- **PES 6 y el "parche de la liga chilena"**: en Chile, PES 6 / Winning Eleven circuló con parches de la comunidad que agregaban la liga local, y la voz de Claudio Palma es parte del recuerdo ([En Cancha](https://www.encancha.cl/tecno-game/juegos/2021/7/21/pro-evolution-soccer-el-recuerdo-de-claudio-palma-siendo-la-voz-de-pes-en-chile-111623.html)). Konami licenció la liga chilena en PES 2017-2019 ([Konami](https://www.konami.com/games/eu/en/topics/13840/)). Hay parches equivalentes en Argentina, incluso de ligas provinciales ([Tiempo de San Juan](https://www.tiempodesanjuan.com/san-juan/el-sanjuanino-que-programo-un-mitico-pes-6-la-liga-sanjuanina-n373923)). **Dato cultural útil:** el público chileno de esa época ya está acostumbrado a "parchar" un juego para tener su liga.
- **La liga chilena falta en los juegos grandes:** EA la tuvo por última vez en FIFA 20 y no estuvo en FC 24 ([RedGol](https://redgol.cl/gamer/el-campeonato-chileno-fuera-de-fc-24-y-ultima-temporada-en-efootball-2024-20230712-RDG-56430.html)); para FC 26 las fuentes se contradicen ([Prensa Fútbol](https://www.prensafutbol.cl/felicidad-para-los-gamers-en-chile-la-liga-chilena-regresara-al-videojuego-de-ea-sports-fc-26/) dice que vuelve; un [hilo del foro de EA](https://forums.ea.com/discussions/fc-26-general-discussion-es/liga-chilena-en-eafc26/12375965) dice que no). **Estimación:** hay un hueco emocional ("mi liga no está en ningún juego") que sirve para prensa local.
- **Otros mánager retro en camino:** Retro Fútbol (ligas sudamericanas de 1995-96), PIX Football Manager ([Vandal](https://vandal.elespanol.com/noticia/1350786870/futbol-nostalgia-y-estrategia-un-juego-de-gestion-retro-llega-pronto-a-steam-y-se-llama-pix-football-manager/)), Retro Football Boss. La nostalgia futbolera es una tendencia, no un hallazgo exclusivo.

### 3.2 Tamaño del público hispanohablante en Steam
- **Dato:** encuesta de Steam de septiembre 2026: español de España 4,08%, español de Latinoamérica 0,75% ([Steam Hardware & Software Survey](https://store.steampowered.com/hwsurvey/Steam-Hardware-Software-Survey-Welcome-to-Steam)). En julio era 4,91% + 0,89%. Valve dio 4,6% de cuentas en español para 2024 en GDC 2025 (citado por [Quantumrun](https://www.quantumrun.com/consulting/steam-language-statistics/)). Muchos latinoamericanos usan "español de España" porque por años fue la única opción, así que la división entre los dos no mide países.
- **Dato antiguo:** Chile era ~1% de los usuarios de Steam en 2017-18 (Argentina 1,36%, Perú 0,77%, México 0,76%) según SteamSpy ([LevelUp Translation](https://www.leveluptranslation.com/single-post/what-languages-to-localize-your-steam-game-into)). Team17 contó en 2019 que Latinoamérica estaba entre sus cinco regiones principales en Steam, liderada por Brasil, México y Chile ([MCV](https://mcvuk.com/business-news/team17-brazil-is-ripe-for-indie-talent/)).
- **Estimación:** el público que reconoce la liga chilena 2006 es una fracción de ese ~5%. Sirve como núcleo de lanzamiento (prensa chilena, streamers, comunidad), no como mercado total. El pilar 4 ya lo dice: "la nostalgia atrae, el deckbuilding retiene".

### 3.3 Precios regionales para Chile y Latinoamérica
- **Dato:** desde el 20-11-2023 Valve pasó Argentina y varios países a la región **LATAM-USD** (Argentina, Bolivia, Ecuador, Paraguay, Venezuela, Centroamérica, etc.) con un precio recomendado en dólares menor que el de EE. UU. ([Steam Support](https://help.steampowered.com/faqs/view/2720-4EC7-B95A-1D2A), [80.lv](https://80.lv/articles/steam-rejects-argentine-peso-turkish-lira)). **Chile no está en esa lista** y sigue con precio en pesos (CLP), igual que México, Colombia, Perú, Uruguay y Brasil con su moneda ([Steam Page Analyzer](https://www.steampageanalyzer.com/blog/steam-regional-pricing-guide)).
- **Dato:** Valve actualizó su matriz de precios recomendados el 30-03-2026, por primera vez desde octubre de 2022 (misma fuente). El valor exacto en CLP aparece en Steamworks al poner el precio base; no se encontró publicado.
- **Estimación (solo orientativa):** con la referencia de un juego de US$5,99 a CLP 2800 ([SteamDB, 2020](https://steamdb.info/app/1021780/)), US$14,99 equivaldría a ~CLP 7000-7500 con la proporción antigua. Las tiendas de códigos chilenas convierten US$20 en ~CLP 18.500 ([ChileCodes](https://chilecodes.cl/categoria/codigos-steam-wallet/)), así que el precio regional recomendado queda bastante bajo el tipo de cambio. Hay que usar el número que dé Steamworks.

---

## 4. Licencias y nombres reales

> **Esto no es asesoría legal.** Es un resumen de prácticas y casos públicos para preparar la
> conversación con un abogado de propiedad intelectual con experiencia en Chile (y, si se vende
> fuera, en los países de venta). La decisión de I-20 debe tomarse con esa asesoría, **antes de
> abrir la página de Steam o publicar material con nombres**.

### 4.1 Prácticas comunes en juegos sin licencia
| Práctica | Ejemplo | Cómo funciona |
|---|---|---|
| Nombres ficticios + archivo editable por la comunidad | PES ("Man Red", "PM Black White") con *option files* ([PC Gamer](https://www.pcgamer.com/uk/pes-2020-option-file-pc-download), [GamesRadar](https://gamesradar.com/pes-2021-option-file)) | El juego trae nombres y escudos inventados; un editor permite renombrar y la comunidad comparte archivos con los reales. En consolas sin archivos externos, el jugador edita a mano |
| Ciudad o región en vez de marca de club | Retro Bowl (Philadelphia en vez de Eagles) | Evita marcas registradas de equipos; colores parecidos pero no iguales |
| Jugadores ficticios en equipos sin acuerdo | Football Manager con las selecciones de Alemania y Japón ([FM Scout](https://www.fmscout.com/q-20162-Unlock-Germany-and-Japan-national-teams-in-FM20.html)) | Donde no hay licencia, nombres falsos; la comunidad los "desbloquea" borrando un archivo |
| Nombres reales sin rostros y con descargo | NUTMEG! ([Sumo Digital](https://www.sumo-digital.com/our-work/nutmeg/)) | Usa nombres "de forma descriptiva" con un aviso de que nadie lo patrocina. **Es un descargo, no una licencia** |
| Nombres ficticios hasta licenciar | FIFA en los 90 ([Infobae](https://www.infobae.com/malditos-nerds/2026/06/15/de-fifa-94-a-ea-sports-fc-treinta-anos-de-futbol-en-pantalla/)) | El primer FIFA usó nombres de jugadores inventados; EA compró las licencias al año siguiente |
| Licencia colectiva vía sindicatos | FIFPRO para EA y otros | FIFPRO adquiere derechos de imagen por medio de sindicatos de unos 60 países y los licencia; en Chile, los seleccionados cedieron derechos de imagen al SIFUP ([El Dínamo](https://www.eldinamo.cl/deportes/2020/06/16/claudio-bravo-emplaza-al-sifup-en-medio-de-polemica-por-fondo-de-retiro-de-los-futbolistas/)) |

### 4.2 Riesgos y casos conocidos
- **Brasil, Football Manager:** exjugadores demandaron a SEGA por usar sus nombres y datos. SEGA alega que solo usa información pública y sin avatares; en 2021 el STJ suspendió todos esos procesos para unificar criterio. **FM no se vende en Brasil desde la edición 2017** ([Conjur](https://www.conjur.com.br/2021-dez-22/stj-suspende-processos-uso-imagem-jogadores-games//?print=1), [TecMundo](https://www.tecmundo.com.br/minha-serie/108861-triste-football-manager-2017-tem-venda-cancelada-brasil.htm)). **Es el antecedente más parecido a nuestro caso**: nombres reales sin rostro en un juego de gestión.
- **Brasil, EA:** los jugadores ganaron demandas contra EA por FIFA y EA dejó de incluir a jugadores brasileños desde FIFA 15 ([Sports Litigation Alert](https://sportslitigationalert.com/the-oswaldinato-problem-what-the-ea-sports-litigation-in-brazil-means-for-every-american-company-that-uses-the-image-of-a-brazilian-athlete/); la cifra de indemnización que circula no se pudo verificar).
- **Incluso con licencia colectiva hay roces:** en 2020 Ibrahimović y Bale cuestionaron que EA usara su imagen vía FIFPRO ([World IP Review](https://www.worldipreview.com/news/zlatan-ibrahimovic-rebukes-ea-sports-in-image-rights-row-20472)).
- **Chile, imagen de deportistas:** no hay una ley específica; los casos se han llevado como recurso de protección invocando el derecho de propiedad sobre la propia imagen (art. 19 n.º 24 de la Constitución). Hay un recurso de 2005 de futbolistas contra Panini por nombres e imágenes en láminas y otro de 2010 por publicidad ([JurisChile 2005](https://www.jurischile.com/2005/07/recurso-de-proteccin-uso-de-nombre-e.html), [JurisChile 2010](https://www.jurischile.com/2010/06/imagenes-de-deportistas-en-laminas-sin.html)); **no se pudo verificar el resultado**. En 2010 Salo demandó a Panini y al SIFUP por derechos de imagen de seleccionados ([DF](https://www.df.cl/empresas/salo-demanda-a-panini-y-a-sifup-por-utilizar-imagen-de-jugadores-de-la-seleccion)).
- **Chile, marcas de clubes:** Blanco y Negro defiende activamente "Colo-Colo" ante INAPI (ganó contra una radio, perdió contra un restaurante) ([Meganoticias](https://www.meganoticias.cl/nacional/492058-disputa-legal-entre-omar-garate-y-blanco-negro-registro-de-marca-inapi-pdp-14-07-2025.html), [DF](https://www.df.cl/empresas/industria/restaurant-plateadas-colo-colo-romeral-le-gana-el-gallito-a-blanco-y-negro)). Nombres, escudos y camisetas de clubes suelen ser marcas registradas, separadas de los derechos de los jugadores.
- **Steam:** Valve tiene un proceso de reclamos de propiedad intelectual (DMCA) que puede retirar una página (conocimiento general, sin un caso de fútbol encontrado). Un reclamo tras el lanzamiento puede bajarla justo cuando importa.

### 4.3 Lo que hay que preguntarle al abogado
1. ¿Puede la versión comercial usar nombres de clubes (sin escudos) y de DT/jugadores de 2006 (sin rostros) en Chile? ¿Y fuera de Chile?
2. ¿Cambia algo que sea un juego histórico (2006) y no la temporada actual?
3. Si el juego trae nombres ficticios y un editor, ¿es un riesgo distribuir o enlazar un archivo de datos con los nombres reales hecho por nosotros, o solo si lo hace la comunidad?
4. ¿Qué cubriría una licencia del SIFUP o de la ANFP, y cuánto cuesta en orden de magnitud?
5. ¿Las parodias de marcas (Cerveza Glaciar, Telnet, Diario El Chisme) tienen algún riesgo?

---

## 5. Recomendaciones

**Precio: US$14,99** (estimación razonada, no dato).
- La mediana del género es US$9,99 y Goaldeck salió a ese precio; NUTMEG (US$24,99) y Clutchtime (US$19,99 tras subir de 15,99) cobran más con estudios más grandes o más contenido.
- A US$14,99 cabe un descuento de lanzamiento del 10-15% y rebajas posteriores sin bajar de US$9.
- Si sale en acceso anticipado, US$11,99-12,99 y subir en 1.0, como hizo Slay the Spire.
- Para Chile y LATAM-USD, aceptar el precio recomendado de Valve en vez de inventar uno más bajo.

**Plataforma:** Steam en Windows primero, con Linux y Steam Deck (Godot exporta a ambos casi gratis y
el Deck favorece a los deckbuilders). itch.io sirve para prototipos y devlog con la comunidad,
**no para la demo principal**: Next Fest exige la demo en Steam. Móvil se estudia después del
lanzamiento; Balatro muestra que un port móvil puede relanzar ventas, pero no al inicio.

**Calendario (en hitos del roadmap, no en fechas):**
1. **Ahora → M3:** resolver I-20 con un abogado y dejar los textos traducibles (I-33). Devlog o clips en redes chilenas sin nombres sensibles, para probar el gancho.
2. **Al cerrar M4** (arte, GIFs y video): abrir la página de Steam con la versión de nombres que el abogado apruebe. Apuntar a 6-12 meses antes del lanzamiento: las listas de deseos muy tempranas convierten peor ([StraySpark](https://www.strayspark.studio/blog/steam-next-fest-october-2026-prep-timeline)).
3. **M5:** demo pública en Steam **2-3 meses antes** del Next Fest elegido, no el mismo día ([Unity, citando a Zukowski](https://unity.com/blog/steam-next-fest-developer-tips-unity)). Cada juego entra a un solo Next Fest: usar el último antes del lanzamiento (febrero, junio u octubre).
4. **Lanzamiento** cuando la lista de deseos se acerque a 5-10 mil, lo que hace falta para salir en "Populares próximos" según Zukowski ([WN Hub](https://wnhub.io/news/analytics/item-3827); después del lanzamiento, ~1000 reseñas el primer año para que Steam lo promueva, [80.lv](https://80.lv/articles/indie-game-should-have-1-000-reviews-to-get-promoted-by-steam)). La conversión mediana de lista de deseos a ventas en la primera semana es ~20% ([TechSpot / GameDiscoverCo](https://www.techspot.com/news/109938-steam-wishlists-have-little-impact-game-success-new.html)).

**Los 3 riesgos comerciales principales:**
1. **Nombres reales.** Un reclamo de jugadores, del SIFUP o de un club (con marcas que defienden activamente) puede bajar la página o el juego. Football Manager dejó de venderse en Brasil por algo parecido. *Mitigación:* I-20 con abogado antes de la página; diseñar para que el juego funcione completo con nombres ficticios.
2. **Público doblemente de nicho.** Deporte en Steam + Chile 2006 en un público hispanohablante de ~5%. NUTMEG, con Sumo detrás, vendería ~5-9 mil copias en meses (estimación). *Mitigación:* inglés desde la demo, gancho mecánico ("cada mano es una jugada") en el tráiler antes que la nostalgia, y prensa chilena como núcleo.
3. **Sobreoferta y competencia directa.** Más de 300 deckbuilders al año y al menos cuatro de fútbol entre 2026 y 2027. Las reseñas castigan el azar opaco, la poca profundidad del mazo y la presentación pobre, justo los riesgos de un desarrollador solo. *Mitigación:* M2 (construir el mazo) antes de mostrar, transparencia del azar como argumento de venta y la dirección de arte de I-30, sostenible para una persona.

---

## Qué cambia para el diseño

1. **El juego tiene que funcionar entero con nombres ficticios.** Como todo está en JSON, preparar un juego de datos "liga ficticia" (clubes con apodos o ciudades, jugadores generados) que pase todas las pruebas, y dejar los nombres reales como un paquete de datos separado y cambiable. Así cualquier respuesta del abogado sobre I-20 se resuelve cambiando datos, no código.
2. **Textos traducibles desde ahora (I-33).** Hoy los textos de UI están en el código en español. Pasarlos a tablas de traducción de Godot antes de M4 cuesta poco y retrasarlo cuesta mucho; la demo debería salir en inglés y español.
3. **Jugar siempre el partido y mostrar que el azar es justo (I-35).** La queja n.º 1 contra NUTMEG y Football, Tactics & Glory es perder "contra las probabilidades" sin entender por qué. Un resumen al final del partido con el % de cada jugada y "goles esperados vs. goles reales" convierte el pilar 2 en algo que se ve en reseñas y streams.
4. **Una partida corta además de la temporada (I-34).** Clutchtime (Eliminación), Goaldeck (8 copas), Rogue Striker y Super Kickmen ofrecen partidas de 30-60 minutos. Un modo Copa de 5-6 partidos con mazo que crece sirve de demo, de bucle "una más" para el público del género y de vitrina para streamers, sin tocar el modo carrera.
5. **M2 antes de mostrar el juego.** "Poco profundo como deckbuilder" es la crítica que más daña a la competencia. Ganar, quitar y mejorar cartas (I-01 a I-03) tiene que estar en la demo; un mazo que se arma solo no compite.
6. **Ritmo:** Super Kickmen apunta a partidos de ~6 minutos y las reseñas de NUTMEG mencionan repetición a mitad de temporada. Medir en los playtests de M1 cuánto dura un partido y una semana, y fijar una meta (por ejemplo, ≤10 min por partido).
