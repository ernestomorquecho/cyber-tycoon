extends Control
class_name Helpdesk
## Va sobre el nodo raíz "Tickets" de Escenas/Tickets.tscn.
##
## Pestañas (botones con los íconos del lado izquierdo):
##   Por hacer      -> solicitudes (esperando aceptar/rechazar) y tickets en proceso
##   Notificaciones -> avisos de lo que fue pasando; la burbuja azul del ícono
##                     (notificacion_sheet.png) cuenta los avisos sin leer
##   Completados    -> tickets ya resueltos

## Se emite al presionar CERRAR, justo antes de quitar la pantalla. El Dashboard
## puede escucharla para refrescar su encabezado o volver a poner el foco en él.
signal closed

enum Tab { TODO, NOTIFICATIONS, DONE }

const TicketCardScene: PackedScene = preload("res://Escenas/Tickets/TicketCard.tscn")
const NotificationRowScene: PackedScene = preload("res://Escenas/Tickets/NotificationRow.tscn")
# Solicitantes: cada avatar va con su nombre. "nombre" es la forma corta que se
# muestra en la descripción ("Arturo Ocampo - solicita ..."); "completo" queda
# disponible por si prefieren mostrar el nombre completo (ver USE_FULL_NAMES).
const REQUESTERS := [
	{"avatar": preload("res://Assets/Tickets/av1.png"), "nombre": "Georgina Salazar", "completo": "Georgina Salazar Partida"},
	{"avatar": preload("res://Assets/Tickets/av2.png"), "nombre": "Blanca Estrada", "completo": "Blanca Guadalupe Estrada Renteria"},
	{"avatar": preload("res://Assets/Tickets/av3.png"), "nombre": "Arturo Elias", "completo": "Arturo Elias Ramirez"},
	{"avatar": preload("res://Assets/Tickets/av4.png"), "nombre": "Arturo Ocampo", "completo": "Arturo Ocampo Silva"},
	{"avatar": preload("res://Assets/Tickets/av5.png"), "nombre": "Estela Muñoz", "completo": "Estela Lizbeth Muñoz Andrade"},
	{"avatar": preload("res://Assets/Tickets/av6.png"), "nombre": "Hector Gutiérrez", "completo": "Hector Andrés Gutiérrez Esparza"},
	{"avatar": preload("res://Assets/Tickets/av7.png"), "nombre": "Clelia Ruiz", "completo": "Clelia Ivette Ruiz Vertiz"},
	{"avatar": preload("res://Assets/Tickets/av8.png"), "nombre": "Luis Raygoza", "completo": "Luis Antonio Raygoza Pérez"},
	{"avatar": preload("res://Assets/Tickets/av9.png"), "nombre": "Guillermo Dominguez", "completo": "Guillermo Dominguez Aguilar"},
	{"avatar": preload("res://Assets/Tickets/av10.png"), "nombre": "Luis Bautista", "completo": "Luis Eduardo Bautista Villalpando"},
]
const USE_FULL_NAMES := true
# Si el título contiene alguna de estas palabras, el solicitante "detectó un
# incidente" en vez de "solicitar" un servicio.
const INCIDENT_WORDS := ["ataque", "ddos", "hackeo", "intrusi", "fuerza bruta", "malware", "ransomware", "phishing", "alerta"]
const NOTIF_SHEET: Texture2D = preload("res://Assets/Tickets/notificacion_sheet.png")
# Sprite sheet en una fila: frame 0 = sobre sin burbuja, 1..9 = número, 10 = "9+"
const NOTIF_FRAME_W := 168
const NOTIF_FRAME_H := 141

const CATALOGO_ENDPOINT := "/api/tienda/catalogo"

# --- Aparición de tickets ---
# Los tickets salen de UNO en UNO: un Timer con intervalo al azar entre
# SPAWN_INTERVAL_MIN_SECONDS y SPAWN_INTERVAL_MAX_SECONDS suelta el siguiente,
# siempre que la bandeja "Por hacer" tenga menos de MAX_ACTIVE_TICKETS
# (solicitudes sin responder + tickets aceptados en curso).
const MAX_ACTIVE_TICKETS := 5
const SPAWN_INTERVAL_MIN_SECONDS := 10.0
const SPAWN_INTERVAL_MAX_SECONDS := 30.0

# --- Generador de solicitudes (modo simulación, sin sesión/API) ---
const REQUESTER_COOLDOWN_SECONDS := 60.0   # espera global del solicitante tras completar/rechazar
const REQUEST_COOLDOWN_SECONDS := 600.0    # espera individual de la solicitud que acaba de resolverse

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

