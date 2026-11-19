extends PanelContainer

const Descripciones := preload("res://Scripts/DescripcionesProductos.gd")
const Imagenes := preload("res://Scripts/ImagenesProductos.gd")
const Estilo := preload("res://Scripts/EstiloTienda.gd")

@onready var acento_rect: ColorRect = %Acento
@onready var marco_imagen: PanelContainer = %MarcoImagen
@onready var imagen: TextureRect = %Imagen
@onready var nombre_label: Label = %Nombre
@onready var categoria_label: Label = %Categoria
@onready var detalle_label: RichTextLabel = %Detalle
@onready var descripcion_label: Label = %Descripcion
@onready var advertencia_label: Label = %Advertencia
@onready var precio_label: Label = %Precio
@onready var boton_comprar: Button = %BotonComprar

var datos_producto: Dictionary

## Grupo de la categoría ("servidores", "refrigeracion", "energia", "redes",
## "otros"). Lo lee catalogo.gd para filtrar.
var grupo: String = "otros"


func _ready() -> void:
	imagen.texture_filter = CanvasItem.TEXTURE_FILTER_NEAREST # pixel art nítido
	add_theme_stylebox_override("panel", Estilo.caja(Estilo.FONDO_TARJETA, Estilo.BORDE, 2))
	boton_comprar.pressed.connect(_on_boton_comprar_pressed)

	# Cualquier cambio global de créditos o espacio puede volver esta tarjeta
	# comprable o no comprable, así que se reevalúa. Se conectan métodos (no
	# lambdas) para que se desconecten solos cuando la tarjeta se libere.
	GameData.creditos_actualizados.connect(_actualizar_estado_boton)
	GameData.espacio_actualizado.connect(_on_espacio_actualizado)
	GameData.compra_exitosa.connect(_on_compra_resuelta)
	GameData.compra_fallida.connect(_on_compra_resuelta)


func cargar_datos(datos: Dictionary) -> void:
	datos_producto = datos

	grupo = Estilo.grupo_de(datos)
	var acento: Color = Estilo.color_de(grupo)
	acento_rect.color = acento
	marco_imagen.add_theme_stylebox_override(
		"panel", Estilo.caja(Estilo.FONDO_IMAGEN, acento.darkened(0.35), 2, 6))
	categoria_label.add_theme_color_override("font_color", acento)
	Estilo.aplicar_boton(boton_comprar, acento)

	nombre_label.text = str(datos.get("nombreProducto", "Sin nombre"))
	categoria_label.text = str(datos.get("categoria", "")).to_upper()
	precio_label.text = "$ " + Estilo.formato_dinero(float(datos.get("costo", 0.0)))

	detalle_label.text = "   ".join(_partes_detalle(datos, acento))

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


# Datos técnicos con color (BBCode). Los números vienen de la BD; solo se
# muestran los que el backend mande y sean distintos de cero.
func _partes_detalle(datos: Dictionary, acento: Color) -> PackedStringArray:
	var partes := PackedStringArray()
	partes.append(_chip("⚡ %d W" % int(datos.get("consumoElectrico", 0)), Estilo.STAT_CONSUMO))
	partes.append(_chip("▤ %d U" % int(datos.get("espacioNecesario", 1)), Estilo.STAT_ESPACIO))

	var tflops := int(datos.get("aumento_teraflops", 0))
	if tflops > 0:
		partes.append(_chip("+%d TFlops" % tflops, Estilo.color_de("servidores")))

	var watts := int(datos.get("aumento_watts", 0))
	if watts > 0:
		partes.append(_chip("+%d W cap." % watts, Estilo.color_de("energia")))

	var ancho_banda := int(datos.get("impacto_anchoDeBanda", 0))
	if ancho_banda > 0:
		partes.append(_chip("+%d ancho de banda" % ancho_banda, Estilo.color_de("redes")))

	var memoria := int(datos.get("aumento_memoria", 0))
	if memoria > 0:
		partes.append(_chip("+%d GB" % memoria, acento))

	var temperatura := int(datos.get("impacto_temperatura", 0))
	if temperatura > 0:
		partes.append(_chip("Calor +%d" % temperatura, Estilo.PELIGRO))
	elif temperatura < 0:
		partes.append(_chip("Enfría %d" % absi(temperatura), Estilo.color_de("refrigeracion")))

	return partes


func _chip(texto: String, color: Color) -> String:
	return "[color=#%s]%s[/color]" % [color.to_html(false), texto]


func _actualizar_estado_boton(_arg = null) -> void:
	if datos_producto.is_empty():
		return

	var costo: float = float(datos_producto.get("costo", 0.0))
	var espacio: int = int(datos_producto.get("espacioNecesario", 1))
	var permitido := GameData.puede_comprar(costo, espacio)

	boton_comprar.disabled = not permitido

	if permitido:
		advertencia_label.visible = false
	else:
		advertencia_label.visible = true
		advertencia_label.text = GameData.motivo_bloqueo(costo, espacio)


func _on_espacio_actualizado(_ocupado: int, _total: int) -> void:
	_actualizar_estado_boton()


func _on_boton_comprar_pressed() -> void:
	var id_producto: int = int(datos_producto.get("id_producto", -1))
	var costo: float = float(datos_producto.get("costo", 0.0))
	var espacio: int = int(datos_producto.get("espacioNecesario", 1))

	boton_comprar.disabled = true
	GameData.intentar_comprar(id_producto, costo, espacio)


func _on_compra_resuelta(id_producto: int, _mensaje: String) -> void:
	if id_producto == int(datos_producto.get("id_producto", -1)):
		_actualizar_estado_boton()
