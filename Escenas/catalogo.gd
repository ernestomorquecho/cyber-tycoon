extends Control

@export var tarjeta_scene: PackedScene = preload("res://Escenas/TarjetaProducto.tscn")

@export var dinero_label: Label
@export var rack_label: Label
@export var mensaje_label: Label
@export var lista_productos: VBoxContainer
@export var boton_cerrar: Button
@export var boton_cancelar: Button

# TODO-BACKEND: escena a la que se vuelve al cerrar el catálogo.
# Ajusta la ruta si tu Dashboard vive en otro lugar, o cambia esta
# función si el catálogo se usa como popup en vez de escena completa.
const ESCENA_DASHBOARD := "res://Escenas/Dashboard.tscn"

var _timer_mensaje: SceneTreeTimer


func _ready() -> void:
	GameData.creditos_actualizados.connect(_actualizar_dinero)
	GameData.espacio_actualizado.connect(_actualizar_rack)
	GameData.catalogo_recibido.connect(_on_catalogo_recibido)
	GameData.catalogo_error.connect(_on_catalogo_error)
	GameData.compra_exitosa.connect(_on_compra_exitosa)
	GameData.compra_fallida.connect(_on_compra_fallida)

	boton_cerrar.pressed.connect(_cerrar_catalogo)
	boton_cancelar.pressed.connect(_cerrar_catalogo)

	# Estado inicial con lo que ya tenga GameData en memoria.
	_actualizar_dinero(GameData.creditos)
	_actualizar_rack(GameData.espacio_ocupado, GameData.espacio_total)

	GameData.solicitar_catalogo()


func _actualizar_dinero(nuevo_saldo: float) -> void:
	dinero_label.text = "$ " + str(nuevo_saldo)


func _actualizar_rack(ocupado: int, total: int) -> void:
	rack_label.text = "%d/%d" % [ocupado, total]


func _on_catalogo_recibido(productos: Array) -> void:
	generar_catalogo(productos)


func _on_catalogo_error(mensaje: String) -> void:
	_mostrar_mensaje(mensaje, false)


func _on_compra_exitosa(_id_producto: int, mensaje: String) -> void:
	_mostrar_mensaje(mensaje, true)


func _on_compra_fallida(_id_producto: int, mensaje: String) -> void:
	_mostrar_mensaje(mensaje, false)


func _mostrar_mensaje(texto: String, es_exito: bool) -> void:
	mensaje_label.text = texto
	mensaje_label.modulate = Color(0.4, 0.9, 0.5) if es_exito else Color(0.95, 0.35, 0.35)
	mensaje_label.visible = true

	# Ocultar el toast solo (sin bloquear si llega otro mensaje antes).
	_timer_mensaje = get_tree().create_timer(2.5)
	_timer_mensaje.timeout.connect(func():
		mensaje_label.visible = false
	)


func generar_catalogo(productos: Array) -> void:
	for child in lista_productos.get_children():
		child.queue_free()

	for producto in productos:
		var nueva_tarjeta = tarjeta_scene.instantiate()
		lista_productos.add_child(nueva_tarjeta)
		nueva_tarjeta.cargar_datos(producto)


func _cerrar_catalogo() -> void:
	get_tree().change_scene_to_file(ESCENA_DASHBOARD)
