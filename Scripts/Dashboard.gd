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

	_rack_container.alignment = BoxContainer.ALIGNMENT_CENTER
	_rack_container.add_theme_constant_override("separation", 35)

	_credits_label.text = "Créditos: ..."
	_poll_timer.wait_time = POLL_INTERVAL_SECONDS
	_poll_timer.timeout.connect(GameData.solicitar_dashboard)
	_poll_timer.start()

	if GameData.estado_recibido:
		_aplicar_estado()
	GameData.solicitar_dashboard()


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
	_credits_label.text = "Créditos: $%s" % _formato_miles(GameData.creditos)

	_pintar_barra(_temp_bar, GameData.temperatura, TEMPERATURA_ESCALA,
		"%d °C" % roundi(GameData.temperatura))
	_pintar_barra(_watts_bar, GameData.carga_electrica, GameData.capacidad_watts,
		"%d / %d W" % [roundi(GameData.carga_electrica), roundi(GameData.capacidad_watts)])
	# TODO: cuando los tickets aceptados reserven RAM/TFLOPS, estas dos barras
	# mostrarán "en uso / total". Por ahora el servidor solo reporta el total.
	_pintar_barra(_memory_bar, GameData.memoria, GameData.memoria,
		"%d GB" % roundi(GameData.memoria))
	_pintar_barra(_teraflops_bar, GameData.teraflops, GameData.teraflops,
		"%d TFLOPS" % roundi(GameData.teraflops))

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
