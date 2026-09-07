extends PanelContainer
class_name InventoryItemCard
## Va sobre el nodo raíz de Escenas/Inventario/InventoryItemCard.tscn.
## Representa UNA celda del GridContainer: ícono, métrica rápida
## (ej. "+100 TFlops") y el Interruptor (CheckButton) de apagar/encender.

signal toggled_confirmed(id_inventario: int, activo: bool, delta_temperatura: int, delta_watts: int)

var _data: InventoryItemData

@onready var _icon_rect: TextureRect = %IconRect
@onready var _name_label: Label = %NameLabel
@onready var _metric_label: Label = %MetricLabel
@onready var _toggle_button: CheckButton = %ToggleButton


func _ready() -> void:
	_toggle_button.toggled.connect(_on_toggle_toggled)


func setup(data: InventoryItemData) -> void:
	_data = data
	_name_label.text = data.nombre_producto
	if data.icon:
		_icon_rect.texture = data.icon

	_metric_label.text = "+%d TFlops" % data.aumento_teraflops

	_toggle_button.set_pressed_no_signal(data.activo)
	_update_visual_state(data.activo)


func _on_toggle_toggled(pressed: bool) -> void:
	_toggle_button.disabled = true # bloqueado mientras "responde la API"
	_request_toggle_item(pressed)


func _update_visual_state(activo: bool) -> void:
	# Equipo apagado = tarjeta en gris, tal como pide el boceto.
	modulate = Color(1, 1, 1, 1) if activo else Color(0.5, 0.5, 0.5, 1)


# --- Llamada a la API (cascarón / stub) ---
# TODO: el backend actual (CyberTycoonBackEnd-main) NO tiene todavía un
# endpoint para esto. La columna Inventario_Usuario.estado_item ya existe en
# la base de datos, pero ninguna ruta la usa aún. Cuando exista algo como
# POST /api/jugador/inventario/{id_inventario}/toggle  { activo: bool }
# aquí es donde se reemplaza el timer de abajo por el HTTPRequest real, y
# solo se debe aplicar el cambio cuando llegue el 200 OK.
func _request_toggle_item(pressed: bool) -> void:
	await get_tree().create_timer(0.3).timeout # simula round-trip a la API
	_on_toggle_confirmed_by_server(pressed)


func _on_toggle_confirmed_by_server(activo: bool) -> void:
	_data.activo = activo
	_update_visual_state(activo)
	_toggle_button.disabled = false

	# Estos deltas son SOLO para que el header de la pantalla reaccione durante
	# las pruebas sin backend real. En cuanto exista el endpoint de verdad, hay
	# que reemplazar esto por los valores exactos que regrese el servidor
	# (nunca calcularlos aquí en producción).
	var signo := 1 if activo else -1
	toggled_confirmed.emit(
		_data.id_inventario,
		activo,
		signo * _data.impacto_temperatura,
		signo * _data.consumo_electrico
	)
