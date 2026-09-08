extends Resource
class_name RackData
## Espejo de cada elemento del arreglo "racks" que according a la spec regresa
## GET /api/usuario/dashboard: { "id_rack": 1, "espacio_usado": 8 }

@export var id_rack: int = 0
@export var espacio_usado: int = 0
# La spec no manda un "espacio_total" por rack; lo dejamos fijo aquí como
# valor visual hasta que el backend decida si lo agrega al JSON.
@export var espacio_total: int = 8
@export var en_alerta: bool = false # sobrecarga o ciberataque activo en este rack
