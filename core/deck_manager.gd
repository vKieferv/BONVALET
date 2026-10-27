class_name DeckManager
extends RefCounted

# Mazo unificado del partido: cartas de ataque y de defensa en las mismas pilas.
# La mano se filtra por posesión: al robar solo salen cartas de la fase actual
# (las penalizaciones salen en ambas, porque estorban siempre).

enum Possession { POSSESSION_ATTACK, POSSESSION_DEFENSE }

const DECK_MIN := 10   # el mazo estándar arranca con 12 (D-23) y crece hasta DECK_MAX
const DECK_MAX := 20

var active: Array = []       # mazo activo del partido
var sideboard: Array = []    # reserva
var draw_pile: Array = []
var hand: Array = []
var discard_pile: Array = []
var possession: Possession = Possession.POSSESSION_ATTACK
var rng: RandomNumberGenerator


func _init(p_active: Array, p_sideboard: Array, p_rng: RandomNumberGenerator) -> void:
	active = p_active
	sideboard = p_sideboard
	rng = p_rng


# "" si el mazo activo tiene un tamaño válido; si no, el mensaje de error.
func size_error() -> String:
	if active.size() < DECK_MIN or active.size() > DECK_MAX:
		return "El mazo tiene %d cartas; debe tener entre %d y %d." % [active.size(), DECK_MIN, DECK_MAX]
	return ""


static func fits_possession(card: Card, p: Possession) -> bool:
	if card.type == Card.Type.PENALTY:
		return true
	return card.is_defensive() == (p == Possession.POSSESSION_DEFENSE)


func start_match() -> void:
	draw_pile = active.duplicate()   # las cartas temporales nunca entran en `active`
	hand.clear()
	discard_pile.clear()
	possession = Possession.POSSESSION_ATTACK
	_shuffle(draw_pile)


# Cambia de fase. La mano anterior no sirve en la nueva fase y va al descarte.
func set_possession(p: Possession) -> void:
	possession = p
	discard_hand()


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


# Roba hasta n cartas de la fase actual. Las de la otra fase se quedan en la pila.
func draw(n: int) -> int:
	var drawn := 0
	for i in n:
		var idx := _next_fitting()
		if idx < 0 and _recycle_discard():
			idx = _next_fitting()
		if idx < 0:
			break
		hand.append(draw_pile.pop_at(idx))
		drawn += 1
	return drawn


# Índice de la carta de la fase actual más cercana al tope de la pila, o -1.
func _next_fitting() -> int:
	for i in range(draw_pile.size() - 1, -1, -1):
		if fits_possession(draw_pile[i], possession):
			return i
	return -1


# Baraja el descarte dentro de la pila de robo. false si no había nada que reciclar.
func _recycle_discard() -> bool:
	if discard_pile.is_empty():
		return false
	draw_pile.append_array(discard_pile)
	discard_pile.clear()
	_shuffle(draw_pile)
	return true


func discard_hand() -> void:
	discard_pile.append_array(hand)
	hand.clear()


func discard_from_hand(card: Card) -> void:
	var i := hand.find(card)
	if i >= 0:
		hand.remove_at(i)
		discard_pile.append(card)


func insert_into_draw(card: Card) -> void:
	draw_pile.insert(rng.randi_range(0, draw_pile.size()), card)


func insert_into_hand(card: Card) -> void:
	hand.append(card)


func reset_flow_uses() -> void:
	for pile in [draw_pile, hand, discard_pile]:
		for c in pile:
			c.flow_uses = 0


# --- Gestión fuera de partido ---

# Purga: quita una carta básica para subir la consistencia de robo.
func trim(card_id: String) -> bool:
	if active.size() <= DECK_MIN:
		return false
	for i in active.size():
		var c: Card = active[i]
		if c.id == card_id and c.type == Card.Type.BASIC:
			active.remove_at(i)
			return true
	return false


# Sideboard: intercambia una carta activa por una de reserva.
func swap_with_sideboard(active_idx: int, side_idx: int) -> void:
	var tmp = active[active_idx]
	active[active_idx] = sideboard[side_idx]
	sideboard[side_idx] = tmp
