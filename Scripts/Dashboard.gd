extends Control
class_name Dashboard
## Va sobre el nodo raíz "Dashboard" de Escenas/Dashboard.tscn.
## Esta pantalla vive siempre activa: hace polling a GET /api/usuario/dashboard
## (vía GameData) y actúa como router que abre las escenas de los demás módulos
## (Tienda/Catálogo, Tickets, Inventario) sobre un OverlayLayer.
## No calcula nada: pinta lo que GameData recibió del servidor.

const LOGIN_SCENE_PATH := "res://login/Login.tscn"
const CatalogoScene: PackedScene = preload("res://Escenas/Catalogo.tscn")
const TicketsScene: PackedScene = preload("res://Escenas/Tickets.tscn")
const InventarioScene: PackedScene = preload("res://Escenas/Inventario.tscn")
const RackScene: PackedScene = preload("res://Escenas/Dashboard/Rack.tscn")

const POLL_INTERVAL_SECONDS := 5.0
const TEMPERATURA_ALERTA := 85.0  # > 85 °C = zona crítica (CLAUDE.md §5); solo visual
const TEMPERATURA_ESCALA := 100.0 # tope visual de la barra de temperatura
const COLOR_TEMP_ADVERTENCIA := Color(1.0, 0.12, 0.12)  # barra en zona de advertencia (status WARNING)
const COLOR_INGRESO_NORMAL := Color(0.45, 1.0, 0.5)
const COLOR_INGRESO_RECORTADO := Color(1.0, 0.65, 0.2)
const SEGUNDOS_AVISO_FLOTANTE := 4.0

@onready var _credits_label: Label = %CreditsLabel

@onready var _temp_bar: ProgressBar = %TempBar
@onready var _watts_bar: ProgressBar = %WattsBar
@onready var _memory_bar: ProgressBar = %MemoryBar
@onready var _teraflops_bar: ProgressBar = %TeraflopsBar

@onready var _rack_container: HBoxContainer = %RackContainer

@onready var _inventario_button: TextureButton = %InventarioButton
@onready var _salir_button: TextureButton = %SalirButton
@onready var _tienda_button: TextureButton = %TiendaButton
@onready var _tickets_button: TextureButton = %TicketsButton

@onready var _overlay_layer: Control = %OverlayLayer
@onready var _poll_timer: Timer = $PollTimer

var _rack_nodes: Dictionary = {} # id_rack (int) -> instancia de Rack
var _bar_labels: Dictionary = {} # ProgressBar -> Label con el valor y su unidad
var _game_over_modal: GameOverModal = null
var _globo_tickets: Label # cuántas solicitudes esperan respuesta
var _ingreso_label: Label # "+$X/min" junto a los créditos
var _aviso_temp: Label    # aviso de thermal throttling debajo de la barra de temperatura
var _color_temp_normal: Color


func _ready() -> void:
	# Sin sesión (p. ej. el juego se abrió directo en esta escena) no hay token:
	# las compras fallarían con 401 y se verían datos falsos. Se va al Login.
	if not GameData.hay_sesion():
		_volver_al_login.call_deferred()
		return

	_inventario_button.pressed.connect(func(): _open_popup(InventarioScene))
	_tienda_button.pressed.connect(func(): _open_popup(CatalogoScene))
	_tickets_button.pressed.connect(func(): _open_popup(TicketsScene))
	_salir_button.pressed.connect(_on_salir_pressed)

	GameData.estado_actualizado.connect(_aplicar_estado)
	GameData.sesion_expirada.connect(_on_sesion_expirada)

	for bar in [_temp_bar, _watts_bar, _memory_bar, _teraflops_bar]:
		_preparar_barra(bar)

	_color_temp_normal = _temp_bar.self_modulate
	_crear_globo_tickets()
	_crear_indicadores_ingreso()
	GameData.ingreso_pasivo_cobrado.connect(_on_ingreso_pasivo_cobrado)

	_rack_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_rack_container.add_theme_constant_override("separation", 35)

	_credits_label.text = "Créditos: ..."
	_poll_timer.wait_time = POLL_INTERVAL_SECONDS
	_poll_timer.timeout.connect(GameData.solicitar_dashboard)
	_poll_timer.start()

	if GameData.estado_recibido:
		_aplicar_estado()
	GameData.solicitar_dashboard()


## Con GAME_OVER el servidor ya bloquea compras/tickets/equipos; aquí solo se
## cierra lo que esté abierto, se desactiva la navegación y se muestra el modal.
func _actualizar_game_over() -> void:
	var terminada := GameData.es_game_over()
	for boton in [_inventario_button, _tienda_button, _tickets_button]:
		boton.disabled = terminada
		boton.modulate = Color(0.4, 0.4, 0.4) if terminada else Color.WHITE

	if terminada:
		if _game_over_modal == null:
			for child in _overlay_layer.get_children():
				child.queue_free()
			_game_over_modal = GameOverModal.new()
			_game_over_modal.salir_solicitado.connect(_on_salir_pressed)
			add_child(_game_over_modal) # último hijo = encima de todo
		_game_over_modal.actualizar()
	elif _game_over_modal != null:
		_game_over_modal.queue_free()
		_game_over_modal = null


