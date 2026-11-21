extends PanelContainer
class_name InventoryItemCard
## Va sobre el nodo raíz de Escenas/Inventario/InventoryItemCard.tscn.
## Representa UNA celda del GridContainer: ícono, métrica rápida, el interruptor
## de encender/apagar y el botón VENDER (se crea por código, no hay que tocar la escena).
## Todo cambio se pide al servidor y solo se aplica cuando responde 200.

## Mensaje para el encabezado del Inventario (éxito o error del servidor).
signal mensaje(texto: String, es_error: bool)

const CONFIRMAR_SEGUNDOS := 3.0

var _data: InventoryItemData
var _sell_button: Button
var _esperando_confirmacion: bool = false
var _ocupado: bool = false # hay una petición en curso para este equipo

@onready var _icon_rect: TextureRect = %IconRect
@onready var _name_label: Label = %NameLabel
@onready var _metric_label: Label = %MetricLabel
@onready var _toggle_button: CheckButton = %ToggleButton


func _ready() -> void:
	_toggle_button.toggled.connect(_on_toggle_toggled)

	_sell_button = Button.new()
	_sell_button.size_flags_horizontal = Control.SIZE_SHRINK_CENTER
	_sell_button.pressed.connect(_on_sell_pressed)
	_toggle_button.get_parent().add_child(_sell_button)

	GameData.equipo_cambiado.connect(_on_equipo_cambiado)
	GameData.equipo_vendido.connect(_on_equipo_vendido)


func setup(data: InventoryItemData) -> void:
	_data = data
	_name_label.text = data.nombre_producto
	if data.icon:
		_icon_rect.texture = data.icon
	_metric_label.text = _texto_metrica(data)
	_toggle_button.set_pressed_no_signal(data.activo)
	_update_visual_state(data.activo)
	_reset_sell_button()
	tooltip_text = "Rack %d, U %d" % [data.rack_numero, data.slot_inicio + 1] if data.rack_numero > 0 else ""


func get_id_inventario() -> int:
	return _data.id_inventario if _data else 0


func _texto_metrica(data: InventoryItemData) -> String:
	var cat := data.categoria.to_lower()
	if cat.begins_with("refriger") or cat.begins_with("enfri"):
		return "%d °C" % data.impacto_temperatura
	if cat.begins_with("energ"):
		return "+%d W capacidad" % data.aumento_watts
	if cat.begins_with("red"):
		return "+%d ancho de banda" % data.ancho_banda
	return "+%d TFLOPS · +%d GB" % [data.aumento_teraflops, data.aumento_memoria]


func _update_visual_state(activo: bool) -> void:
	# Equipo apagado = tarjeta en gris, tal como pide el boceto.
	modulate = Color(1, 1, 1, 1) if activo else Color(0.5, 0.5, 0.5, 1)
	_toggle_button.text = "Encendido" if activo else "Apagado"


func _set_ocupado(valor: bool) -> void:
	_ocupado = valor
	_toggle_button.disabled = valor
	_sell_button.disabled = valor


# --- Encender / apagar ---

func _on_toggle_toggled(pressed: bool) -> void:
	if _ocupado:
		return
	_set_ocupado(true)
	GameData.cambiar_estado_equipo(_data.id_inventario, pressed)


func _on_equipo_cambiado(id_inventario: int, exito: bool, encendido: bool, texto: String) -> void:
	if _data == null or id_inventario != _data.id_inventario:
		return
	_set_ocupado(false)
	# Si el servidor dijo que no (p. ej. INSUFFICIENT_POWER), el interruptor regresa.
	_data.activo = encendido
	_toggle_button.set_pressed_no_signal(encendido)
	_update_visual_state(encendido)
	mensaje.emit(texto, not exito)


# --- Vender (dos toques: el primero pide confirmación) ---

func _reset_sell_button() -> void:
	_esperando_confirmacion = false
	if _sell_button and _data:
		_sell_button.text = "VENDER $%d" % roundi(_data.precio_venta)


func _on_sell_pressed() -> void:
	if _ocupado:
		return
	if not _esperando_confirmacion:
		_esperando_confirmacion = true
		_sell_button.text = "¿CONFIRMAR?"
		get_tree().create_timer(CONFIRMAR_SEGUNDOS).timeout.connect(func():
			if is_instance_valid(self) and _esperando_confirmacion and not _ocupado:
				_reset_sell_button()
		)
		return
	_esperando_confirmacion = false
	_set_ocupado(true)
	_sell_button.text = "VENDIENDO..."
	GameData.vender_equipo(_data.id_inventario)


func _on_equipo_vendido(id_inventario: int, exito: bool, texto: String) -> void:
	if _data == null or id_inventario != _data.id_inventario:
		return
	mensaje.emit(texto, not exito)
	if exito:
		queue_free()
	else:
		_set_ocupado(false)
		_reset_sell_button()
