extends Control
class_name TicketCard
## Va sobre el nodo raíz de Escenas/Tickets/TicketCard.tscn.
## Una misma tarjeta con dos "caras":
##   - Collapsed -> ticketSoli.png  (ícono de correo + título + tiempo)
##   - Expanded  -> ticketConte.png (avatar, título, tiempo, descripción,
##                                   requisitos, cronómetro de proceso y botones)
## Un clic en el encabezado alterna entre las dos (acordeón).
##
## Dos modos:
##   - SERVIDOR (ticket con id > 0 y sesión activa): aceptar/rechazar se piden a
##     POST /api/tickets/:id/aceptar|rechazar; los cronómetros solo se pintan, el
##     servidor es quien expira y entrega. Helpdesk sincroniza con sincronizar()
##     y finalizar_desde_servidor().
##   - SIMULACIÓN (sin sesión, p. ej. Tickets.tscn con F6): todo es local.

signal ticket_accepted(id_ticket: int)
signal ticket_rejected(id_ticket: int)
signal ticket_expired(id_ticket: int)
signal ticket_resolved(id_ticket: int, exito: bool, creditos_actuales: float, reputacion_actual: float)

## REQUEST     = solicitud esperando que el jugador acepte o rechace
## IN_PROGRESS = aceptada, corriendo el cronómetro de proceso
## DONE        = ya resuelta (éxito o fallo)
enum State { REQUEST, IN_PROGRESS, DONE }

const COLLAPSED_HEIGHT := 130.0 # alto de ticketSoli.png
const EXPANDED_HEIGHT := 290.0  # alto de ticketConte.png (mínimo de la tarjeta abierta)
# Alto que cabe en la descripción sin mover nada (2 renglones). Si el texto
# necesita más, la tarjeta crece y lo de abajo se recorre (ver _ajustar_alto).
const ALTO_DESCRIPCION_BASE := 46.0
const URGENT_SECONDS := 5.0
const DESFASE_TOLERADO := 2.0   # segundos de diferencia con el servidor antes de corregir el reloj

const COLOR_NORMAL := Color(0.89, 0.93, 0.97)
const COLOR_DIM := Color(0.55, 0.62, 0.7)
const COLOR_URGENT := Color(1.0, 0.35, 0.35)
const COLOR_OK := Color(0.3, 0.9, 0.45)
const COLOR_FAIL := Color(1.0, 0.4, 0.4)

var state: State = State.REQUEST
var result_text: String = ""          # "RESUELTO" o "FALLIDO"
var finished_with_error: bool = false

var _data: TicketData
var _is_expanded: bool = false
var _esperando: bool = false # hay una petición al servidor en curso
var _alto_extra: float = 0.0
var _posiciones_base: Dictionary = {} # nodo -> [offset_top, offset_bottom] originales

@onready var _collapsed: NinePatchRect = %Collapsed
@onready var _expanded: NinePatchRect = %Expanded

@onready var _c_title: Label = %CollapsedTitle
@onready var _c_time: Label = %CollapsedTime
@onready var _c_toggle: TextureButton = %CollapsedToggle

@onready var _avatar: TextureRect = %Avatar
@onready var _e_title: Label = %ExpandedTitle
@onready var _e_time: Label = %ExpandedTime
@onready var _e_toggle: TextureButton = %ExpandedToggle
@onready var _description_label: Label = %DescriptionLabel
@onready var _requirements_label: Label = %RequirementsLabel
@onready var _reward_money: Label = %RewardMoney
@onready var _reward_rep: Label = %RewardRep
@onready var _penalty_money: Label = %PenaltyMoney
@onready var _penalty_rep: Label = %PenaltyRep
@onready var _process_label: Label = %ProcessLabel
@onready var _accept_button: TextureButton = %AcceptButton
@onready var _reject_button: TextureButton = %RejectButton

@onready var _decision_timer: Timer = $DecisionTimer
@onready var _process_timer: Timer = $ProcessTimer


func _ready() -> void:
	_c_toggle.pressed.connect(_toggle_expanded)
	_e_toggle.pressed.connect(_toggle_expanded)
	_accept_button.pressed.connect(_on_accept_pressed)
	_reject_button.pressed.connect(_on_reject_pressed)
	_decision_timer.timeout.connect(_on_decision_timer_timeout)
	_process_timer.timeout.connect(_on_process_timer_timeout)
	GameData.ticket_respuesta.connect(_on_ticket_respuesta)

	_process_label.visible = false
	# Lo que va debajo de la descripción se recorre si esta necesita más renglones.
	for nodo in [_description_label, get_node("Expanded/RewardRow"), get_node("Expanded/PenaltyRow"),
			_requirements_label, _process_label, _accept_button, _reject_button]:
		_posiciones_base[nodo] = [nodo.offset_top, nodo.offset_bottom]
	_description_label.resized.connect(_ajustar_alto)
	_set_expanded(false)