## Globo rojo con el número de solicitudes pendientes sobre el botón de Tickets
## (los tickets llegan y expiran aunque esa pantalla esté cerrada).
func _crear_globo_tickets() -> void:
	_globo_tickets = Label.new()
	_globo_tickets.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_globo_tickets.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_globo_tickets.custom_minimum_size = Vector2(34, 34)
	_globo_tickets.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_globo_tickets.add_theme_color_override("font_color", Color.WHITE)
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.9, 0.15, 0.2)
	fondo.set_corner_radius_all(17)
	_globo_tickets.add_theme_stylebox_override("normal", fondo)
	_globo_tickets.set_anchors_and_offsets_preset(Control.PRESET_TOP_RIGHT)
	_globo_tickets.position += Vector2(-6, 4)
	_globo_tickets.visible = false
	_tickets_button.add_child(_globo_tickets)


## Ingreso pasivo junto a los créditos y aviso de temperatura bajo su barra
## (creados por código para no tocar el Inspector).
func _crear_indicadores_ingreso() -> void:
	_ingreso_label = Label.new()
	_ingreso_label.add_theme_color_override("font_color", COLOR_INGRESO_NORMAL)
	_ingreso_label.add_theme_color_override("font_outline_color", Color.BLACK)
	_ingreso_label.add_theme_constant_override("outline_size", 4)
	_ingreso_label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	var barra_superior := _credits_label.get_parent()
	barra_superior.add_child(_ingreso_label)
	barra_superior.move_child(_ingreso_label, _credits_label.get_index() + 1)

	_aviso_temp = Label.new()
	_aviso_temp.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_aviso_temp.add_theme_color_override("font_color", Color(1.0, 0.35, 0.3))
	_aviso_temp.add_theme_color_override("font_outline_color", Color.BLACK)
	_aviso_temp.add_theme_constant_override("outline_size", 4)
	_aviso_temp.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_aviso_temp.mouse_filter = Control.MOUSE_FILTER_IGNORE
	_aviso_temp.visible = false
	var columna_temp := _temp_bar.get_parent()
	columna_temp.add_child(_aviso_temp)
	columna_temp.move_child(_aviso_temp, _temp_bar.get_index() + 1)


func _actualizar_ingresos() -> void:
	var advertencia := GameData.status_temperatura == "WARNING"
	_temp_bar.self_modulate = COLOR_TEMP_ADVERTENCIA if advertencia else _color_temp_normal

	_ingreso_label.text = "   +$%s/min" % _formato_ingreso(GameData.ingreso_por_minuto)
	_ingreso_label.add_theme_color_override("font_color",
		COLOR_INGRESO_RECORTADO if advertencia else COLOR_INGRESO_NORMAL)

	_aviso_temp.visible = advertencia and not GameData.es_game_over()
	if advertencia:
		if GameData.ingreso_base_por_minuto > 0.0:
			var recorte := roundi((1.0 - GameData.ingreso_por_minuto / GameData.ingreso_base_por_minuto) * 100.0)
			_aviso_temp.text = "¡Sobrecalentamiento! Ingresos -%d%%. Mejora la refrigeración." % recorte
		else:
			_aviso_temp.text = "¡Sobrecalentamiento! Mejora la refrigeración."


## Al volver al juego tras un rato: "Mientras no estabas ganaste $X".
func _on_ingreso_pasivo_cobrado(creditos: float, segundos: int) -> void:
	var minutos := maxi(1, roundi(segundos / 60.0))
	_mostrar_aviso_flotante("Ingresos pasivos: +$%s en %d min" % [_formato_ingreso(creditos), minutos])


func _mostrar_aviso_flotante(texto: String) -> void:
	if GameData.es_game_over():
		return
	var aviso := Label.new()
	aviso.text = texto
	aviso.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	aviso.mouse_filter = Control.MOUSE_FILTER_IGNORE
	aviso.add_theme_color_override("font_color", Color.WHITE)
	var fondo := StyleBoxFlat.new()
	fondo.bg_color = Color(0.05, 0.35, 0.15, 0.92)
	fondo.set_corner_radius_all(10)
	fondo.set_content_margin_all(12)
	aviso.add_theme_stylebox_override("normal", fondo)
	aviso.set_anchors_and_offsets_preset(Control.PRESET_CENTER_TOP)
	aviso.grow_horizontal = Control.GROW_DIRECTION_BOTH
	aviso.position.y = 70
	add_child(aviso)
	var tween := aviso.create_tween()
	tween.tween_interval(SEGUNDOS_AVISO_FLOTANTE)
	tween.tween_property(aviso, "modulate:a", 0.0, 0.6)
	tween.tween_callback(aviso.queue_free)


