extends Control
## Pantalla de acceso de Cyber Tycoon (res://login/Login.tscn).
## Diseño original del paquete CyberTycoon_Login_Godot; aquí se le agregó la
## conexión real: POST /api/auth/login con nombreUsuario + codigo_clase.
## Si el servidor acepta, guarda la sesión en GameData/Session y abre el Dashboard.

signal login_solicitado(nombre: String, codigo: String)

const ESTILO_ERROR := preload("res://login/assets/input_error_9slice.png")
const ESCENA_DASHBOARD := "res://Escenas/Dashboard.tscn"
const LOGIN_ENDPOINT := "/api/auth/login"
const TIMEOUT_SEGUNDOS := 10.0
const TEXTO_CAMPOS_VACIOS := "COMPLETA AMBOS CAMPOS"

@onready var input_nombre: LineEdit = $Contenido/Marco/Panel/Tarjeta/InputNombre
@onready var input_codigo: LineEdit = $Contenido/Marco/Panel/Tarjeta/InputCodigo
@onready var boton_jugar: TextureButton = $Contenido/Marco/BotonJugar
@onready var mensaje_error: Label = $Contenido/Marco/MensajeError

var _estilo_error: StyleBoxTexture
var _http: HTTPRequest
var _enviando: bool = false


func _ready() -> void:
	_estilo_error = StyleBoxTexture.new()
	_estilo_error.texture = ESTILO_ERROR
	for lado in [SIDE_LEFT, SIDE_TOP, SIDE_RIGHT, SIDE_BOTTOM]:
		_estilo_error.set_texture_margin(lado, 12)
	_estilo_error.content_margin_left = 16
	_estilo_error.content_margin_right = 16
	_estilo_error.content_margin_top = 8
	_estilo_error.content_margin_bottom = 8

	# El mensaje puede traer textos largos del servidor: que bajen de renglón.
	mensaje_error.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART

	_http = HTTPRequest.new()
	_http.timeout = TIMEOUT_SEGUNDOS
	add_child(_http)
	_http.request_completed.connect(_on_login_completed)

	for campo in [input_nombre, input_codigo]:
		campo.text_changed.connect(_on_texto_cambiado.bind(campo))
		campo.text_submitted.connect(func(_t): _intentar_jugar())
	boton_jugar.pressed.connect(_intentar_jugar)

	# Tab pasa de Nombre a Código y luego al botón
	input_nombre.focus_next = input_codigo.get_path()
	input_codigo.focus_next = boton_jugar.get_path()

	_actualizar_estado()
	input_nombre.grab_focus()


func _on_texto_cambiado(_texto: String, campo: LineEdit) -> void:
	campo.remove_theme_stylebox_override("normal")
	_actualizar_estado()


func _datos_completos() -> bool:
	return not input_nombre.text.strip_edges().is_empty() \
		and not input_codigo.text.strip_edges().is_empty()


func _actualizar_estado() -> void:
	var listo := _datos_completos()
	boton_jugar.disabled = not listo or _enviando
	mensaje_error.text = TEXTO_CAMPOS_VACIOS
	mensaje_error.visible = not listo


func _mostrar_error(texto: String) -> void:
	mensaje_error.text = texto.to_upper() # la fuente pixel solo trae mayúsculas
	mensaje_error.visible = true


func _intentar_jugar() -> void:
	if _enviando:
		return # evita doble envío (Enter + clic)
	if not _datos_completos():
		for campo in [input_nombre, input_codigo]:
			if campo.text.strip_edges().is_empty():
				campo.add_theme_stylebox_override("normal", _estilo_error)
		return

	var nombre := input_nombre.text.strip_edges()
	var codigo := input_codigo.text.strip_edges().to_upper()
	login_solicitado.emit(nombre, codigo)

	var cuerpo := JSON.stringify({"nombreUsuario": nombre, "codigo_clase": codigo})
	var err := _http.request(Session.base_url + LOGIN_ENDPOINT,
		PackedStringArray(["Content-Type: application/json"]), HTTPClient.METHOD_POST, cuerpo)
	if err != OK:
		_mostrar_error("No se pudo conectar con el servidor")
		return

	_enviando = true
	boton_jugar.disabled = true
	mensaje_error.visible = false


func _on_login_completed(result: int, codigo_http: int, _headers: PackedStringArray, body: PackedByteArray) -> void:
	_enviando = false
	_actualizar_estado()

	if result != HTTPRequest.RESULT_SUCCESS or body.is_empty():
		_mostrar_error("Sin respuesta del servidor. Revisa tu conexión")
		return

	var json = JSON.parse_string(body.get_string_from_utf8())
	if codigo_http == 200 and json is Dictionary and json.has("token"):
		var usuario = json.get("usuario", {})
		GameData.iniciar_sesion(str(json["token"]), usuario if usuario is Dictionary else {})
		get_tree().change_scene_to_file(ESCENA_DASHBOARD)
		return

	var texto := "Error al iniciar sesión (%d)" % codigo_http
	if json is Dictionary and json.has("error"):
		texto = str(json["error"])
	_mostrar_error(texto)
	# El servidor responde 404 cuando el código de clase no existe.
	if codigo_http == 404:
		input_codigo.add_theme_stylebox_override("normal", _estilo_error)
