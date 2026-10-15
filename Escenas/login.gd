extends Control

@onready var input_usuario: LineEdit = %LineEditUsuario
@onready var input_codigo: LineEdit = %LineEditCodigo
@onready var boton_login: Button = %BotonLogin

var http_request: HTTPRequest

func _ready() -> void:
	http_request = HTTPRequest.new()
	add_child(http_request)
	http_request.request_completed.connect(_on_login_completed)
	
	boton_login.pressed.connect(_on_boton_login_pressed)

func _on_boton_login_pressed() -> void:
	var url = "http://127.0.0.1:3000/api/auth/login"
	var headers = PackedStringArray(["Content-Type: application/json"])
	
	var payload = {
		"nombreUsuario": input_usuario.text.strip_edges(),
		"codigo_clase": input_codigo.text.strip_edges()
	}
	var body = JSON.stringify(payload)
	
	var err = http_request.request(url, headers, HTTPClient.METHOD_POST, body)
	if err != OK:
		print("Error al enviar la solicitud HTTP de login.")

func _on_login_completed(_result: int, response_code: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	if body.is_empty():
		print("El servidor no respondió.")
		return

	var json = JSON.parse_string(body.get_string_from_utf8())

	if response_code == 200 and json is Dictionary:
		GameData.token_jwt = json.get("token", "")
		
		if json.has("usuario"):
			var u = json["usuario"]
			GameData.id_usuario = int(u.get("id_usuario", 1))
			GameData.nombreUsuario = String(u.get("nombreUsuario", "Jugador"))
			
			# ESCUDO DE SEGURIDAD: Si la BD manda 0 o nada, forzamos 10000 para la prueba
			var creditos_recibidos = u.get("creditos")
			if creditos_recibidos == null or float(str(creditos_recibidos)) <= 0:
				GameData.creditos = 10000.0
			else:
				GameData.creditos = float(str(creditos_recibidos))
				
			GameData.creditos_actualizados.emit(GameData.creditos)
			
			var espacio_libre = int(u.get("espacioFisicoDisponible", 16))
			GameData.espacio_ocupado = GameData.espacio_total - espacio_libre
		
		print("¡Login exitoso! Token guardado correctamente.")
		get_tree().change_scene_to_file("res://Escenas/Dashboard.tscn")
	else:
		var mensaje_error = "Credenciales incorrectas"
		if json is Dictionary and json.has("error"):
			mensaje_error = json["error"]
		print("Error en el login (Código %s): %s" % [response_code, mensaje_error])
