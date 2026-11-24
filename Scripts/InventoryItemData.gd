extends Resource
class_name InventoryItemData
## Espeja cada fila de GET /api/inventario:
## id_inventario, nombreProducto, categoria, encendido, rack_numero, slot_inicio,
## precio_venta y los aportes del producto (TFLOPS, RAM, watts, calor...).

@export var id_inventario: int = 0
@export var nombre_producto: String = ""
@export var categoria: String = "Servidor" # "Servidor" | "Refrigeracion" | "Energia" | "Redes"
@export var icon: Texture2D

@export var aumento_teraflops: int = 0
@export var aumento_memoria: int = 0
@export var ancho_banda: int = 0
@export var aumento_watts: int = 0
@export var impacto_temperatura: int = 0 # negativo = enfría, positivo = calienta
@export var consumo_electrico: int = 0

@export var activo: bool = true          # Inventario_Usuario.encendido
@export var sobrecalentado: bool = false # motivo_apagado == "OVERHEATED" (apagado de emergencia)
@export var sin_energia: bool = false    # motivo_apagado == "BROWNOUT" (apagón parcial)
@export var rack_numero: int = 0
@export var slot_inicio: int = 0
@export var precio_venta: float = 0.0    # lo que devuelve el servidor al vender


static func desde_json(fila: Dictionary) -> InventoryItemData:
	var data := InventoryItemData.new()
	data.id_inventario = int(fila.get("id_inventario", 0))
	data.nombre_producto = str(fila.get("nombreProducto", "Hardware"))
	data.categoria = str(fila.get("categoria", "Servidor"))
	data.aumento_teraflops = int(fila.get("aumento_teraflops", 0))
	data.aumento_memoria = int(fila.get("aumento_memoria", 0))
	data.ancho_banda = int(fila.get("impacto_anchoDeBanda", 0))
	data.aumento_watts = int(fila.get("aumento_watts", 0))
	data.impacto_temperatura = int(fila.get("impacto_temperatura", 0))
	data.consumo_electrico = int(fila.get("consumoElectrico", 0))
	data.activo = bool(fila.get("encendido", true))
	data.sobrecalentado = str(fila.get("motivo_apagado", "")) == "OVERHEATED"
	data.sin_energia = str(fila.get("motivo_apagado", "")) == "BROWNOUT"
	var rack = fila.get("rack_numero")
	data.rack_numero = int(rack) if rack != null else 0
	var slot = fila.get("slot_inicio")
	data.slot_inicio = int(slot) if slot != null else 0
	data.precio_venta = float(fila.get("precio_venta", 0.0))
	return data
