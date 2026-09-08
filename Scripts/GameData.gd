extends Node

# ============================================================
# GameData.gd — Autoload / Singleton
# Responsable de: estado global del jugador + comunicación HTTP
# con el backend. Godot NUNCA calcula el resultado de una compra,
# solo envía la petición y aplica lo que la API confirme.
# ============================================================

# TODO-BACKEND: ajustar la URL base al host real de tu servidor
# (localhost para pruebas, o la URL de despliegue).
const API_BASE_URL := "http://127.0.0.1:3000/api/tienda"

# --- Estado del jugador (reflejo de la tabla 'Usuarios') ---
var id_usuario: int = 1
var nombreUsuario: String = "Jugador1"
var creditos: float = 10000.0
var espacio_ocupado: int = 2
var espacio_total: int = 16

# --- Señales que la UI escucha para refrescarse sola ---
signal creditos_actualizados(nuevo_saldo: float)
signal espacio_actualizado(ocupado: int, total: int)
signal catalogo_recibido(productos: Array)
signal catalogo_error(mensaje: String)
signal compra_exitosa(id_producto: int, mensaje: String)
signal compra_fallida(id_producto: int, mensaje: String)

var _http_productos: HTTPRequest
var _http_comprar: HTTPRequest

# id del producto que está actualmente "en vuelo" hacia la API,
# para poder avisarle a la tarjeta correcta si la compra falla.
var _id_producto_en_proceso: int = -1


func _ready() -> void:
	_http_productos = HTTPRequest.new()
	add_child(_http_productos)
	_http_productos.request_completed.connect(_on_productos_completed)

	_http_comprar = HTTPRequest.new()
	add_child(_http_comprar)
	_http_comprar.request_completed.connect(_on_comprar_completed)


# ------------------------------------------------------------
# GET /api/tienda/productos
# ------------------------------------------------------------
func solicitar_catalogo() -> void:
	var err := _http_productos.request(API_BASE_URL + "/productos")
	if err != OK:
		catalogo_error.emit("No se pudo conectar con el servidor (código %s)." % err)


func _on_productos_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code != 200:
		catalogo_error.emit("El servidor respondió con error %s al pedir el catálogo." % response_code)
		return

	if body.is_empty():
		catalogo_error.emit("El servidor no respondió (¿está corriendo?).")
		return

	var json = JSON.parse_string(body.get_string_from_utf8())

	# TODO-BACKEND: confirmar si /productos devuelve un Array directo
	# o un objeto tipo { "productos": [...] }. Soporto ambos casos.
	if json is Array:
		catalogo_recibido.emit(json)
	elif json is Dictionary and json.has("productos"):
		catalogo_recibido.emit(json["productos"])
	else:
		catalogo_error.emit("Formato de respuesta de /productos no reconocido.")


# ------------------------------------------------------------
# Validación LOCAL (solo para UX: habilitar/deshabilitar botón).
# La API sigue siendo la única autoridad sobre si la compra
# realmente se procesa o no.
# ------------------------------------------------------------
func puede_comprar(costo: float, espacio_necesario: int) -> bool:
	var alcanza_credito := creditos >= costo
	var alcanza_espacio := (espacio_ocupado + espacio_necesario) <= espacio_total
	return alcanza_credito and alcanza_espacio


func motivo_bloqueo(costo: float, espacio_necesario: int) -> String:
	if creditos < costo:
		return "Créditos insuficientes"
	if (espacio_ocupado + espacio_necesario) > espacio_total:
		return "No hay espacio en el rack"
	return ""


# ------------------------------------------------------------
# POST /api/tienda/comprar
# ------------------------------------------------------------
func intentar_comprar(id_producto: int, costo: float, espacio_necesario: int) -> void:
	# Chequeo local solo para no disparar una petición inútil.
	if not puede_comprar(costo, espacio_necesario):
		compra_fallida.emit(id_producto, motivo_bloqueo(costo, espacio_necesario))
		return

	_id_producto_en_proceso = id_producto

	var payload := {
		"id_producto": id_producto,
		"id_usuario": id_usuario,
	}
	var headers := ["Content-Type: application/json"]
	var body := JSON.stringify(payload)

	var err := _http_comprar.request(
		API_BASE_URL + "/comprar", headers, HTTPClient.METHOD_POST, body
	)
	if err != OK:
		compra_fallida.emit(id_producto, "No se pudo conectar con el servidor.")


func _on_comprar_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	var id_producto := _id_producto_en_proceso
	_id_producto_en_proceso = -1

	if body.is_empty():
		compra_fallida.emit(id_producto, "No se pudo conectar con el servidor.")
		return

	var json = JSON.parse_string(body.get_string_from_utf8())

	if response_code == 200 and json is Dictionary:
		# TODO-BACKEND: confirmar nombres exactos de estos campos
		# en la respuesta real de POST /comprar.
		creditos = json.get("creditos", creditos)
		espacio_ocupado = json.get("espacio_ocupado", espacio_ocupado)

		creditos_actualizados.emit(creditos)
		espacio_actualizado.emit(espacio_ocupado, espacio_total)
		compra_exitosa.emit(id_producto, json.get("mensaje", "¡Compra realizada!"))
	else:
		var mensaje := "No se pudo completar la compra."
		if json is Dictionary and json.has("mensaje"):
			mensaje = json["mensaje"]
		compra_fallida.emit(id_producto, mensaje)
