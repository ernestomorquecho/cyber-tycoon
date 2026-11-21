extends Node
## Autoload "GameData": estado sincronizado del jugador + peticiones a la API.
##
## Regla de oro (CLAUDE.md §2): aquí NO se calcula nada de dinero, espacio,
## energía ni temperatura. Todo valor viene del backend y se aplica tal cual con
## aplicar_estado(), que recibe el bloque "estado" que regresan
## GET /api/usuario/dashboard, POST /api/tienda/comprar y las rutas de /api/inventario.

const TIMEOUT_SEGUNDOS := 10.0

# --- Estado del jugador (espejo de lo que manda el servidor) ---
var id_usuario: int = 0
var nombreUsuario: String = ""
var estado_partida: String = "ACTIVE"
var creditos: float = 0.0
var reputacion: int = 0
var teraflops: float = 0.0
var memoria: float = 0.0
var ancho_banda: float = 0.0
var temperatura: float = 0.0
var carga_electrica: float = 0.0
var capacidad_watts: float = 0.0
var espacio_ocupado: int = 0
var espacio_total: int = 0
var racks: Array = []
var estado_recibido: bool = false # false hasta la primera respuesta del servidor

# Token JWT: la única fuente de verdad es Session.jwt_token (la usan también
# Helpdesk y TicketCard). Esta propiedad solo la reenvía para no romper código viejo.
var token_jwt: String:
	get:
		return Session.jwt_token
	set(valor):
		Session.jwt_token = valor

# --- Señales ---
signal estado_actualizado()                         # cambió cualquier métrica o rack
signal creditos_actualizados(nuevo_saldo: float)
signal espacio_actualizado(ocupado: int, total: int)
signal sesion_expirada()                            # 401/403: hay que volver al Login
signal catalogo_recibido(productos: Array)
signal catalogo_error(mensaje: String)
signal compra_exitosa(id_producto: int, mensaje: String)
signal compra_fallida(id_producto: int, mensaje: String)
signal inventario_recibido(items: Array)
signal inventario_error(mensaje: String)
signal equipo_cambiado(id_inventario: int, exito: bool, encendido: bool, mensaje: String)
signal equipo_vendido(id_inventario: int, exito: bool, mensaje: String)

var _dashboard_en_curso: bool = false


# ------------------------------------------------------------
# Sesión
# ------------------------------------------------------------
func hay_sesion() -> bool:
	return not Session.jwt_token.is_empty()


func iniciar_sesion(token: String, usuario: Dictionary) -> void:
	Session.jwt_token = token
	id_usuario = int(usuario.get("id_usuario", 0))
	nombreUsuario = str(usuario.get("nombreUsuario", ""))
	estado_recibido = false


func cerrar_sesion() -> void:
	Session.jwt_token = ""
	id_usuario = 0
	nombreUsuario = ""
	estado_recibido = false
	racks = []


# ------------------------------------------------------------
# Estado (lo único que mueve las métricas en el cliente)
# ------------------------------------------------------------
func aplicar_estado(estado: Dictionary) -> void:
	if estado.is_empty():
		return
	var m: Dictionary = estado.get("metricas", {})
	estado_partida = str(estado.get("estado_partida", estado_partida))
	creditos = float(m.get("creditos", creditos))
	reputacion = int(m.get("reputacion", reputacion))
	teraflops = float(m.get("teraflops", teraflops))
	memoria = float(m.get("memoria", memoria))
	ancho_banda = float(m.get("ancho_banda", ancho_banda))
	temperatura = float(m.get("temperatura", temperatura))
	carga_electrica = float(m.get("carga_electrica", carga_electrica))
	capacidad_watts = float(m.get("capacidad_watts", capacidad_watts))
	espacio_ocupado = int(m.get("espacio_usado", espacio_ocupado))
	espacio_total = int(m.get("espacio_total", espacio_total))
	racks = estado.get("racks", racks)
	estado_recibido = true

	creditos_actualizados.emit(creditos)
	espacio_actualizado.emit(espacio_ocupado, espacio_total)
	estado_actualizado.emit()


## GET /api/usuario/dashboard. No dispara otra si la anterior no ha respondido.
func solicitar_dashboard() -> void:
	if _dashboard_en_curso or not hay_sesion():
		return
	_dashboard_en_curso = true
	_api(HTTPClient.METHOD_GET, "/api/usuario/dashboard", null, func(codigo: int, json):
		_dashboard_en_curso = false
		if codigo == 200 and json is Dictionary:
			if json.has("nombreUsuario"):
				nombreUsuario = str(json["nombreUsuario"])
			aplicar_estado(json)
		elif codigo != 401 and codigo != 403:
			push_warning("[GameData] No se pudo actualizar el dashboard: %s" % _mensaje_error(codigo, json, "sin respuesta"))
	)


