extends Control
class_name Helpdesk
## Va sobre el nodo raíz "Tickets" de Escenas/Tickets.tscn.
##
## Pestañas (botones con los íconos del lado izquierdo):
##   Por hacer      -> solicitudes (esperando aceptar/rechazar) y tickets en proceso
##   Notificaciones -> avisos de lo que fue pasando; la burbuja azul del ícono
##                     (notificacion_sheet.png) cuenta los avisos sin leer
##   Completados    -> tickets ya resueltos

enum Tab { TODO, NOTIFICATIONS, DONE }

const TicketCardScene: PackedScene = preload("res://Escenas/Tickets/TicketCard.tscn")
const NotificationRowScene: PackedScene = preload("res://Escenas/Tickets/NotificationRow.tscn")
const AVATARS := [
	preload("res://Assets/Tickets/av2.png"),
	preload("res://Assets/Tickets/av3.png"),
]
const NOTIF_SHEET: Texture2D = preload("res://Assets/Tickets/notificacion_sheet.png")
# Sprite sheet en una fila: frame 0 = sobre sin burbuja, 1..9 = número, 10 = "9+"
const NOTIF_FRAME_W := 168
const NOTIF_FRAME_H := 141

const PENDIENTES_ENDPOINT := "/api/tickets/pendientes"
const TAB_ACTIVE := Color(1, 1, 1, 1)
const TAB_INACTIVE := Color(0.5, 0.5, 0.55, 1)

@onready var _scroll: ScrollContainer = %Scroll
@onready var _todo_list: VBoxContainer = %TodoList
@onready var _notifications_list: VBoxContainer = %NotificationsList
@onready var _done_list: VBoxContainer = %DoneList
@onready var _todo_tab: TextureButton = %TodoTab
@onready var _notifications_tab: TextureButton = %NotificationsTab
@onready var _done_tab: TextureButton = %DoneTab
@onready var _close_button: Button = %CloseButton
@onready var _fetch_request: HTTPRequest = $FetchRequest

var _current_tab: Tab = Tab.TODO
var _unread: int = 0

# Espejo local SOLO para mostrarlo en pantalla si hace falta. El valor real
# vive en Usuarios.reputacion en el backend.
var displayed_reputation: int = 100


func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	_todo_tab.pressed.connect(_show_tab.bind(Tab.TODO))
	_notifications_tab.pressed.connect(_show_tab.bind(Tab.NOTIFICATIONS))
	_done_tab.pressed.connect(_show_tab.bind(Tab.DONE))
	_fetch_request.request_completed.connect(_on_fetch_completed)

	_show_tab(Tab.TODO)
	_update_badge()
	_load_pending_tickets()


func _on_close_pressed() -> void:
	# TODO: normalmente esto oculta la pantalla y regresa al Dashboard.
	print("[Helpdesk] Cerrar presionado (falta conectar con el Dashboard)")


# --- Pestañas ---

func _show_tab(tab: Tab) -> void:
	_current_tab = tab
	_todo_list.visible = tab == Tab.TODO
	_notifications_list.visible = tab == Tab.NOTIFICATIONS
	_done_list.visible = tab == Tab.DONE

	_todo_tab.modulate = TAB_ACTIVE if tab == Tab.TODO else TAB_INACTIVE
	_done_tab.modulate = TAB_ACTIVE if tab == Tab.DONE else TAB_INACTIVE
	_scroll.scroll_vertical = 0

	if tab == Tab.NOTIFICATIONS:
		_unread = 0 # al abrir la pestaña, todo queda como leído
	_update_badge()


func _update_badge() -> void:
	var frame := 10 if _unread > 9 else _unread
	var atlas := AtlasTexture.new()
	atlas.atlas = NOTIF_SHEET
	atlas.region = Rect2(frame * NOTIF_FRAME_W, 0, NOTIF_FRAME_W, NOTIF_FRAME_H)
	_notifications_tab.texture_normal = atlas
	# Con avisos sin leer el ícono se queda a color para que la burbuja destaque.
	var highlighted := _current_tab == Tab.NOTIFICATIONS or _unread > 0
	_notifications_tab.modulate = TAB_ACTIVE if highlighted else TAB_INACTIVE