var _current_tab: Tab = Tab.TODO
var _unread: int = 0

var _scheduler: RequestScheduler
var _sim_ticket_counter: int = 0

var _spawn_timer: Timer
var _spawn_rng := RandomNumberGenerator.new()
var _spawning: bool = false
var _catalog_request: HTTPRequest

# Reputación con la que arranca el modo simulación (igual que
# Usuarios.reputacion DEFAULT 50 en el init.sql). Con la API conectada, el valor
# real vive en el backend y aquí solo queda un espejo del último que regresó.
const SIM_START_REPUTATION := 50

# En modo simulación ESTE número decide qué dificultades pueden pedir los
# clientes (ver RequestCatalog.unlocked_count).
var displayed_reputation: int = SIM_START_REPUTATION


func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	_todo_tab.pressed.connect(_show_tab.bind(Tab.TODO))
	_notifications_tab.pressed.connect(_show_tab.bind(Tab.NOTIFICATIONS))
	_done_tab.pressed.connect(_show_tab.bind(Tab.DONE))

	_spawn_rng.randomize()
	_spawn_timer = Timer.new()
	_spawn_timer.one_shot = true
	add_child(_spawn_timer)
	_spawn_timer.timeout.connect(_on_spawn_timer_timeout)

	_show_tab(Tab.TODO)
	_update_badge()
	_verify_store_catalog()
	_load_pending_tickets()


## CERRAR: avisa con la señal `closed` y quita la pantalla. Cuando se abre como
## ventana emergente del Dashboard, la libera y el Dashboard queda a la vista.
## Si se corrió suelta (Escena actual / F6), no hay Dashboard debajo y cierra el juego.
## OJO: al liberar la pantalla se pierden los tickets en curso y los cooldowns del
## modo simulación (con el backend real ese estado vive en el servidor).
func _on_close_pressed() -> void:
	closed.emit()
	if get_tree().current_scene == self:
		get_tree().quit()
	else:
		queue_free()


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


# --- Modo servidor: el backend genera, expira, reserva y entrega los tickets ---
# Cada POLL_SEGUNDOS se pide GET /api/tickets (vía GameData) y las tarjetas se
# sincronizan por id_ticket. Sin sesión (Tickets.tscn con F6) se usa la simulación.

const POLL_SEGUNDOS := 3.0
var _modo_servidor: bool = false
var _cards_por_id: Dictionary = {}  # id_ticket -> TicketCard en la bandeja "Por hacer"
var _primera_carga: bool = true
var _poll_timer: Timer


func _load_pending_tickets() -> void:
	if not GameData.hay_sesion():
		push_warning("[Helpdesk] Sin sesión activa, generando solicitudes en modo simulación")
		_start_simulation()
		return

	_modo_servidor = true
	GameData.tickets_recibidos.connect(_on_tickets_recibidos)
	_poll_timer = Timer.new()
	_poll_timer.wait_time = POLL_SEGUNDOS
	add_child(_poll_timer)
	_poll_timer.timeout.connect(GameData.solicitar_tickets)
	_poll_timer.start()
	GameData.solicitar_tickets()


func _on_tickets_recibidos(tablero: Dictionary) -> void:
	var activos: Array = tablero.get("activos", [])
	var recientes: Array = tablero.get("recientes", [])

	# 1) Tickets activos: crear los nuevos y ajustar cronómetros de los existentes
	var vistos := {}
	for fila in activos:
		if not fila is Dictionary:
			continue
		var id := int(fila.get("id_ticket", 0))
		vistos[id] = true
		var card = _cards_por_id.get(id)
		if card == null or not is_instance_valid(card):
			card = _spawn_ticket(_ticket_data_desde_json(fila))
			_cards_por_id[id] = card
			if not _primera_carga:
				_push_notification("Nueva solicitud: %s" % card.get_title())
		card.sincronizar(fila)

	# 2) Los que ya no están activos: el servidor los completó, falló, rechazó o expiró
	var finales := {}
	for fila in recientes:
		if fila is Dictionary:
			finales[int(fila.get("id_ticket", 0))] = str(fila.get("estado", ""))
	for id in _cards_por_id.keys():
		if vistos.has(id):
			continue
		var card = _cards_por_id[id]
		_cards_por_id.erase(id)
		if is_instance_valid(card) and not card.is_queued_for_deletion():
			_cerrar_desde_servidor(card, finales.get(id, ""))

	# 3) Al abrir la pantalla, la pestaña "Completados" muestra el historial reciente
	if _primera_carga:
		_primera_carga = false
		for fila in recientes:
			var estado_final := str(fila.get("estado", ""))
			if estado_final == "completado" or estado_final == "fallido":
				var card := _spawn_ticket(_ticket_data_desde_json(fila), _done_list, false)
				card.finalizar_desde_servidor(estado_final == "completado")


