extends Control
class_name Dashboard
## Va sobre el nodo raíz "Dashboard" de Escenas/Dashboard.tscn.
## Esta pantalla vive siempre activa: hace polling constante y actúa como
## router que abre las escenas de los demás módulos (Tienda/Catálogo,
## Tickets, Inventario) sobre un OverlayLayer.

const CatalogoScene: PackedScene = preload("res://Escenas/Catalogo.tscn")
const TicketsScene: PackedScene = preload("res://Escenas/Tickets.tscn")
const InventarioScene: PackedScene = preload("res://Escenas/Inventario.tscn")
const RackScene: PackedScene = preload("res://Escenas/Dashboard/Rack.tscn")

# TODO: la especificación pide GET /api/usuario/dashboard, pero el backend
# actual (CyberTycoonBackEnd) solo expone GET /api/jugador/estado (bajo el
# prefijo /api/jugador, no /api/usuario), y esa ruta no regresa el arreglo de
# racks que se usa aquí abajo. Hay que acordar con el equipo de backend si
# agregan /api/usuario/dashboard tal cual la spec, o adaptamos esta pantalla
# a lo que exista en /api/jugador/estado.
const DASHBOARD_ENDPOINT := "/api/usuario/dashboard"
const POLL_INTERVAL_SECONDS := 5.0
const TEMPERATURA_ALERTA := 80.0 # umbral visual local; ajustar con diseño

@onready var _credits_label: Label = %CreditsLabel

@onready var _temp_bar: ProgressBar = %TempBar
@onready var _watts_bar: ProgressBar = %WattsBar
@onready var _memory_bar: ProgressBar = %MemoryBar
@onready var _teraflops_bar: ProgressBar = %TeraflopsBar

@onready var _rack_container: HBoxContainer = %RackContainer

@onready var _inventario_button: Button = %InventarioButton
@onready var _salir_button: Button = %SalirButton
@onready var _tienda_button: Button = %TiendaButton
@onready var _tickets_button: Button = %TicketsButton

@onready var _overlay_layer: Control = %OverlayLayer
@onready var _poll_timer: Timer = $PollTimer

var _rack_nodes: Dictionary = {} # id_rack (int) -> instancia de Rack


func _ready() -> void:
	_inventario_button.pressed.connect(func(): _open_popup(InventarioScene))
	_tienda_button.pressed.connect(func(): _open_popup(CatalogoScene))
	_tickets_button.pressed.connect(func(): _open_popup(TicketsScene))
	_salir_button.pressed.connect(_on_salir_pressed)

	_poll_timer.wait_time = POLL_INTERVAL_SECONDS
	_poll_timer.timeout.connect(_poll_dashboard)
	_poll_timer.start()

	_poll_dashboard() # primer refresco inmediato al entrar a la pantalla


func _on_salir_pressed() -> void:
	# TODO: aquí normalmente se abriría un menú de Opciones/Salir del juego.
	print("[Dashboard] Salir/Opciones presionado (falta definir ese menú)")


func _open_popup(scene: PackedScene) -> void:
	# Cierra cualquier ventana emergente anterior antes de abrir la nueva,
	# para no apilar Tienda + Tickets + Inventario al mismo tiempo.
	for child in _overlay_layer.get_children():
		child.queue_free()
	var instance := scene.instantiate()
	_overlay_layer.add_child(instance)


# --- Polling a la API (cascarón / stub) ---
# TODO: reemplazar por un HTTPRequest real hacia DASHBOARD_ENDPOINT.
# Esta es la única pantalla con polling constante, así que cuando se conecte
# de verdad hay que cuidar timeouts y no disparar una petición nueva si la
# anterior no ha respondido todavía.
func _poll_dashboard() -> void:
	await get_tree().create_timer(0.2).timeout # simula la latencia de red
	var mock_response := _build_mock_dashboard_response()
	_apply_dashboard_data(mock_response)


func _apply_dashboard_data(data: Dictionary) -> void:
	var metricas: Dictionary = data.get("metricas", {})

	_credits_label.text = "Créditos: %d" % int(metricas.get("creditos", 0))

	_temp_bar.value = float(metricas.get("temperatura", 0))
	_watts_bar.max_value = float(metricas.get("watts_maximos", 1))
	_watts_bar.value = float(metricas.get("watts_actuales", 0))
	_memory_bar.value = float(metricas.get("memoria_disponible", 0))
	_teraflops_bar.value = float(metricas.get("teraflops", 0))

	var hay_alerta: bool = float(metricas.get("temperatura", 0)) >= TEMPERATURA_ALERTA

	var racks: Array = data.get("racks", [])
	for rack_json in racks:
		var id_rack := int(rack_json.get("id_rack", 0))
		var espacio := int(rack_json.get("espacio_usado", 0))
		_ensure_rack(id_rack, espacio, hay_alerta)


func _ensure_rack(id_rack: int, espacio_usado: int, en_alerta: bool) -> void:
	if _rack_nodes.has(id_rack):
		var rack: Rack = _rack_nodes[id_rack]
		var data: RackData = RackData.new()
		data.id_rack = id_rack
		data.espacio_usado = espacio_usado
		rack.setup(data)
		rack.set_alert(en_alerta)
		return

	# Rack nuevo: la API reportó un id que no teníamos, el carrusel crece
	# automáticamente hacia la derecha, tal como pide la spec.
	var data := RackData.new()
	data.id_rack = id_rack
	data.espacio_usado = espacio_usado

	var rack_instance: Rack = RackScene.instantiate()
	_rack_container.add_child(rack_instance)
	rack_instance.setup(data)
	rack_instance.set_alert(en_alerta)
	_rack_nodes[id_rack] = rack_instance


# --- Solo para probar el flujo mientras no hay conexión real ---

func _build_mock_dashboard_response() -> Dictionary:
	return {
		"metricas": {
			"creditos": 10000,
			"temperatura": 45,
			"watts_actuales": 1200,
			"watts_maximos": 2000,
			"memoria_disponible": 64,
			"teraflops": 320
		},
		"racks": [
			{"id_rack": 1, "espacio_usado": 8},
			{"id_rack": 2, "espacio_usado": 3},
			{"id_rack": 3, "espacio_usado": 0}
		]
	}
