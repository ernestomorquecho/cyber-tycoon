extends PanelContainer
class_name InventoryItemCard
## Va sobre el nodo raíz de Escenas/Inventario/InventoryItemCard.tscn.
## Representa UNA celda del GridContainer: ícono, métrica rápida, el interruptor
## de encender/apagar y el botón VENDER (se crea por código, no hay que tocar la escena).
## Todo cambio se pide al servidor y solo se aplica cuando responde 200.

## Mensaje para el encabezado del Inventario (éxito o error del servidor).
signal mensaje(texto: String, es_error: bool)

const CONFIRMAR_SEGUNDOS := 3.0
const Estilo := preload("res://Scripts/EstiloTienda.gd")

## Grupo de categoría (servidores, refrigeracion, energia, redes, otros),
## el mismo que usa la Tienda; el Inventario filtra sus pestañas con él.
var grupo: String = "otros"

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
	_toggle_button.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND

	GameData.equipo_cambiado.connect(_on_equipo_cambiado)
	GameData.equipo_vendido.connect(_on_equipo_vendido)


func setup(data: InventoryItemData) -> void:
	_data = data
	grupo = Estilo.grupo_de({"categoria": data.categoria})
	_aplicar_estilo()
	_name_label.text = data.nombre_producto
	if data.icon:
		_icon_rect.texture = data.icon
	_metric_label.text = _texto_metrica(data)
	_toggle_button.set_pressed_no_signal(data.activo)
	_update_visual_state(data.activo)
	_reset_sell_button()


## Mismo look que TarjetaProducto: fondo oscuro, borde con el acento neón
## de la categoría y botón VENDER en color dinero.
func _aplicar_estilo() -> void:
	var acento := Estilo.color_de(grupo)
	add_theme_stylebox_override("panel", Estilo.caja(Estilo.FONDO_TARJETA, acento.darkened(0.35), 2))
	size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_name_label.add_theme_color_override("font_color", Estilo.TEXTO)
	_name_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_name_label.custom_minimum_size.y = 40
	_name_label.vertical_alignment = VERTICAL_ALIGNMENT_CENTER
	_metric_label.add_theme_color_override("font_color", acento)
	_toggle_button.add_theme_color_override("font_color", Estilo.TEXTO_SECUNDARIO)
	_toggle_button.add_theme_color_override("font_pressed_color", Estilo.ACENTOS["refrigeracion"])
	_toggle_button.add_theme_color_override("font_hover_pressed_color", Estilo.ACENTOS["refrigeracion"])
	Estilo.aplicar_boton(_sell_button, Estilo.DINERO)
	_sell_button.size_flags_horizontal = Control.SIZE_EXPAND_FILL


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
	# Equipo apagado = tarjeta en gris, tal como pide el boceto. Si lo apagó el
	# apagado de emergencia (> 85 °C) se tiñe de rojo para que se note el motivo.
	var sobrecalentado := not activo and _data != null and _data.sobrecalentado
	if activo:
		modulate = Color(1, 1, 1, 1)
		_toggle_button.text = "Encendido"
	elif sobrecalentado:
		modulate = Color(1, 0.45, 0.45, 1)
		_toggle_button.text = "SOBRECALENTADO"
	elif _data != null and _data.sin_energia:
		# Lo apagó el apagón parcial (falla eléctrica): tono ámbar.
		modulate = Color(1, 0.8, 0.4, 1)
		_toggle_button.text = "SIN ENERGÍA"
	else:
		modulate = Color(0.5, 0.5, 0.5, 1)
		_toggle_button.text = "Apagado"
	tooltip_text = _tooltip()


func _tooltip() -> String:
	if _data == null:
		return ""
	var texto := "Rack %d, U %d" % [_data.rack_numero, _data.slot_inicio + 1] if _data.rack_numero > 0 else ""
	if not _data.activo and _data.sin_energia:
		texto += "
Apagado por el apagón parcial (falla eléctrica). Reenciéndelo cuando vuelva la energía."
	if not _data.activo and _data.sobrecalentado:
		texto += "\nApagado de emergencia por temperatura. Mejora la refrigeración para reencenderlo."
	return texto.strip_edges()


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
	if exito:
		_data.sobrecalentado = false # el jugador lo cambió: se borra la marca
		_data.sin_energia = false
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