func _cerrar_desde_servidor(card: TicketCard, estado_final: String) -> void:
	match estado_final:
		"completado", "fallido":
			# Emite ticket_resolved -> _on_ticket_resolved la pasa a "Completados".
			card.finalizar_desde_servidor(estado_final == "completado")
		"expirado":
			_push_notification("Caducó sin respuesta: %s (-5 de reputación)" % card.get_title())
			card.queue_free()
		_:
			card.queue_free() # rechazado: ya se avisó al recibir la respuesta


func _ticket_data_desde_json(fila: Dictionary) -> TicketData:
	var data := TicketData.new()
	data.id_ticket = int(fila.get("id_ticket", 0))
	data.descripcion = str(fila.get("titulo", fila.get("descripcion", "")))
	data.titulo = data.descripcion
	data.dificultad = str(fila["dificultad"]) if fila.get("dificultad") != null else ""
	data.teraflops_requeridos = float(fila.get("teraflops_requeridos", 0))
	data.anchoDeBanda_requerido = float(fila.get("anchoDeBanda_requerido", 0))
	data.memoriaRequerida = float(fila.get("memoriaRequerida", 0))
	data.recompensa_creditos = float(fila.get("recompensa_creditos", 0))
	data.penalizacion_creditos = float(fila.get("penalizacion_creditos", 0))
	data.recompensa_reputacion = int(fila.get("recompensa_reputacion", 0))
	data.penalizacion_reputacion = int(fila.get("penalizacion_reputacion", 0))
	var requiere = fila.get("requiere", {})
	data.productos_requeridos = requiere if requiere is Dictionary else {}
	var decidir = fila.get("segundos_para_decidir")
	data.decision_time_seconds = float(decidir) if decidir != null else 0.1
	data.tiempo_para_completado = int(fila.get("tiempo_proceso_seg", 120))
	var solicitante = fila.get("solicitante")
	if solicitante != null:
		_assign_requester(data, posmod(int(solicitante), REQUESTERS.size()))
	# Los productos del diseño original se muestran como "equipo sugerido";
	# lo que de verdad se aparta al aceptar son los TFLOPS / RAM / ancho de banda.
	if not data.productos_requeridos.is_empty():
		var partes: Array = []
		for producto in data.productos_requeridos:
			partes.append("%d× %s" % [int(data.productos_requeridos[producto]), producto])
		data.detalle = "Equipo sugerido: " + ", ".join(partes)
	return data


func _spawn_ticket(data: TicketData, lista: VBoxContainer = null, conectar: bool = true) -> TicketCard:
	if data.icon == null or data.solicitante.is_empty():
		# Mismo ticket = mismo solicitante siempre (depende del id, no es aleatorio).
		_assign_requester(data, posmod(data.id_ticket - 1, REQUESTERS.size()))
	data.detalle = _compose_detail(data)

	var card: TicketCard = TicketCardScene.instantiate()
	(lista if lista != null else _todo_list).add_child(card)
	card.setup(data)

	if conectar:
		card.ticket_accepted.connect(_on_ticket_accepted.bind(card))
		card.ticket_rejected.connect(_on_ticket_rejected.bind(card))
		card.ticket_expired.connect(_on_ticket_expired.bind(card))
		card.ticket_resolved.connect(_on_ticket_resolved.bind(card))
	return card


func _assign_requester(data: TicketData, index: int) -> void:
	var requester: Dictionary = REQUESTERS[index]
	data.icon = requester["avatar"]
	data.solicitante = requester["completo"] if USE_FULL_NAMES else requester["nombre"]


## Arma el texto de la zona de descripción:
##   "Arturo Ocampo - solicita Hospedaje Web PYME"
##   "Blanca Estrada - detectó un incidente: Ataque DDoS"
## (y debajo el texto extra del ticket, si trae `detalle`).
func _compose_detail(data: TicketData) -> String:
	var title := data.titulo if not data.titulo.is_empty() else data.descripcion
	var lowered := title.to_lower()
	var is_incident := false
	for word in INCIDENT_WORDS:
		if lowered.contains(word):
			is_incident = true
			break
	var header := ""
	if is_incident:
		header = "%s - detectó un incidente: %s" % [data.solicitante, title]
	else:
		header = "%s - solicita %s" % [data.solicitante, title]
	return header if data.detalle.is_empty() else header + "\n" + data.detalle


func _on_ticket_accepted(id_ticket: int, _card: TicketCard) -> void:
	print("[Helpdesk] Ticket aceptado, procesando: ", id_ticket)


