extends RefCounted
class_name RequestScheduler
## Decide CUÁNDO y QUÉ solicitud emite cada solicitante. No toca la interfaz:
## solo lleva el estado y las reglas, para poder probarlo aislado.
##
## Reglas:
##  1. Cada solicitante tiene un catálogo fijo de `catalog_size` (50) solicitudes.
##  2. Un solicitante solo puede tener UNA solicitud activa a la vez. No emite
##     otra hasta que la actual se libere con release() (completada, rechazada
##     o caducada).
##  3. Cooldown GLOBAL del solicitante: al liberar su solicitud no puede emitir
##     ninguna otra durante `requester_cooldown` segundos.
##  4. Cooldown INDIVIDUAL de la solicitud: la solicitud que se acaba de liberar
##     no puede volver a salir durante `request_cooldown` segundos.
##  5. Selección: índice al azar (0 a catalog_size-1). Si esa solicitud está en
##     cooldown, se prueba el índice siguiente (+1), luego el anterior (-1),
##     luego +2, -2... de forma circular (después del último sigue el primero)
##     hasta hallar una disponible. Si TODAS están en cooldown no se emite nada
##     y se reintenta en la siguiente revisión (nunca hay bucle infinito).
##
## El reloj interno avanza solo con tick(delta), así que se puede pausar o
## acelerar para pruebas.

var requester_count: int = 0
var catalog_size: int = 0
var requester_cooldown: float = 60.0
var request_cooldown: float = 600.0

var _now: float = 0.0
var _active: Array = []              # por solicitante: índice de su solicitud activa, o -1
var _requester_ready_at: Array = []  # por solicitante: instante en que termina su cooldown global
var _request_ready_at: Array = []    # por solicitante: Array con el fin del cooldown de cada solicitud
var _rng := RandomNumberGenerator.new()


func setup(p_requester_count: int, p_catalog_size: int, p_requester_cooldown: float, p_request_cooldown: float, p_seed: int = -1) -> void:
	requester_count = p_requester_count
	catalog_size = p_catalog_size
	requester_cooldown = p_requester_cooldown
	request_cooldown = p_request_cooldown
	_now = 0.0
	_active.clear()
	_requester_ready_at.clear()
	_request_ready_at.clear()
	for r in requester_count:
		_active.append(-1)
		_requester_ready_at.append(0.0)
		var row: Array = []
		row.resize(catalog_size)
		row.fill(0.0)
		_request_ready_at.append(row)
	if p_seed >= 0:
		_rng.seed = p_seed
	else:
		_rng.randomize()


func tick(delta: float) -> void:
	_now += delta


func now() -> float:
	return _now


## Retrasa la primera solicitud de un solicitante (para que no salgan todas juntas al arrancar).
func delay_requester(requester: int, seconds: float) -> void:
	_requester_ready_at[requester] = _now + seconds


func get_active_request(requester: int) -> int:
	return _active[requester]


func requester_cooldown_left(requester: int) -> float:
	return maxf(0.0, _requester_ready_at[requester] - _now)


func request_cooldown_left(requester: int, request: int) -> float:
	return maxf(0.0, _request_ready_at[requester][request] - _now)


## Regla 2 + 3: sin solicitud activa y fuera del cooldown global.
func is_requester_ready(requester: int) -> bool:
	return _active[requester] == -1 and _now >= _requester_ready_at[requester]


## Regla 4: la solicitud ya salió de su cooldown individual.
func is_request_available(requester: int, request: int) -> bool:
	return _now >= _request_ready_at[requester][request]


## Regla 5: elige al azar y, si está en cooldown, busca la más cercana disponible.
func pick_request(requester: int) -> int:
	return find_available(requester, _rng.randi_range(0, catalog_size - 1))


## Parte del índice `start` y regresa el primero disponible probando
## start, start+1, start-1, start+2, start-2... de forma circular.
## Regresa -1 si todas las solicitudes del solicitante están en cooldown.
func find_available(requester: int, start: int) -> int:
	if is_request_available(requester, start):
		return start
	for step in range(1, catalog_size):
		var forward := posmod(start + step, catalog_size)
		if is_request_available(requester, forward):
			return forward
		var backward := posmod(start - step, catalog_size)
		if is_request_available(requester, backward):
			return backward
	return -1


## Revisa a todos los solicitantes y emite una solicitud por cada uno que esté
## listo. Regresa una lista de Vector2i(solicitante, solicitud).
func issue_ready() -> Array:
	var issued: Array = []
	for r in requester_count:
		if not is_requester_ready(r):
			continue
		var request := pick_request(r)
		if request < 0:
			continue # todo el catálogo en cooldown: se reintenta en la próxima revisión
		_active[r] = request
		issued.append(Vector2i(r, request))
	return issued


## El jugador completó, rechazó (o la solicitud caducó). Libera al solicitante e
## inicia los dos cooldowns. Es idempotente: si ya estaba liberada, o `request`
## no es la solicitud activa de ese solicitante, no hace nada y regresa false
## (así una señal duplicada no reinicia los cooldowns).
func release(requester: int, request: int) -> bool:
	if requester < 0 or requester >= requester_count:
		return false
	if _active[requester] != request:
		return false
	_active[requester] = -1
	_requester_ready_at[requester] = _now + requester_cooldown
	_request_ready_at[requester][request] = _now + request_cooldown
	return true
