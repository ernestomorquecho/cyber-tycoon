extends SceneTree
## Prueba de conexión Godot <-> Backend de Cyber Tycoon.
## Ejecutar (desde cualquier carpeta):
##   Godot_console.exe --headless --path <carpeta frontend> --script res://tests/prueba_conexion.gd
## No modifica nada del juego; crea un profesor/clase/alumno de prueba en la BD.

const BASE := "http://127.0.0.1:3000"
const Imagenes := preload("res://Scripts/ImagenesProductos.gd")

var _http: HTTPRequest
var _resumen: Array[String] = []


func _initialize() -> void:
	_http = HTTPRequest.new()
	_http.timeout = 10.0
	root.add_child(_http)
	_correr.call_deferred()


func _req(metodo: HTTPClient.Method, ruta: String, cuerpo: Variant = null, token: String = "") -> Dictionary:
	var headers: PackedStringArray = ["Content-Type: application/json"]
	if token != "":
		headers.append("Authorization: Bearer " + token)
	var datos: String = "" if cuerpo == null else JSON.stringify(cuerpo)
	var err: Error = _http.request(BASE + ruta, headers, metodo, datos)
	if err != OK:
		return {"codigo": -1, "datos": null, "error": "request() falló: %s" % error_string(err)}
	var r: Array = await _http.request_completed
	var resultado: int = r[0]
	var codigo: int = r[1]
	var texto: String = (r[3] as PackedByteArray).get_string_from_utf8()
	if resultado != HTTPRequest.RESULT_SUCCESS:
		return {"codigo": -1, "datos": null, "error": "Sin conexión (resultado HTTPRequest=%d)" % resultado}
	return {"codigo": codigo, "datos": JSON.parse_string(texto), "crudo": texto.left(300)}


func _paso(nombre: String, r: Dictionary, esperado: int = 200) -> bool:
	var ok: bool = r.codigo == esperado
	var linea: String = "%s %-38s -> HTTP %d" % ["[OK]  " if ok else "[FALLA]", nombre, r.codigo]
	print(linea)
	if not ok:
		print("        respuesta: ", r.get("error", r.get("crudo", "")))
	_resumen.append(linea)
	return ok


func _clave_maestra() -> String:
	var ruta: String = ProjectSettings.globalize_path("res://").path_join("../backend/.env")
	var f: FileAccess = FileAccess.open(ruta, FileAccess.READ)
	if f == null:
		return ""
	for linea: String in f.get_as_text().split("\n"):
		if linea.begins_with("ADMIN_REGISTRATION_KEY="):
			return linea.trim_prefix("ADMIN_REGISTRATION_KEY=").strip_edges().trim_prefix("\"").trim_suffix("\"")
	return ""


