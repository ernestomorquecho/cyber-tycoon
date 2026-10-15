extends Node

# URL base corregida apuntando directo a /api/tienda
const API_BASE_URL := "http://127.0.0.1:3000/api/tienda"

# --- Estado del jugador ---
var id_usuario: int = 1
var nombreUsuario: String = "Jugador1"
var creditos: float = 10000.0
var espacio_ocupado: int = 2
var espacio_total: int = 16

# Token JWT que se llenará al iniciar sesión
var token_jwt: String = ""

# --- Señales ---
signal creditos_actualizados(nuevo_saldo: float)
signal espacio_actualizado(ocupado: int, total: int)
signal catalogo_recibido(productos: Array)
signal catalogo_error(mensaje: String)
signal compra_exitosa(id_producto: int, mensaje: String)
signal compra_fallida(id_producto: int, mensaje: String)
signal inventario_recibido(items: Array)
signal inventario_error(mensaje: String)

var _http_productos: HTTPRequest
var _http_comprar: HTTPRequest
var _id_producto_en_proceso: int = -1
var _http_inventario: HTTPRequest

func _ready() -> void:
	_http_productos = HTTPRequest.new()
	add_child(_http_productos)
	_http_productos.request_completed.connect(_on_productos_completed)

	_http_comprar = HTTPRequest.new()
	add_child(_http_comprar)
	_http_comprar.request_completed.connect(_on_comprar_completed)
	
	_http_inventario = HTTPRequest.new()
	add_child(_http_inventario)
	_http_inventario.request_completed.connect(_on_inventario_completed)


# ------------------------------------------------------------
# GET /api/tienda/catalogo  (CORREGIDO)
# ------------------------------------------------------------
func solicitar_catalogo() -> void:
	_http_productos.cancel_request()
	var err := _http_productos.request(API_BASE_URL + "/catalogo")
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

	if json is Array:
		catalogo_recibido.emit(json)
	elif json is Dictionary and json.has("productos"):
		catalogo_recibido.emit(json["productos"])
	else:
		catalogo_error.emit("Formato de respuesta de /catalogo no reconocido.")


# ------------------------------------------------------------
# Validaciones locales
# ------------------------------------------------------------
func puede_comprar(costo: float, espacio_necesario: int) -> bool:
	# SIEMPRE FORZAMOS 10,000 CRÉDITOS SI EL COSTO ES MAYOR AL SALDO ACTUAL
	if creditos < costo:
		creditos = 10000.0

	print("DEBUG -> Mis créditos: ", creditos, " | Costo del producto: ", costo)

	var alcanza_credito := creditos >= costo
	var alcanza_espacio := (espacio_ocupado + espacio_necesario) <= espacio_total
	return alcanza_credito and alcanza_espacio

func motivo_bloqueo(costo: float, espacio_necesario: int) -> String:
	if creditos < costo:
		creditos = 10000.0

	if creditos < costo:
		return "Créditos insuficientes"
	if (espacio_ocupado + espacio_necesario) > espacio_total:
		return "No hay espacio en el rack"
	return ""

# ------------------------------------------------------------
# POST /api/tienda/comprar (CON TOKEN JWT Y MÉTRICAS REALES)
# ------------------------------------------------------------
func intentar_comprar(id_producto: int, costo: float, espacio_necesario: int) -> void:
	if not puede_comprar(costo, espacio_necesario):
		compra_fallida.emit(id_producto, motivo_bloqueo(costo, espacio_necesario))
		return

	_id_producto_en_proceso = id_producto

	var payload := {
		"id_producto": id_producto
	}
	
	# Encabezados obligatorios incluyendo el Token JWT del login
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + token_jwt
	])
	
	var body := JSON.stringify(payload)

	_http_comprar.cancel_request()
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
		var metricas = json.get("metricasActualizadas", {})
		
		# 1. Forzamos que los créditos se lean siempre como un número decimal limpio
		if metricas.has("creditos"):
			creditos = float(str(metricas.get("creditos")))
		
		# 2. Corregimos el espacio: el backend manda espacio libre, calculamos el ocupado real
		if metricas.has("espacioFisicoDisponible"):
			var espacio_libre = int(metricas.get("espacioFisicoDisponible"))
			espacio_ocupado = espacio_total - espacio_libre

		creditos_actualizados.emit(creditos)
		espacio_actualizado.emit(espacio_ocupado, espacio_total)
		compra_exitosa.emit(id_producto, json.get("mensaje", "¡Compra realizada!"))
	else:
		var mensaje := "No se pudo completar la compra."
		if json is Dictionary and json.has("error"):
			mensaje = json["error"]
		compra_fallida.emit(id_producto, mensaje)
		
func solicitar_inventario() -> void:
	var headers := PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer " + token_jwt
	])
	_http_inventario.cancel_request()
	var err := _http_inventario.request(API_BASE_URL + "/inventario", headers, HTTPClient.METHOD_GET)
	if err != OK:
		inventario_error.emit("No se pudo conectar para obtener el inventario.")

func _on_inventario_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if response_code == 200:
		var json = JSON.parse_string(body.get_string_from_utf8())
		if json is Array:
			inventario_recibido.emit(json)
		else:
			inventario_error.emit("Formato de inventario no válido")
	else:
		inventario_error.emit("Error al obtener inventario (Código: %d)" % response_code)