func _on_ticket_rejected(id_ticket: int, card: TicketCard) -> void:
	print("[Helpdesk] Ticket rechazado: ", id_ticket)
	if _modo_servidor:
		_cards_por_id.erase(id_ticket)
		displayed_reputation = GameData.reputacion # ya la descontó el servidor
	else:
		_change_reputation(-5)
	_release_requester(card, "rechazada")
	_push_notification("Rechazaste: %s (-5 de reputación)" % card.get_title())


func _on_ticket_expired(id_ticket: int, card: TicketCard) -> void:
	print("[Helpdesk] Ticket caducado (-20 reputación, SOLO VISUAL, falta endpoint real): ", id_ticket)
	_change_reputation(-20)
	# Una solicitud que caduca también libera al solicitante; si no, se quedaría
	# bloqueado para siempre (nadie la completará ni la rechazará).
	_release_requester(card, "caducada")
	_push_notification("Caducó sin respuesta: %s" % card.get_title())


func _on_ticket_resolved(id_ticket: int, exito: bool, creditos_actuales: float, reputacion_actual: float, card: TicketCard) -> void:
	print("[Helpdesk] Ticket %d resuelto. Éxito: %s | Créditos: %.0f | Reputación: %.0f" % [
		id_ticket, exito, creditos_actuales, reputacion_actual
	])
	var data := card.get_data()
	if data != null and data.requester_index >= 0:
		# Ticket del generador local (no hay servidor que decida): la reputación se
		# mueve aquí con los valores del propio ticket.
		_change_reputation(data.recompensa_reputacion if (exito and not card.finished_with_error) else -data.penalizacion_reputacion)
	else:
		# Ticket del servidor: créditos y reputación ya vienen aplicados en GameData
		# (el Dashboard se actualiza solo con GameData.estado_actualizado).
		displayed_reputation = GameData.reputacion

	_release_requester(card, "completada")
	card.reparent(_done_list)
	_done_list.move_child(card, 0)
	_push_notification("%s: %s" % [card.get_title(), card.result_text])


## Suma o resta reputación (nunca baja de 0) y avisa cuando se cruza un umbral
## que desbloquea (o vuelve a bloquear) solicitudes medias o difíciles.
func _change_reputation(delta: int) -> void:
	var before := RequestCatalog.unlocked_count(displayed_reputation)
	displayed_reputation = maxi(0, displayed_reputation + delta)
	var after := RequestCatalog.unlocked_count(displayed_reputation)
	print("[Reputacion] %+d -> %d (los clientes pueden pedir %d de %d solicitudes)" % [delta, displayed_reputation, after, RequestCatalog.CATALOG_SIZE])
	if after > before:
		_push_notification("¡Más prestigio! Los clientes ya piden solicitudes %s." % ("difíciles" if after == RequestCatalog.CATALOG_SIZE else "medias"))


# --- Modo simulación: solicitudes generadas por RequestScheduler ---

func _start_simulation() -> void:
	if _scheduler != null:
		return # ya está corriendo
	RequestCatalog.validate(REQUESTERS.size())
	_scheduler = RequestScheduler.new()
	_scheduler.setup(REQUESTERS.size(), RequestCatalog.CATALOG_SIZE, REQUESTER_COOLDOWN_SECONDS, REQUEST_COOLDOWN_SECONDS)
	_begin_spawning()


func _process(delta: float) -> void:
	if _scheduler != null:
		_scheduler.tick(delta)


# --- Ritmo de aparición: Timer aleatorio + tope en la bandeja ---

## Saca el primer ticket de inmediato (para que la bandeja no abra vacía) y
## arranca el Timer que soltará los demás de uno en uno.
func _begin_spawning() -> void:
	if _spawning:
		return
	_spawning = true
	_try_spawn_one()
	_schedule_next_spawn()


func _on_spawn_timer_timeout() -> void:
	_try_spawn_one()
	_schedule_next_spawn()


func _schedule_next_spawn() -> void:
	_spawn_timer.start(_next_spawn_interval())


func _next_spawn_interval() -> float:
	return _spawn_rng.randf_range(SPAWN_INTERVAL_MIN_SECONDS, SPAWN_INTERVAL_MAX_SECONDS)


## Tickets que hoy ocupan la bandeja "Por hacer" (no cuenta los ya completados
## ni los que se están borrando).
func _active_ticket_count() -> int:
	var count := 0
	for card in _todo_list.get_children():
		if not card.is_queued_for_deletion():
			count += 1
	return count


