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

# Espejo local de las métricas del jugador SOLO para mostrarlas en el header.
# El valor real siempre vive en la tabla Usuarios del backend.
var _capacidad_watts: int = 0
var _carga_electrica_actual: int = 0
var _temperatura_cd: int = 0


func _ready() -> void:
	_close_button.pressed.connect(_on_close_pressed)
	# TODO: aquí en el futuro se hace GET /api/jugador/estado, se leen
	# usuario.capacidad_watts / usuario.carga_electrica_actual / usuario.temperaturaCD
	# para el header, y por cada fila de "inventario" se arma un
	# InventoryItemData y se llama _spawn_item(data).
	_load_mock_data_for_testing()
	_refresh_header()


func _on_close_pressed() -> void:
	# TODO: normalmente esto oculta el modal y regresa al Dashboard de fondo.
	print("[Inventario] Cerrar presionado (falta conectar con el Dashboard)")


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
	return _grid_servidores # "Servidor" / cualquier categoría no reconocida


func _on_item_toggled_confirmed(_id_inventario: int, _activo: bool, delta_temp: int, delta_watts: int) -> void:
	_temperatura_cd += delta_temp
	_carga_electrica_actual += delta_watts
	_refresh_header()


func _refresh_header() -> void:
	_watts_label.text = "Consumo: %d / %d W" % [_carga_electrica_actual, _capacidad_watts]
	_temp_label.text = "Temperatura: %d°C" % _temperatura_cd


# --- Solo para probar el flujo mientras no hay conexión real a /api/jugador/estado ---

func _load_mock_data_for_testing() -> void:
	_capacidad_watts = 1000
	_carga_electrica_actual = 650
	_temperatura_cd = 42

	var servidor := InventoryItemData.new()
	servidor.id_inventario = 1
	servidor.nombre_producto = "Servidor Rack R710"
	servidor.categoria = "Servidor"
	servidor.aumento_teraflops = 100
	servidor.impacto_temperatura = 8
	servidor.consumo_electrico = 250
	servidor.activo = true
	_spawn_item(servidor)

	var enfriador := InventoryItemData.new()
	enfriador.id_inventario = 2
	enfriador.nombre_producto = "Unidad CRAC"
	enfriador.categoria = "Enfriamiento"
	enfriador.aumento_teraflops = 0
	enfriador.impacto_temperatura = -15
	enfriador.consumo_electrico = 180
	enfriador.activo = true
	_spawn_item(enfriador)

	var router := InventoryItemData.new()
	router.id_inventario = 3
	router.nombre_producto = "Router Core 10G"
	router.categoria = "Red"
	router.aumento_teraflops = 0
	router.impacto_temperatura = 3
	router.consumo_electrico = 60
	router.activo = false
	_spawn_item(router)