func _push_notification(text: String) -> void:
	var row := NotificationRowScene.instantiate()
	row.get_node("%Text").text = text
	_notifications_list.add_child(row)
	_notifications_list.move_child(row, 0) # lo más nuevo arriba
	if _current_tab != Tab.NOTIFICATIONS:
		_unread += 1
		_update_badge()


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
	data.titulo = data.descripcion
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
	# La tabla no trae un texto largo, así que el detalle se arma con las
	# recompensas y penalizaciones reales del ticket.
	data.detalle = "Recompensa: %s créditos y +%d de reputación.\nSi falla: -%s créditos y -%d de reputación." % [
		String.num(data.recompensa_creditos), data.recompensa_reputacion,
		String.num(data.penalizacion_creditos), data.penalizacion_reputacion
	]
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
	if data.icon == null:
		data.icon = AVATARS[absi(data.id_ticket) % AVATARS.size()]

	var card: TicketCard = TicketCardScene.instantiate()
	_todo_list.add_child(card)
	card.setup(data)

	card.ticket_accepted.connect(_on_ticket_accepted.bind(card))
	card.ticket_rejected.connect(_on_ticket_rejected.bind(card))
	card.ticket_expired.connect(_on_ticket_expired.bind(card))
	card.ticket_resolved.connect(_on_ticket_resolved.bind(card))


func _on_ticket_accepted(id_ticket: int, _card: TicketCard) -> void:
	print("[Helpdesk] Ticket aceptado, procesando: ", id_ticket)


func _on_ticket_rejected(id_ticket: int, card: TicketCard) -> void:
	print("[Helpdesk] Ticket rechazado (-5 reputación, SOLO VISUAL, falta endpoint real): ", id_ticket)
	displayed_reputation -= 5
	_push_notification("Rechazaste: %s" % card.get_title())


func _on_ticket_expired(id_ticket: int, card: TicketCard) -> void:
	print("[Helpdesk] Ticket caducado (-20 reputación, SOLO VISUAL, falta endpoint real): ", id_ticket)
	displayed_reputation -= 20
	_push_notification("Caducó sin respuesta: %s" % card.get_title())


func _on_ticket_resolved(id_ticket: int, exito: bool, creditos_actuales: float, reputacion_actual: float, card: TicketCard) -> void:
	print("[Helpdesk] Ticket %d resuelto. Éxito: %s | Créditos: %.0f | Reputación: %.0f" % [
		id_ticket, exito, creditos_actuales, reputacion_actual
	])
	if not card.finished_with_error:
		displayed_reputation = int(reputacion_actual)
	# TODO: esta pantalla no tiene su propio label de créditos/reputación;
	# lo normal es emitir esto hacia el Dashboard para refrescar su header
	# en cuanto exista esa conexión entre pantallas.

	card.reparent(_done_list)
	_done_list.move_child(card, 0)
	_push_notification("%s: %s" % [card.get_title(), card.result_text])


# --- Solo para probar el flujo mientras no hay sesión real ---

func _spawn_mock_tickets_for_testing() -> void:
	var ddos := TicketData.new()
	ddos.id_ticket = -1
	ddos.titulo = "Ataque DDoS"
	ddos.detalle = "Un pico de tráfico sospechoso está saturando el nodo 3. Mitígalo antes de que escale."
	ddos.teraflops_requeridos = 4.5
	ddos.anchoDeBanda_requerido = 100.0
	ddos.memoriaRequerida = 8.0
	ddos.decision_time_seconds = 25.0
	ddos.tiempo_para_completado = 20
	_spawn_ticket(ddos)

	var nomina := TicketData.new()
	nomina.id_ticket = -2
	nomina.titulo = "Procesar Nómina"
	nomina.detalle = "Cliente corporativo solicita el procesamiento por lotes de la nómina mensual."
	nomina.teraflops_requeridos = 2.0
	nomina.anchoDeBanda_requerido = 20.0
	nomina.memoriaRequerida = 4.0
	nomina.decision_time_seconds = 40.0
	nomina.tiempo_para_completado = 30
	_spawn_ticket(nomina)


func _on_close_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Escenas/Dashboard.tscn")