func setup(data: TicketData) -> void:
	_data = data
	var title := data.titulo if not data.titulo.is_empty() else data.descripcion
	var detail := data.detalle if not data.detalle.is_empty() else data.descripcion

	_c_title.text = title
	_e_title.text = title
	_description_label.text = detail
	_requirements_label.text = _requirements_text(data)
	# Junto a cada cantidad va su ícono (money.png / repu.png), puestos en la escena.
	_reward_money.text = "+" + TicketData.fmt_num(data.recompensa_creditos)
	_reward_rep.text = "+" + TicketData.fmt_num(float(data.recompensa_reputacion))
	_penalty_money.text = "-" + TicketData.fmt_num(data.penalizacion_creditos)
	_penalty_rep.text = "-" + TicketData.fmt_num(float(data.penalizacion_reputacion))
	if data.icon:
		_avatar.texture = data.icon

	_decision_timer.start(maxf(0.1, data.decision_time_seconds))
	_update_labels()
	_ajustar_alto.call_deferred()


func _modo_servidor() -> bool:
	return _data != null and _data.id_ticket > 0 and GameData.hay_sesion()


## Servidor: la capacidad que se APARTA al aceptar (TFLOPS / RAM / ancho de banda).
## Simulación: "Requiere: 2× Lenorvo OverThink SR650 (2U), 1× ...".
func _requirements_text(data: TicketData) -> String:
	if data.id_ticket > 0 or data.productos_requeridos.is_empty():
		return "Requiere:  %s TFLOPS   |   %s GB RAM   |   %s ancho de banda" % [
			TicketData.fmt_num(data.teraflops_requeridos),
			TicketData.fmt_num(data.memoriaRequerida),
			TicketData.fmt_num(data.anchoDeBanda_requerido)
		]
	var parts: Array = []
	for producto in data.productos_requeridos:
		parts.append("%d× %s" % [int(data.productos_requeridos[producto]), producto])
	return "Requiere:  " + ",  ".join(parts)


func get_title() -> String:
	return _c_title.text


func get_data() -> TicketData:
	return _data


func _process(_delta: float) -> void:
	_update_labels()


func _format_time(seconds: float) -> String:
	var total := int(ceil(seconds))
	return "%02d:%02d" % [int(total / 60.0), total % 60]


func _update_labels() -> void:
	if _data == null:
		return
	match state:
		State.REQUEST:
			var left := _decision_timer.time_left
			var color := COLOR_URGENT if left <= URGENT_SECONDS else COLOR_NORMAL
			_set_time_labels(_format_time(left), color, _format_time(left), color)
		State.IN_PROGRESS:
			var txt := _format_time(_process_timer.time_left)
			_set_time_labels(txt, COLOR_NORMAL, "--:--", COLOR_DIM)
			if not _process_timer.is_stopped():
				_process_label.text = "Entregar en: " + txt
		State.DONE:
			pass # el texto final se fija una sola vez en _finish()


func _set_time_labels(c_text: String, c_color: Color, e_text: String, e_color: Color) -> void:
	_c_time.text = c_text
	_c_time.add_theme_color_override("font_color", c_color)
	_e_time.text = e_text
	_e_time.add_theme_color_override("font_color", e_color)


# --- Acordeón ---

func _toggle_expanded() -> void:
	_set_expanded(not _is_expanded)


func _set_expanded(value: bool) -> void:
	_is_expanded = value
	_collapsed.visible = not value
	_expanded.visible = value
	custom_minimum_size.y = EXPANDED_HEIGHT + _alto_extra if value else COLLAPSED_HEIGHT
	if value:
		_ajustar_alto.call_deferred()


## Si la descripción no cabe en 2 renglones, la tarjeta abierta crece lo necesario
## y las filas de recompensa, requisitos y botones se recorren hacia abajo. El
## fondo (ticketConte.png) solo estira la franja lisa entre el avatar y la línea
## de "Requiere" (patch_margin_top/bottom en TicketCard.tscn).
func _ajustar_alto() -> void:
	if _description_label.size.x <= 0.0:
		return
	var renglones := _description_label.get_line_count()
	var interlineado := float(_description_label.get_theme_constant("line_spacing"))
	var alto_texto := renglones * (_description_label.get_line_height() + interlineado)
	var extra := maxf(0.0, ceilf(alto_texto - ALTO_DESCRIPCION_BASE))
	if is_equal_approx(extra, _alto_extra):
		return
	_alto_extra = extra
	for nodo in _posiciones_base:
		var base: Array = _posiciones_base[nodo]
		if nodo == _description_label:
			nodo.offset_bottom = base[1] + extra # la descripción crece; su parte de arriba no se mueve
		else:
			nodo.offset_top = base[0] + extra
			nodo.offset_bottom = base[1] + extra
	if _is_expanded:
		custom_minimum_size.y = EXPANDED_HEIGHT + _alto_extra


# --- Botones ---

func _on_accept_pressed() -> void:
	if state != State.REQUEST or _esperando:
		return
	if _modo_servidor():
		_set_esperando(true)
		GameData.aceptar_ticket(_data.id_ticket)
		return
	_iniciar_proceso(float(_data.tiempo_para_completado))
	ticket_accepted.emit(_data.id_ticket)