func _correr() -> void:
	print("\n===== PRUEBA DE CONEXIÓN CYBER TYCOON (%s) =====\n" % BASE)
	var sufijo: String = str(Time.get_unix_time_from_system()).left(10)

	# 1. Salud
	var r: Dictionary = await _req(HTTPClient.METHOD_GET, "/api/health")
	if not _paso("GET /api/health", r):
		print("\nEl backend no responde. Revisa que Docker esté arriba y el puerto 3000 expuesto.")
		quit(1)
		return

	# 2. Catálogo (público)
	r = await _req(HTTPClient.METHOD_GET, "/api/tienda/catalogo")
	var id_producto: int = -1
	if _paso("GET /api/tienda/catalogo", r) and r.datos is Array:
		var productos: Array = r.datos
		print("        %d productos en la BD" % productos.size())
		for p: Dictionary in productos:
			var nombre: String = str(p.get("nombreProducto", "?"))
			var limpio: String = nombre.get_slice(" (", 0)
			var con_imagen: bool = Imagenes.IMAGENES.has(limpio)
			print("        - #%s %-40s imagen en frontend: %s" % [str(p.get("id_producto")), nombre, "sí" if con_imagen else "NO"])
		if productos.size() > 0:
			id_producto = int(productos[0].get("id_producto", -1))

	# 3. Profesor demo de init.sql
	r = await _req(HTTPClient.METHOD_POST, "/api/profesor/login",
		{"correo": "carlos@universidad.edu", "password": "PasswordDocente2026"})
	_paso("POST /api/profesor/login (demo init.sql)", r)

	# 4. Profesor de prueba
	var correo: String = "prueba%s@cybertycoon.test" % sufijo
	var clave: String = _clave_maestra()
	if clave == "":
		print("[AVISO] No encontré ADMIN_REGISTRATION_KEY en backend/.env")
	r = await _req(HTTPClient.METHOD_POST, "/api/profesor/registro",
		{"nombre": "Profe Prueba", "correo": correo, "password": "Prueba12345!", "clave_maestra": clave})
	_paso("POST /api/profesor/registro", r, 201)
	r = await _req(HTTPClient.METHOD_POST, "/api/profesor/login", {"correo": correo, "password": "Prueba12345!"})
	if not _paso("POST /api/profesor/login (prueba)", r) or not r.datos is Dictionary:
		_fin()
		return
	var token_prof: String = str(r.datos.get("token", ""))

	# 5. Clase + alumno
	r = await _req(HTTPClient.METHOD_POST, "/api/profesor/clases", {"nombre_clase": "Clase prueba " + sufijo}, token_prof)
	if not _paso("POST /api/profesor/clases", r, 201):
		_fin()
		return
	var id_clase: int = int(r.datos.get("id_clase", 0))
	var codigo: String = str(r.datos.get("codigo_clase", ""))
	var alumno: String = "alumno" + sufijo
	r = await _req(HTTPClient.METHOD_POST, "/api/profesor/clases/%d/estudiantes" % id_clase, {"nombreUsuario": alumno}, token_prof)
	_paso("POST /api/profesor/clases/:id/estudiantes", r, 201)

	# 6. Login del jugador (igual que login.gd)
	r = await _req(HTTPClient.METHOD_POST, "/api/auth/login", {"nombreUsuario": alumno, "codigo_clase": codigo})
	if not _paso("POST /api/auth/login (jugador)", r) or not r.datos is Dictionary:
		_fin()
		return
	var token: String = str(r.datos.get("token", ""))
	print("        usuario recibido: ", JSON.stringify(r.datos.get("usuario", {})))

	# 7. Endpoints del jugador
	r = await _req(HTTPClient.METHOD_GET, "/api/jugador/estado", null, token)
	_paso("GET /api/jugador/estado", r)
	if id_producto != -1:
		r = await _req(HTTPClient.METHOD_POST, "/api/tienda/comprar", {"id_producto": id_producto}, token)
		_paso("POST /api/tienda/comprar (id %d)" % id_producto, r)
		print("        ", r.get("crudo", ""))
	r = await _req(HTTPClient.METHOD_GET, "/api/tienda/inventario", null, token)
	_paso("GET /api/tienda/inventario", r)
	print("        ", r.get("crudo", ""))
	r = await _req(HTTPClient.METHOD_POST, "/api/tickets/generar-demo", {}, token)
	_paso("POST /api/tickets/generar-demo", r, r.codigo if r.codigo in [200, 201] else 200)
	r = await _req(HTTPClient.METHOD_GET, "/api/tickets/pendientes", null, token)
	_paso("GET /api/tickets/pendientes", r)
	r = await _req(HTTPClient.METHOD_GET, "/api/eventos/activos", null, token)
	_paso("GET /api/eventos/activos", r)

	# 8. Endpoint que usa Dashboard.gd
	r = await _req(HTTPClient.METHOD_GET, "/api/usuario/dashboard", null, token)
	_paso("GET /api/usuario/dashboard (Dashboard.gd)", r)

	_fin()


func _fin() -> void:
	print("\n===== RESUMEN =====")
	for l: String in _resumen:
		print(l)
	quit()