## Intenta sacar UN ticket. No hace nada si la bandeja ya está llena o si no hay
## nadie listo para pedir (cooldowns) / no quedan tickets de la API por mostrar.
func _try_spawn_one() -> bool:
	if _active_ticket_count() >= MAX_ACTIVE_TICKETS:
		return false
	if _scheduler != null:
		var pair := _scheduler.issue_one_ready(RequestCatalog.unlocked_count(displayed_reputation))
		if pair.x < 0:
			return false
		_spawn_simulated_ticket(pair.x, pair.y)
		return true
	return false


func _spawn_simulated_ticket(requester_index: int, request_index: int) -> void:
	_sim_ticket_counter += 1
	var data := RequestCatalog.make_ticket_data(requester_index, request_index)
	data.id_ticket = -_sim_ticket_counter # negativo: no existe en la base de datos
	_assign_requester(data, requester_index)
	print("[Solicitudes] %s pide #%d (%s) \"%s\" | reputación %d" % [data.solicitante, request_index + 1, data.dificultad, data.titulo, displayed_reputation])
	_spawn_ticket(data)


## Libera al solicitante de la solicitud que acaba de terminar e inicia sus cooldowns.
func _release_requester(card: TicketCard, motivo: String) -> void:
	var data := card.get_data()
	if _scheduler == null or data == null or data.requester_index < 0:
		return
	if _scheduler.release(data.requester_index, data.request_index):
		print("[Solicitudes] %s %s #%d \"%s\" -> solicitante en cooldown %ds, solicitud en cooldown %ds" % [
			data.solicitante, motivo, data.request_index + 1, data.titulo,
			int(REQUESTER_COOLDOWN_SECONDS), int(REQUEST_COOLDOWN_SECONDS)
		])


# --- Sincronía con el catálogo de la tienda ---
# Compara los 20 productos que piden los tickets (RequestCatalog.PRODUCTS) con lo
# que de verdad hay en Catalogo_Productos (GET /api/tienda/catalogo, ruta pública):
# que exista el nombre exacto, la misma categoría y el mismo espacio ("(2U)").
# Solo avisa en la consola; no bloquea nada.

func _verify_store_catalog() -> void:
	_catalog_request = HTTPRequest.new()
	_catalog_request.timeout = 5.0
	add_child(_catalog_request)
	_catalog_request.request_completed.connect(_on_store_catalog_received)
	var err := _catalog_request.request(Session.base_url + CATALOGO_ENDPOINT)
	if err != OK:
		print("[Catalogo] No se pudo pedir el catálogo de la tienda (error %d); se omite la verificación." % err)


func _on_store_catalog_received(result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if result != HTTPRequest.RESULT_SUCCESS or response_code != 200:
		print("[Catalogo] No se pudo verificar contra la tienda (servidor no disponible o error %d); se omite." % response_code)
		return
	var json = JSON.parse_string(body.get_string_from_utf8())
	if typeof(json) != TYPE_ARRAY:
		push_warning("[Catalogo] Respuesta inesperada de %s" % CATALOGO_ENDPOINT)
		return

	var store := {}
	for row in json:
		if typeof(row) == TYPE_DICTIONARY:
			store[str(row.get("nombreProducto", ""))] = row

	var problems := 0
	for nombre in RequestCatalog.PRODUCTS:
		var esperado: Dictionary = RequestCatalog.PRODUCTS[nombre]
		if not store.has(nombre):
			push_warning("[Catalogo] El producto de los tickets \"%s\" NO existe en la tienda (revisa que el nombre sea idéntico al de la base de datos)." % nombre)
			problems += 1
			continue
		var fila: Dictionary = store[nombre]
		if str(fila.get("categoria", "")) != esperado["categoria"]:
			push_warning("[Catalogo] \"%s\": la tienda lo tiene en la categoría \"%s\" y los tickets esperan \"%s\"." % [nombre, fila.get("categoria", ""), esperado["categoria"]])
			problems += 1
		var espacio = fila.get("espacioNecesario")
		if (typeof(espacio) == TYPE_INT or typeof(espacio) == TYPE_FLOAT) and int(espacio) != int(esperado["u"]):
			push_warning("[Catalogo] \"%s\": la tienda dice %dU de espacio y el nombre/los tickets dicen %dU." % [nombre, int(espacio), int(esperado["u"])])
			problems += 1

	if problems == 0:
		print("[Catalogo] OK: los %d productos que piden los tickets coinciden con la tienda." % RequestCatalog.PRODUCTS.size())
	else:
		push_warning("[Catalogo] %d diferencia(s) entre los tickets y la tienda; revisa los avisos de arriba." % problems)
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


func _on_close_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Escenas/Dashboard.tscn")
