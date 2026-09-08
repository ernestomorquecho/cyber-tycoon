extends Control
class_name Helpdesk
## Va sobre el nodo raíz "Tickets" de Escenas/Tickets.tscn.

const TicketCardScene: PackedScene = preload("res://Escenas/Tickets/TicketCard.tscn")
const PENDIENTES_ENDPOINT := "/api/tickets/pendientes"

@onready var _ticket_list: Node = %TicketList
@onready var _close_button: Button = %CloseButton
@onready var _fetch_request: HTTPRequest = $FetchRequest

# Espejo local SOLO para mostrarlo en pantalla si hace falta. El valor real
# vive en Usuarios.reputacion en el backend.
var displayed_reputation: int = 100


func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	_fetch_request.request_completed.connect(_on_fetch_completed)
	_load_pending_tickets()


func _on_close_pressed() -> void:
	# TODO: normalmente esto oculta la pantalla y regresa al Dashboard.
	print("[Helpdesk] Cerrar presionado (falta conectar con el Dashboard)")


# --- Carga real desde la API, con fallback a datos de prueba ---

func _load_pending_tickets() -> void:
	if Session.jwt_token.is_empty():
		# TODO: sin Login.tscn todavía no hay JWT real que mandar. Mientras
		# tanto se usan tickets de prueba para poder seguir probando la UI.
		push_warning("[Helpdesk] Sin sesión activa, usando tickets de prueba")
		_spawn_mock_tickets_for_testing()
		return

	var url := Session.base_url + PENDIENTES_ENDPOINT
	_fetch_request.request(url, Session.auth_headers(), HTTPClient.METHOD_GET)


func _on_fetch_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		push_warning("[Helpdesk] Error %d al pedir /tickets/pendientes, usando datos de prueba" % response_code)
		_spawn_mock_tickets_for_testing()
		return

	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null or typeof(json) != TYPE_ARRAY:
		push_warning("[Helpdesk] Respuesta inesperada de /tickets/pendientes, usando datos de prueba")
		_spawn_mock_tickets_for_testing()
		return

	if json.is_empty():
		print("[Helpdesk] No hay tickets pendientes ahora mismo")

	for row in json:
		_spawn_ticket_from_json(row)


func _spawn_ticket_from_json(row: Dictionary) -> void:
	var data := TicketData.new()
	data.id_ticket = int(row.get("id_ticket", 0))
	data.descripcion = str(row.get("descripcion", ""))
	data.teraflops_requeridos = float(row.get("teraflops_requeridos", 0))
	data.anchoDeBanda_requerido = float(row.get("anchoDeBanda_requerido", 0))
	data.memoriaRequerida = float(row.get("memoriaRequerida", 0))
	data.recompensa_creditos = float(row.get("recompensa_creditos", 0))
	data.penalizacion_creditos = float(row.get("penalizacion_creditos", 0))
	data.recompensa_reputacion = int(row.get("recompensa_reputacion", 0))
	data.penalizacion_reputacion = int(row.get("penalizacion_reputacion", 0))
	data.fecha_limite = str(row.get("fecha_limite", ""))
	data.tiempo_para_completado = int(row.get("tiempoParaCompletado", 30))
	data.decision_time_seconds = _seconds_until(data.fecha_limite)
	_spawn_ticket(data)


func _seconds_until(fecha_limite_iso: String) -> float:
	if fecha_limite_iso.is_empty():
		return 15.0
	# Cálculo LOCAL solo para pintar el cronómetro; el servidor es quien de
	# verdad decide si seguía a tiempo cuando llegue /resolver.
	var limite_unix := Time.get_unix_time_from_datetime_string(fecha_limite_iso)
	var ahora_unix := Time.get_unix_time_from_system()
	return max(1.0, float(limite_unix - ahora_unix))


func _spawn_ticket(data: TicketData) -> void:
	var card: TicketCard = TicketCardScene.instantiate()
	_ticket_list.add_child(card)
	card.setup(data)

	card.ticket_accepted.connect(_on_ticket_accepted)
	card.ticket_rejected.connect(_on_ticket_rejected)
	card.ticket_expired.connect(_on_ticket_expired)
	card.ticket_resolved.connect(_on_ticket_resolved)


func _on_ticket_accepted(id_ticket: int) -> void:
	print("[Helpdesk] Ticket aceptado, procesando: ", id_ticket)


func _on_ticket_rejected(id_ticket: int) -> void:
	print("[Helpdesk] Ticket rechazado (-5 reputación, SOLO VISUAL, falta endpoint real): ", id_ticket)
	displayed_reputation -= 5


func _on_ticket_expired(id_ticket: int) -> void:
	print("[Helpdesk] Ticket caducado (-20 reputación, SOLO VISUAL, falta endpoint real): ", id_ticket)
	displayed_reputation -= 20


func _on_ticket_resolved(id_ticket: int, exito: bool, creditos_actuales: float, reputacion_actual: float) -> void:
	print("[Helpdesk] Ticket %d resuelto. Éxito: %s | Créditos: %.0f | Reputación: %.0f" % [
		id_ticket, exito, creditos_actuales, reputacion_actual
	])
	displayed_reputation = int(reputacion_actual)
	# TODO: esta pantalla no tiene su propio label de créditos/reputación;
	# lo normal es emitir esto hacia el Dashboard para refrescar su header
	# en cuanto exista esa conexión entre pantallas.


# --- Solo para probar el flujo mientras no hay sesión real ---

func _spawn_mock_tickets_for_testing() -> void:
	var ddos := TicketData.new()
	ddos.id_ticket = -1
	ddos.descripcion = "Ataque DDoS (ticket de prueba, sin sesión real)"
	ddos.teraflops_requeridos = 4.5
	ddos.anchoDeBanda_requerido = 100.0
	ddos.memoriaRequerida = 8.0
	ddos.recompensa_creditos = 150.0
	ddos.penalizacion_creditos = 50.0
	ddos.recompensa_reputacion = 15
	ddos.penalizacion_reputacion = 20
	ddos.decision_time_seconds = 15.0
	ddos.tiempo_para_completado = 20
	_spawn_ticket(ddos)

	var nomina := TicketData.new()
	nomina.id_ticket = -2
	nomina.descripcion = "Procesar Nómina (ticket de prueba, sin sesión real)"
	nomina.teraflops_requeridos = 2.0
	nomina.anchoDeBanda_requerido = 20.0
	nomina.memoriaRequerida = 4.0
	nomina.recompensa_creditos = 80.0
	nomina.penalizacion_creditos = 30.0
	nomina.recompensa_reputacion = 10
	nomina.penalizacion_reputacion = 15
	nomina.decision_time_seconds = 25.0
	nomina.tiempo_para_completado = 30
	_spawn_ticket(nomina)