## Salir: cierra la sesión y vuelve al Login.
func _on_salir_pressed() -> void:
	GameData.cerrar_sesion()
	_volver_al_login()


func _on_sesion_expirada() -> void:
	push_warning("[Dashboard] La sesión expiró o el token no es válido; volviendo al Login")
	GameData.cerrar_sesion()
	_volver_al_login()


func _volver_al_login() -> void:
	if is_inside_tree():
		get_tree().change_scene_to_file(LOGIN_SCENE_PATH)


func _open_popup(scene: PackedScene) -> void:
	# Cierra cualquier ventana emergente anterior en el overlay antes de abrir la nueva
	for child in _overlay_layer.get_children():
		child.queue_free()
	var instance := scene.instantiate()
	_overlay_layer.add_child(instance)


# --- Barras de métricas: valor real con su unidad en lugar de porcentaje ---

func _preparar_barra(bar: ProgressBar) -> void:
	bar.show_percentage = false
	bar.custom_minimum_size.y = maxf(bar.custom_minimum_size.y, 26.0)
	var label := Label.new()
	label.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	label.add_theme_color_override("font_color", Color.WHITE)
	label.add_theme_color_override("font_outline_color", Color.BLACK)
	label.add_theme_constant_override("outline_size", 4)
	label.mouse_filter = Control.MOUSE_FILTER_IGNORE
	# El color de la barra (naranja, amarillo...) viene de su "modulate", que
	# también teñiría el texto hijo. Se pasa a self_modulate, que solo pinta la barra.
	bar.self_modulate = bar.modulate
	bar.modulate = Color.WHITE
	bar.add_child(label)
	_bar_labels[bar] = label


func _pintar_barra(bar: ProgressBar, valor: float, maximo: float, texto: String) -> void:
	bar.max_value = maxf(maximo, 1.0)
	bar.value = clampf(valor, 0.0, bar.max_value)
	if _bar_labels.has(bar):
		_bar_labels[bar].text = texto


func _aplicar_estado() -> void:
	_credits_label.text = "Créditos: $%s     Reputación: %d/100" % [
		_formato_miles(GameData.creditos), GameData.reputacion]
	_actualizar_game_over()
	_actualizar_ingresos()
	_globo_tickets.text = str(GameData.tickets_pendientes)
	_globo_tickets.visible = GameData.tickets_pendientes > 0 and not GameData.es_game_over()

	_pintar_barra(_temp_bar, GameData.temperatura, TEMPERATURA_ESCALA,
		"%d °C" % roundi(GameData.temperatura))
	_pintar_barra(_watts_bar, GameData.carga_electrica, GameData.capacidad_watts,
		"%d / %d W" % [roundi(GameData.carga_electrica), roundi(GameData.capacidad_watts)])
	# RAM y TFLOPS: lo que apartan los tickets en proceso sobre el total instalado.
	var ram_uso := float(GameData.reservado.get("memoria", 0))
	var tf_uso := float(GameData.reservado.get("teraflops", 0))
	_pintar_barra(_memory_bar, ram_uso, GameData.memoria,
		"%d / %d GB en uso" % [roundi(ram_uso), roundi(GameData.memoria)])
	_pintar_barra(_teraflops_bar, tf_uso, GameData.teraflops,
		"%d / %d TFLOPS en uso" % [roundi(tf_uso), roundi(GameData.teraflops)])

	var en_alerta := GameData.temperatura > TEMPERATURA_ALERTA
	for rack_json in GameData.racks:
		_ensure_rack(rack_json, en_alerta)


func _ensure_rack(rack_json: Dictionary, en_alerta: bool) -> void:
	var data := RackData.desde_json(rack_json)

	var rack: Rack = _rack_nodes.get(data.id_rack)
	if rack == null:
		# Rack nuevo: se añade al carrusel manteniendo el tamaño del asset (260x480)
		rack = RackScene.instantiate()
		rack.custom_minimum_size = Vector2(260, 480)
		rack.size_flags_vertical = Control.SIZE_EXPAND_FILL
		_rack_container.add_child(rack)
		_rack_nodes[data.id_rack] = rack

	rack.setup(data)
	rack.set_alert(en_alerta)


## 8 -> "8", 154.8 -> "154.8", 1548 -> "1,548"
static func _formato_ingreso(valor: float) -> String:
	if is_equal_approx(valor, roundf(valor)) or absf(valor) >= 1000.0:
		return _formato_miles(valor)
	return "%.1f" % valor


static func _formato_miles(valor: float) -> String:
	var entero := str(roundi(valor))
	var resultado := ""
	var contador := 0
	for i in range(entero.length() - 1, -1, -1):
		resultado = entero[i] + resultado
		contador += 1
		if contador % 3 == 0 and i > 0 and entero[i - 1] != "-":
			resultado = "," + resultado
	return resultado
