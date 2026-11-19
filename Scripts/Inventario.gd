extends Control
class_name InventarioModal
## Va sobre el nodo raíz "Inventario" de Escenas/Inventario.tscn.

const ItemCardScene: PackedScene = preload("res://Escenas/Inventario/InventoryItemCard.tscn")

@onready var _watts_label: Label = %WattsLabel
@onready var _temp_label: Label = %TempLabel
@onready var _close_button: Button = %CloseButton

@onready var _grid_servidores: GridContainer = %Servidores
@onready var _grid_enfriamiento: GridContainer = %Enfriamiento
@onready var _grid_red: GridContainer = %Red

# Métricas del jugador para el header
var _capacidad_watts: int = 1000
var _carga_electrica_actual: int = 0
var _temperatura_cd: int = 25


func _ready() -> void:

	# Nos conectamos a las señales del inventario real en GameData
	GameData.inventario_recibido.connect(_on_inventario_recibido)
	GameData.inventario_error.connect(_on_inventario_error)

	# Limpiamos los grids por si acaso y pedimos el inventario al servidor
	_limpiar_grids()
	GameData.solicitar_inventario()
	_refresh_header()


func _on_close_button_pressed() -> void:
	get_tree().change_scene_to_file("res://Escenas/Dashboard.tscn")


func _limpiar_grids() -> void:
	for child in _grid_servidores.get_children():
		child.queue_free()
	for child in _grid_enfriamiento.get_children():
		child.queue_free()
	for child in _grid_red.get_children():
		child.queue_free()


func _on_inventario_recibido(items: Array) -> void:
	_limpiar_grids()
	
	for item_dict in items:
		var data = InventoryItemData.new()
		# Mapeamos los campos que vienen del backend (join entre inventario y catalogo)
		data.id_inventario = int(item_dict.get("id_inventario", 0))
		data.nombre_producto = String(item_dict.get("nombreProducto", "Hardware"))
		data.categoria = String(item_dict.get("categoria", "Servidor"))
		data.aumento_teraflops = int(item_dict.get("aumento_teraflops", 0))
		data.impacto_temperatura = int(item_dict.get("impacto_temperatura", 0))
		data.consumo_electrico = int(item_dict.get("consumoElectrico", 0))
		data.activo = bool(item_dict.get("activo", true))
		
		_spawn_item(data)
		
		# Sumamos consumo eléctrico inicial para las métricas del header
		if data.activo:
			_carga_electrica_actual += data.consumo_electrico
			_temperatura_cd += data.impacto_temperatura

	_refresh_header()


func _on_inventario_error(mensaje: String) -> void:
	print("[Inventario] Error al cargar: ", mensaje)


func _spawn_item(data: InventoryItemData) -> void:
	var card: InventoryItemCard = ItemCardScene.instantiate()
	_grid_for_category(data.categoria).add_child(card)
	card.setup(data)
	card.toggled_confirmed.connect(_on_item_toggled_confirmed)


func _grid_for_category(categoria: String) -> GridContainer:
	var normalized := categoria.to_lower()
	if normalized.begins_with("enfri") or normalized.begins_with("refriger"):
		return _grid_enfriamiento
	if normalized.begins_with("red") or normalized.begins_with("network"):
		return _grid_red
	return _grid_servidores


func _on_item_toggled_confirmed(_id_inventario: int, _activo: bool, delta_temp: int, delta_watts: int) -> void:
	_temperatura_cd += delta_temp
	_carga_electrica_actual += delta_watts
	_refresh_header()


func _refresh_header() -> void:
	if _watts_label:
		_watts_label.text = "Consumo: %d / %d W" % [_carga_electrica_actual, _capacidad_watts]
	if _temp_label:
		_temp_label.text = "Temperatura: %d°C" % _temperatura_cd
