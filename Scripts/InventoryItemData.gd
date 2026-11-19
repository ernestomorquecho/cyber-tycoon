extends Resource
class_name InventoryItemData
## Espeja el JOIN que ya regresa GET /api/jugador/estado (arreglo "inventario"
## dentro de la respuesta), fila por fila:
## iu.id_inventario, iu.fecha_compra, cp.nombreProducto, cp.categoria,
## cp.aumento_teraflops, cp.impacto_temperatura, cp.consumoElectrico

@export var id_inventario: int = 0
@export var nombre_producto: String = ""
@export var categoria: String = "Servidor" # "Servidor" | "Enfriamiento" | "Red" según el backend
@export var icon: Texture2D # placeholder hasta que haya assets

@export var aumento_teraflops: int = 0
@export var impacto_temperatura: int = 0 # negativo = enfría, positivo = calienta
@export var consumo_electrico: int = 0

# El backend todavía NO expone "estado_item" en /api/jugador/estado ni un
# endpoint para cambiarlo (ver TODO en InventoryItemCard.gd). Por ahora se usa
# solo para pintar el switch en su posición correcta al cargar la pantalla.
@export var activo: bool = true