# ------------------------------------------------------------
# Tienda
# ------------------------------------------------------------
func solicitar_catalogo() -> void:
	_api(HTTPClient.METHOD_GET, "/api/tienda/catalogo", null, func(codigo: int, json):
		if codigo == 200 and json is Array:
			catalogo_recibido.emit(json)
		elif codigo == 200 and json is Dictionary and json.has("productos"):
			catalogo_recibido.emit(json["productos"])
		else:
			catalogo_error.emit(_mensaje_error(codigo, json, "No se pudo obtener el catálogo."))
	, false)


## Pista SOLO visual para pintar el botón de la tarjeta. Quien decide de verdad
## si se puede comprar es POST /api/tienda/comprar (espacio contiguo, energía...).
func puede_comprar(costo: float, espacio_necesario: int) -> bool:
	return motivo_bloqueo(costo, espacio_necesario).is_empty()


func motivo_bloqueo(costo: float, espacio_necesario: int) -> String:
	if not estado_recibido:
		return "" # todavía sin datos del servidor: que él decida
	if creditos < costo:
		return "Créditos insuficientes"
	if espacio_ocupado + espacio_necesario > espacio_total:
		return "No hay espacio en el rack"
	return ""


## Cada compra usa su propia petición: dos clics en productos distintos ya no se
## cancelan entre sí (antes la segunda cancelaba la primera aunque el servidor
## sí la hubiera cobrado).
func intentar_comprar(id_producto: int, _costo: float = 0.0, _espacio_necesario: int = 0) -> void:
	if not hay_sesion():
		compra_fallida.emit(id_producto, "Sesión no iniciada. Vuelve a entrar desde el Login.")
		sesion_expirada.emit()
		return
	_api(HTTPClient.METHOD_POST, "/api/tienda/comprar", {"id_producto": id_producto}, func(codigo: int, json):
		if codigo == 200 and json is Dictionary:
			aplicar_estado(json.get("estado", {}))
			compra_exitosa.emit(id_producto, str(json.get("mensaje", "¡Compra realizada!")))
		else:
			compra_fallida.emit(id_producto, _mensaje_error(codigo, json, "No se pudo completar la compra."))
	)


# ------------------------------------------------------------
# Inventario
# ------------------------------------------------------------
func solicitar_inventario() -> void:
	_api(HTTPClient.METHOD_GET, "/api/inventario", null, func(codigo: int, json):
		if codigo == 200 and json is Array:
			inventario_recibido.emit(json)
		else:
			inventario_error.emit(_mensaje_error(codigo, json, "No se pudo obtener el inventario."))
	)


func cambiar_estado_equipo(id_inventario: int, encendido: bool) -> void:
	var ruta := "/api/inventario/%d/estado" % id_inventario
	_api(HTTPClient.METHOD_POST, ruta, {"encendido": encendido}, func(codigo: int, json):
		if codigo == 200 and json is Dictionary:
			aplicar_estado(json.get("estado", {}))
			equipo_cambiado.emit(id_inventario, true, encendido, str(json.get("mensaje", "")))
		else:
			equipo_cambiado.emit(id_inventario, false, not encendido, _mensaje_error(codigo, json, "No se pudo cambiar el equipo."))
	)


func vender_equipo(id_inventario: int) -> void:
	var ruta := "/api/inventario/%d/vender" % id_inventario
	_api(HTTPClient.METHOD_POST, ruta, {}, func(codigo: int, json):
		if codigo == 200 and json is Dictionary:
			aplicar_estado(json.get("estado", {}))
			equipo_vendido.emit(id_inventario, true, str(json.get("mensaje", "Equipo vendido")))
		else:
			equipo_vendido.emit(id_inventario, false, _mensaje_error(codigo, json, "No se pudo vender el equipo."))
	)


# ------------------------------------------------------------
# Cliente HTTP genérico: una petición = un HTTPRequest temporal
# ------------------------------------------------------------
## al_terminar recibe (codigo_http: int, json: Variant). codigo 0 = sin conexión/timeout.
func _api(metodo: HTTPClient.Method, ruta: String, cuerpo: Variant, al_terminar: Callable, con_token: bool = true) -> void:
	var http := HTTPRequest.new()
	http.timeout = TIMEOUT_SEGUNDOS
	add_child(http)

	var headers := PackedStringArray(["Content-Type: application/json"])
	if con_token:
		headers = Session.auth_headers()

	http.request_completed.connect(func(_result: int, codigo: int, _h: PackedStringArray, body: PackedByteArray):
		http.queue_free()
		var json = null
		if not body.is_empty():
			json = JSON.parse_string(body.get_string_from_utf8())
		if con_token and (codigo == 401 or codigo == 403):
			sesion_expirada.emit()
		al_terminar.call(codigo, json)
	)

	var datos := "" if cuerpo == null else JSON.stringify(cuerpo)
	var err := http.request(Session.base_url + ruta, headers, metodo, datos)
	if err != OK:
		http.queue_free()
		al_terminar.call(0, null)


func _mensaje_error(codigo: int, json: Variant, por_defecto: String) -> String:
	if json is Dictionary and json.has("error"):
		return str(json["error"])
	if codigo == 0:
		return "No se pudo conectar con el servidor."
	return "%s (código %d)" % [por_defecto, codigo]
