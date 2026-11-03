extends PanelContainer

const Descripciones := preload("res://Scripts/DescripcionesProductos.gd")
const Imagenes := preload("res://Scripts/ImagenesProductos.gd")

@onready var imagen: TextureRect = $Margin/HBox/Imagen
@onready var nombre_label: Label = $Margin/HBox/Info/Nombre
@onready var precio_label: Label = $Margin/HBox/Info/FilaSuperior/Precio
@onready var boton_comprar: Button = $Margin/HBox/Info/FilaSuperior/BotonComprar
@onready var categoria_label: Label = $Margin/HBox/Info/Categoria
@onready var detalle_label: Label = $Margin/HBox/Info/Detalle
@onready var descripcion_label: Label = $Margin/HBox/Info/Descripcion
@onready var advertencia_label: Label = $Margin/HBox/Info/Advertencia

var datos_producto: Dictionary


func _ready() -> void:
	imagen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # pixel art nítido
	boton_comprar.pressed.connect(_on_boton_comprar_pressed)

	# Cualquier cambio global de créditos o espacio puede volver
	# esta tarjeta comprable o no comprable, así que reevaluamos.
	GameData.creditos_actualizados.connect(_actualizar_estado_boton)
	GameData.espacio_actualizado.connect(func(_o, _t): _actualizar_estado_boton())
	GameData.compra_exitosa.connect(_on_compra_resuelta)
	GameData.compra_fallida.connect(_on_compra_resuelta)


func cargar_datos(datos: Dictionary) -> void:
	datos_producto = datos

	nombre_label.text = datos.get("nombreProducto", "Sin Nombre")
	categoria_label.text = datos.get("categoria", "")
	precio_label.text = "$ " + str(datos.get("costo", 0.0))

	# Los números vienen de la BD (Catalogo_Productos); solo se muestran los
	# que el backend mande y sean distintos de cero.
	var partes := PackedStringArray()
	partes.append("⚡ %dW" % int(datos.get("consumoElectrico", 0)))
	partes.append("▤ %dU" % int(datos.get("espacioNecesario", 1)))

	var tflops := int(datos.get("aumento_teraflops", 0))
	if tflops > 0:
		partes.append("+%d TFlops" % tflops)

	var watts := int(datos.get("aumento_watts", 0))
	if watts > 0:
		partes.append("+%dW cap." % watts)

	var ancho_banda := int(datos.get("impacto_anchoDeBanda", 0))
	if ancho_banda > 0:
		partes.append("+%d ancho de banda" % ancho_banda)

	var memoria := int(datos.get("aumento_memoria", 0))
	if memoria > 0:
		partes.append("+%d GB" % memoria)

	var temperatura := int(datos.get("impacto_temperatura", 0))
	if temperatura > 0:
		partes.append("Calor +%d" % temperatura)
	elif temperatura < 0:
		partes.append("Enfría %d" % absi(temperatura))

	detalle_label.text = "   ".join(partes)

	# Descripción: si el backend la manda, esa; si no, la local por nombre.
	var descripcion := ""
	if datos.get("descripcion") != null:
		descripcion = str(datos["descripcion"])
	if descripcion == "":
		descripcion = Descripciones.buscar(str(datos.get("nombreProducto", "")))
	descripcion_label.text = descripcion
	descripcion_label.visible = descripcion != ""

	# Imagen: una "textura" ya cargada tiene prioridad; si no, se busca por nombre.
	if datos.has("textura") and datos["textura"] != null:
		imagen.texture = datos["textura"]
	else:
		imagen.texture = Imagenes.cargar(str(datos.get("nombreProducto", "")))

	_actualizar_estado_boton()


func _actualizar_estado_boton(_arg = null) -> void:
	if datos_producto.is_empty():
		return

	var costo: float = datos_producto.get("costo", 0.0)
	var espacio: int = datos_producto.get("espacioNecesario", 1)
	var permitido := GameData.puede_comprar(costo, espacio)

	boton_comprar.disabled = not permitido

	if permitido:
		advertencia_label.visible = false
	else:
		advertencia_label.visible = true
		advertencia_label.text = GameData.motivo_bloqueo(costo, espacio)


func _on_boton_comprar_pressed() -> void:
	var id_producto: int = datos_producto.get("id_producto", -1)
	var costo: float = datos_producto.get("costo", 0.0)
	var espacio: int = datos_producto.get("espacioNecesario", 1)

	boton_comprar.disabled = true
	GameData.intentar_comprar(id_producto, costo, espacio)


func _on_compra_resuelta(id_producto: int, _mensaje: String) -> void:
	# Solo nos interesa si el resultado corresponde a ESTA tarjeta.
	if id_producto == datos_producto.get("id_producto", -1):
		_actualizar_estado_boton()
