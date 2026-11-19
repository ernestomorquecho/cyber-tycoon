extends RefCounted
## Imagen (sprite PNG) de cada producto del catálogo.
##
## Igual que las descripciones, se busca por NOMBRE (sin el "(1U)") y no por id,
## así funciona con lo que mande el backend aunque cambie el orden de los ids.
## OJO: Windows no distingue mayúsculas en rutas, pero Linux/Android/el .pck
## exportado SÍ. Las rutas deben coincidir letra por letra con el archivo.

const Descripciones := preload("res://Scripts/DescripcionesProductos.gd")

const IMAGENES := {
	"Dull PowerBorde R110": "res://Escenas/Inventario/producto_1.png",
	"HachePe ProLiante DL360": "res://Escenas/Inventario/producto_2.png",
	"Lenorvo OverThink SR650": "res://Escenas/Inventario/producto_3.png",
	"HyperMicro MegaBlade X12": "res://Escenas/Inventario/producto_4.png",
	"Envidia DGX-9000 TensorHorno": "res://Escenas/Inventario/producto_5.png",
	"NocturnaBúho FanTray Industrial": "res://Escenas/Inventario/producto_6.png",
	"Corsario HydroLeak AIO": "res://Escenas/Inventario/producto_7.png",
	"VertiFrío Liebert InRow": "res://Escenas/Inventario/producto_8.png",
	"TermoTake Chiller H2O-Max": "res://Escenas/Inventario/producto_9.png",
	"SubMarino Pod Dieléctrico": "res://Escenas/Inventario/producto_10.png",
	"TrippCorto Regleta PDU-800": "res://Escenas/Inventario/trippCorto.png",
	"APagón Smart-UPS 1500VA": "res://Escenas/Inventario/aPagon.png",
	"Tragón 9PX Doble Conversión": "res://Escenas/Inventario/tragon.png",
	"Chispazoneider Symmetra Li-Ion": "res://Escenas/Inventario/chispazoneider.png",
	"Tésla MegaPila Nuclear-Pack": "res://Escenas/Inventario/teslaPila.png",
	"MacroTik RouterBordo HEX-24": "res://Escenas/Inventario/macroTik.png",
	"Chisco Catalizador 2960-Giga": "res://Escenas/Inventario/chisco.png",
	"FuerteNet FortiMuro 600F": "res://Escenas/Inventario/fuerteNet.png",
	"Arisca EtherSwitch 100G-Spine": "res://Escenas/Inventario/arisca.png",
	"Junípero PTX-TeraCore Óptico": "res://Escenas/Inventario/junipero.png",
}


## Ruta de la imagen del producto, o "" si el nombre no está en el mapa.
static func ruta(nombre_producto: String) -> String:
	var buscada := Descripciones.clave(nombre_producto)
	for nombre in IMAGENES:
		if Descripciones.clave(nombre) == buscada:
			return IMAGENES[nombre]
	return ""


## Textura lista para ponerle a un TextureRect, o null si no se encuentra
## (en ese caso deja un aviso en la consola, la tarjeta no se rompe).
static func cargar(nombre_producto: String) -> Texture2D:
	var r := ruta(nombre_producto)
	if r == "":
		return null
	if not ResourceLoader.exists(r):
		push_warning("Imagen de producto no encontrada: %s" % r)
		return null
	return load(r) as Texture2D
