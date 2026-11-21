extends Control
class_name InventarioModal
## Va sobre el nodo raíz "Inventario" de Escenas/Inventario.tscn.
## El encabezado (consumo y temperatura) se pinta con lo que manda el servidor
## en GameData; esta pantalla ya no suma ni resta métricas por su cuenta.

const ItemCardScene: PackedScene = preload("res://Escenas/Inventario/InventoryItemCard.tscn")
const MENSAJE_SEGUNDOS := 3.0

@onready var _watts_label: Label = %WattsLabel
@onready var _temp_label: Label = %TempLabel
# El botón CERRAR (%CloseButton) se conecta desde Inventario.tscn a _on_close_button_pressed.

@onready var _tabs: TabContainer = %Tabs
@onready var _grid_servidores: GridContainer = %Servidores
@onready var _grid_enfriamiento: GridContainer = %Enfriamiento
@onready var _grid_red: GridContainer = %Red
var _grid_energia: GridContainer # la escena no trae pestaña de Energía: se crea en _ready

var _mensaje_label: Label
var _id_mensaje: int = 0


func _ready() -> void:
	_grid_energia = GridContainer.new()
	_grid_energia.name = "Energía"
	_grid_energia.columns = _grid_servidores.columns
	_tabs.add_child(_grid_energia)

	_mensaje_label = Label.new()
	_mensaje_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensaje_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	var main_vbox := _tabs.get_parent()
	main_vbox.add_child(_mensaje_label)
	main_vbox.move_child(_mensaje_label, _tabs.get_index())

	GameData.inventario_recibido.connect(_on_inventario_recibido)
	GameData.inventario_error.connect(_on_inventario_error)
	GameData.estado_actualizado.connect(_refresh_header)

	_limpiar_grids()
	_refresh_header()
	GameData.solicitar_inventario()


func _on_close_button_pressed() -> void:
	if get_tree().current_scene == self:
		# Corrida sola (F6): no hay Dashboard debajo, se vuelve a él.
		get_tree().change_scene_to_file("res://Escenas/Dashboard.tscn")
	else:
		# Popup del Dashboard: basta con quitarlo.
		queue_free()


func _limpiar_grids() -> void:
	for grid in [_grid_servidores, _grid_enfriamiento, _grid_red, _grid_energia]:
		for child in grid.get_children():
			child.queue_free()


func _on_inventario_recibido(items: Array) -> void:
	_limpiar_grids()
	for item_dict in items:
		if not item_dict is Dictionary:
			continue
		var data := InventoryItemData.desde_json(item_dict)
		data.icon = ImagenesProductos.cargar(data.nombre_producto)
		_spawn_item(data)


func _on_inventario_error(texto: String) -> void:
	_mostrar_mensaje(texto, true)


func _spawn_item(data: InventoryItemData) -> void:
	var card: InventoryItemCard = ItemCardScene.instantiate()
	_grid_for_category(data.categoria).add_child(card)
	card.setup(data)
	card.mensaje.connect(_on_card_mensaje)


func _on_card_mensaje(texto: String, es_error: bool) -> void:
	_mostrar_mensaje(texto, es_error)
	if es_error:
		# Puede que el inventario haya cambiado en otro lado (p. ej. ya se vendió):
		# se vuelve a pedir para que la pantalla coincida con el servidor.
		GameData.solicitar_inventario()


func _grid_for_category(categoria: String) -> GridContainer:
	var normalized := categoria.to_lower()
	if normalized.begins_with("enfri") or normalized.begins_with("refriger"):
		return _grid_enfriamiento
	if normalized.begins_with("red") or normalized.begins_with("network"):
		return _grid_red
	if normalized.begins_with("energ"):
		return _grid_energia
	return _grid_servidores


func _refresh_header() -> void:
	_watts_label.text = "Consumo: %d / %d W" % [roundi(GameData.carga_electrica), roundi(GameData.capacidad_watts)]
	_temp_label.text = "Temperatura: %d °C" % roundi(GameData.temperatura)


func _mostrar_mensaje(texto: String, es_error: bool) -> void:
	if texto.is_empty():
		return
	_id_mensaje += 1
	var id := _id_mensaje
	_mensaje_label.text = texto
	_mensaje_label.add_theme_color_override("font_color", Color(1, 0.4, 0.4) if es_error else Color(0.4, 0.9, 0.5))
	get_tree().create_timer(MENSAJE_SEGUNDOS).timeout.connect(func():
		if is_instance_valid(self) and id == _id_mensaje:
			_mensaje_label.text = ""
	)
