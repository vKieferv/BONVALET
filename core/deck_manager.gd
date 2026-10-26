class_name DeckManager
extends RefCounted

const MIN_DECK_SIZE := 15

var active: Array = []       # mazo activo del partido
var sideboard: Array = []    # reserva
var draw_pile: Array = []
var hand: Array = []
var discard_pile: Array = []
var rng: RandomNumberGenerator


func _init(p_active: Array, p_sideboard: Array, p_rng: RandomNumberGenerator) -> void:
	active = p_active
	sideboard = p_sideboard
	rng = p_rng


func start_match() -> void:
	draw_pile = active.duplicate()   # las cartas temporales nunca entran en `active`
	hand.clear()
	discard_pile.clear()
	_shuffle(draw_pile)


func _shuffle(arr: Array) -> void:
	for i in range(arr.size() - 1, 0, -1):
		var j := rng.randi_range(0, i)
		var tmp = arr[i]
		arr[i] = arr[j]
		arr[j] = tmp


func draw(n: int) -> int:
	var drawn := 0
	for i in n:
		if draw_pile.is_empty():
			if discard_pile.is_empty():
				break
			draw_pile = discard_pile.duplicate()
			discard_pile.clear()
			_shuffle(draw_pile)
		hand.append(draw_pile.pop_back())
		drawn += 1
	return drawn


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
	if active.size() <= MIN_DECK_SIZE:
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