func _on_reject_pressed() -> void:
	if state != State.REQUEST or _esperando:
		return
	if _modo_servidor():
		_set_esperando(true)
		GameData.rechazar_ticket(_data.id_ticket)
		return
	_decision_timer.stop()
	ticket_rejected.emit(_data.id_ticket)
	queue_free()


## Respuesta del servidor a aceptar / rechazar ESTA tarjeta.
func _on_ticket_respuesta(id_ticket: int, accion: String, exito: bool, mensaje: String, ticket: Dictionary) -> void:
	if _data == null or id_ticket != _data.id_ticket:
		return
	_set_esperando(false)
	if not exito:
		# p. ej. INSUFFICIENT_RESOURCES: la tarjeta se queda como solicitud y explica por qué.
		_mostrar_aviso(mensaje)
		return
	if accion == "aceptar":
		_iniciar_proceso(float(ticket.get("segundos_para_entregar", _data.tiempo_para_completado)))
		ticket_accepted.emit(_data.id_ticket)
	else:
		_decision_timer.stop()
		ticket_rejected.emit(_data.id_ticket)
		queue_free()


func _set_esperando(valor: bool) -> void:
	_esperando = valor
	_accept_button.disabled = valor or state != State.REQUEST
	_reject_button.disabled = valor or state != State.REQUEST


func _mostrar_aviso(texto: String) -> void:
	_process_label.text = texto
	_process_label.add_theme_color_override("font_color", COLOR_FAIL)
	_process_label.visible = true
	_set_expanded(true)


func _iniciar_proceso(segundos: float) -> void:
	state = State.IN_PROGRESS
	_decision_timer.stop()
	_process_timer.start(maxf(0.1, segundos))
	_process_label.remove_theme_color_override("font_color")
	_process_label.visible = true
	_refresh_buttons()


func _refresh_buttons() -> void:
	var can_decide := state == State.REQUEST and not _esperando
	_accept_button.disabled = not can_decide
	_reject_button.disabled = not can_decide
	# Ya resuelto: los botones dejan de tener sentido.
	_accept_button.visible = state != State.DONE
	_reject_button.visible = state != State.DONE


# --- Sincronía con el servidor (la llama Helpdesk en cada consulta) ---

## Ajusta estado y cronómetros a lo que dice el servidor para este ticket activo.
func sincronizar(fila: Dictionary) -> void:
	if state == State.DONE:
		return
	var estado_srv := str(fila.get("estado", ""))
	if estado_srv == "en_proceso":
		var entrega := float(fila.get("segundos_para_entregar", 0))
		if state == State.REQUEST:
			_iniciar_proceso(entrega)
		elif not _process_timer.is_stopped() and absf(_process_timer.time_left - entrega) > DESFASE_TOLERADO:
			_process_timer.start(maxf(0.1, entrega))
	elif estado_srv == "pendiente" and state == State.REQUEST:
		var decidir := float(fila.get("segundos_para_decidir", 0))
		if not _decision_timer.is_stopped() and absf(_decision_timer.time_left - decidir) > DESFASE_TOLERADO:
			_decision_timer.start(maxf(0.1, decidir))


## El servidor ya lo entregó: completado (true) o fallido (false).
func finalizar_desde_servidor(completado: bool) -> void:
	if state != State.DONE:
		_finish(completado, 0.0, float(GameData.reputacion))


# --- Cronómetros ---

func _on_decision_timer_timeout() -> void:
	if state != State.REQUEST:
		return
	if _modo_servidor():
		# El servidor lo marca como EXPIRADO; Helpdesk quita la tarjeta en la próxima consulta.
		_set_time_labels("00:00", COLOR_URGENT, "00:00", COLOR_URGENT)
		_accept_button.disabled = true
		_reject_button.disabled = true
		return
	ticket_expired.emit(_data.id_ticket)
	queue_free()


func _on_process_timer_timeout() -> void:
	if state != State.IN_PROGRESS:
		return
	if _modo_servidor():
		# La entrega la decide el servidor (¿sigue habiendo capacidad?); aquí solo se espera.
		_process_label.text = "Entregando..."
		return
	# Simulación sin sesión: resultado local.
	push_warning("[TicketCard] Ticket %d sin respaldo en el servidor, resultado SIMULADO" % _data.id_ticket)
	_finish(true, 0.0, 0.0)


## Deja la tarjeta en su estado final (colapsada, con el resultado a la vista)
## y avisa a Helpdesk para que la mueva a la pestaña "Completados".
func _finish(exito: bool, creditos: float, reputacion: float, error_text: String = "") -> void:
	state = State.DONE
	finished_with_error = not error_text.is_empty()
	result_text = error_text if finished_with_error else ("RESUELTO" if exito else "FALLIDO")
	var color := COLOR_OK if (exito and not finished_with_error) else COLOR_FAIL

	_decision_timer.stop()
	_process_timer.stop()
	_set_time_labels(result_text, color, "--:--", COLOR_DIM)
	_process_label.text = result_text
	_process_label.add_theme_color_override("font_color", color)
	_process_label.visible = true
	_refresh_buttons()
	_set_expanded(false)

	ticket_resolved.emit(_data.id_ticket, exito, creditos, reputacion)
