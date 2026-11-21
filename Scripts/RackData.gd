extends Resource
class_name RackData
## Espejo de cada elemento del arreglo "racks" de GET /api/usuario/dashboard:
## { "id_rack": 1, "espacio_total": 14, "espacio_usado": 3,
##   "equipos": [ { "id_inventario", "nombreProducto", "categoria",
##                  "slot_inicio", "espacio", "encendido" }, ... ] }

@export var id_rack: int = 0
@export var espacio_usado: int = 0
@export var espacio_total: int = 14
@export var equipos: Array = []
@export var en_alerta: bool = false # temperatura crítica (solo visual)


static func desde_json(json: Dictionary) -> RackData:
	var data := RackData.new()
	data.id_rack = int(json.get("id_rack", 0))
	data.espacio_usado = int(json.get("espacio_usado", 0))
	data.espacio_total = int(json.get("espacio_total", 14))
	data.equipos = json.get("equipos", [])
	return data
