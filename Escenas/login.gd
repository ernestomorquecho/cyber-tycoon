extends Control

@onready var input_usuario: LineEdit = %LineEditUsuario
@onready var input_codigo: LineEdit = %LineEditCodigo
@onready var boton_login: Button = %BotonLogin

var http_request: HTTPRequest

func _ready() -> void:
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.timeout = 10.0
	http_request.request_completed.connect(_on_login_completed)
	# OJO: la señal "pressed" de BotonLogin ya está conectada desde Login.tscn
	# (pestaña Nodo del Inspector). Conectarla también aquí causaba el error
	# "Signal 'pressed' is already connected".

func _on_boton_login_pressed() -> void:
	if boton_login.disabled:
		return # ya hay una petición en curso (evita doble clic)
	var url = Session.base_url + "/api/auth/login"
	var headers = PackedStringArray(["Content-Type: application/json"])
	
	var payload = {
		"nombreUsuario": input_usuario.text.strip_edges(),
		"codigo_clase": input_codigo.text.strip_edges()
	}
	var body = JSON.stringify(payload)
	
	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		print("Error al enviar la solicitud HTTP de login.")
		return
	boton_login.disabled = true

func _on_login_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	boton_login.disabled = false
	if body.is_empty():
		print("El servidor no respondió.")
		return

	var json = JSON.parse_string(body.get_string_from_utf8())

	if response_code == 200 and json is Dictionary:
		# Solo se guarda la sesión. Créditos, espacio y métricas los pide el
		# Dashboard a GET /api/usuario/dashboard en cuanto se abre (el cliente ya
		# no inventa valores como los 10000 créditos o los 16 U de antes).
		var u = json.get("usuario", {})
		GameData.iniciar_sesion(str(json.get("token", "")), u if u is Dictionary else {})
		print("¡Login exitoso! Token guardado correctamente.")
		get_tree().change_scene_to_file("res://Escenas/Dashboard.tscn")
	else:
		var mensaje_error = "Credenciales incorrectas"
		if json is Dictionary and json.has("error"):
			mensaje_error = json["error"]
		print("Error en el login (Código %s): %s" % [response_code, mensaje_error])
