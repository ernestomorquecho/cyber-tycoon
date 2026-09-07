extends PanelContainer
class_name TicketCard
## Va sobre el nodo raíz de Escenas/Tickets/TicketCard.tscn.

signal ticket_accepted(id_ticket: int)
signal ticket_rejected(id_ticket: int)
signal ticket_expired(id_ticket: int)
signal ticket_resolved(id_ticket: int, exito: bool, creditos_actuales: float, reputacion_actual: float)

const RESOLVER_ENDPOINT := "/api/tickets/resolver"

var _data: TicketData
var _is_expanded: bool = false
var _is_processing: bool = false

@onready var _header_button: Button = %HeaderButton
@onready var _client_icon: TextureRect = %ClientIcon
@onready var _title_label: Label = %TitleLabel
@onready var _decision_time_label: Label = %DecisionTimeLabel

@onready var _expanded_content: VBoxContainer = %ExpandedContent
@onready var _description_label: Label = %DescriptionLabel
@onready var _requirements_label: Label = %RequirementsLabel
@onready var _process_time_label: Label = %ProcessTimeLabel
@onready var _accept_button: Button = %AcceptButton
@onready var _reject_button: Button = %RejectButton

@onready var _decision_timer: Timer = $DecisionTimer
@onready var _process_timer: Timer = $ProcessTimer
@onready var _resolve_request: HTTPRequest = $ResolveRequest


func _ready() -> void:
	_header_button.pressed.connect(_on_header_pressed)
	_accept_button.pressed.connect(_on_accept_pressed)
	_reject_button.pressed.connect(_on_reject_pressed)
	_decision_timer.timeout.connect(_on_decision_timer_timeout)
	_process_timer.timeout.connect(_on_process_timer_timeout)
	_resolve_request.request_completed.connect(_on_resolve_completed)

	_expanded_content.visible = false
	_process_time_label.visible = false
	custom_minimum_size.y = 60


func setup(data: TicketData) -> void:
	_data = data
	_title_label.text = data.descripcion
	if data.icon:
		_client_icon.texture = data.icon

	_description_label.text = data.descripcion
	_requirements_label.text = "Requiere: %.1f TF / %.0f Mbps / %.0f MB" % [
		data.teraflops_requeridos, data.anchoDeBanda_requerido, data.memoriaRequerida
	]

	_decision_timer.start(data.decision_time_seconds)


func _process(_delta: float) -> void:
	if not _is_processing and _decision_timer.time_left > 0.0:
		_decision_time_label.text = _format_time(_decision_timer.time_left)
	elif _is_processing and _process_timer.time_left > 0.0:
		_process_time_label.text = "Procesando: %s" % _format_time(_process_timer.time_left)


func _format_time(seconds: float) -> String:
	var total := int(ceil(seconds))
	var m := total / 60
	var s := total % 60
	return "%02d:%02d" % [m, s]


# --- Acordeón ---

func _on_header_pressed() -> void:
	if _is_processing:
		return
	_is_expanded = not _is_expanded
	_expanded_content.visible = _is_expanded
	custom_minimum_size.y = 220 if _is_expanded else 60


# --- Botones ---

func _on_accept_pressed() -> void:
	_set_buttons_enabled(false)
	_is_processing = true
	_is_expanded = true
	_expanded_content.visible = true
	_process_time_label.visible = true
	custom_minimum_size.y = 220
	_header_button.disabled = true
	_decision_timer.stop()
	_process_timer.start(_data.tiempo_para_completado)
	ticket_accepted.emit(_data.id_ticket)


func _on_reject_pressed() -> void:
	_set_buttons_enabled(false)
	_decision_timer.stop()
	# TODO: el backend todavía NO tiene un endpoint de "rechazar" (solo existe
	# /api/tickets/resolver, que siempre evalúa capacidad). La penalización de
	# -5 reputación de la spec no se está aplicando de verdad todavía; hace
	# falta pedir al equipo de backend algo como
	# POST /api/tickets/descartar { id_ticket }.
	ticket_rejected.emit(_data.id_ticket)
	queue_free()


func _set_buttons_enabled(enabled: bool) -> void:
	_accept_button.disabled = not enabled
	_reject_button.disabled = not enabled


# --- Cronómetros ---

func _on_decision_timer_timeout() -> void:
	_set_buttons_enabled(false)
	# TODO: mismo caso que el rechazo, no existe todavía un endpoint de
	# "caducó" que aplique los -20 de reputación de la spec en el servidor.
	ticket_expired.emit(_data.id_ticket)
	queue_free()


func _on_process_timer_timeout() -> void:
	# Aquí es cuando de verdad se le pregunta al servidor si tenías
	# capacidad suficiente. Antes de esto, nada se da por hecho.
	if Session.jwt_token.is_empty():
		push_warning("[TicketCard] Sin sesión activa (falta Login.tscn), no se puede resolver el ticket %d" % _data.id_ticket)
		queue_free()
		return

	var url := Session.base_url + RESOLVER_ENDPOINT
	var body := JSON.stringify({"id_ticket": _data.id_ticket})
	_resolve_request.request(url, Session.auth_headers(), HTTPClient.METHOD_POST, body)


func _on_resolve_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		push_warning("[TicketCard] Error %d al resolver el ticket %d" % [response_code, _data.id_ticket])
		queue_free()
		return

	var json = JSON.parse_string(body.get_string_from_utf8())
	if json == null:
		push_warning("[TicketCard] Respuesta inválida al resolver el ticket %d" % _data.id_ticket)
		queue_free()
		return

	ticket_resolved.emit(
		_data.id_ticket,
		bool(json.get("exito", false)),
		float(json.get("creditosActuales", 0.0)),
		float(json.get("reputacionActual", 0.0))
	)
	queue_free()
