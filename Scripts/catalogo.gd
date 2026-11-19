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

# SOLO PARA PROBAR LA UI SIN BACKEND. Si GET /api/tienda/catalogo falla y la
# lista está vacía, se muestran estos 20 productos. Los nombres son los reales;
# costo, consumo, TFlops, Watts, ancho de banda y calor son valores inventados,
# NO los de la BD. La imagen y la descripción NO se escriben aquí: la tarjeta
# las busca por nombre en ImagenesProductos.gd y DescripcionesProductos.gd.
# Cuando el backend ya corra, pon USAR_LISTA_DE_PRUEBA en false.
const USAR_LISTA_DE_PRUEBA := false
const PRODUCTOS_PRUEBA := [
	{"id_producto": 1, "nombreProducto": "Dull PowerBorde R110 (1U)", "categoria": "Servidor", "costo": 1800.0, "espacioNecesario": 1, "consumoElectrico": 250, "aumento_teraflops": 10, "impacto_temperatura": 8},
	{"id_producto": 2, "nombreProducto": "HachePe ProLiante DL360 (1U)", "categoria": "Servidor", "costo": 3500.0, "espacioNecesario": 1, "consumoElectrico": 400, "aumento_teraflops": 25, "impacto_temperatura": 12},
	{"id_producto": 3, "nombreProducto": "Lenorvo OverThink SR650 (2U)", "categoria": "Servidor", "costo": 5200.0, "espacioNecesario": 2, "consumoElectrico": 550, "aumento_teraflops": 40, "impacto_temperatura": 16},
	{"id_producto": 4, "nombreProducto": "HyperMicro MegaBlade X12 (3U)", "categoria": "Servidor", "costo": 9800.0, "espacioNecesario": 3, "consumoElectrico": 1200, "aumento_teraflops": 90, "impacto_temperatura": 30},
	{"id_producto": 5, "nombreProducto": "Envidia DGX-9000 TensorHorno (4U)", "categoria": "Servidor", "costo": 24000.0, "espacioNecesario": 4, "consumoElectrico": 3200, "aumento_teraflops": 400, "impacto_temperatura": 70},
	{"id_producto": 6, "nombreProducto": "NocturnaBúho FanTray Industrial (1U)", "categoria": "Refrigeración", "costo": 900.0, "espacioNecesario": 1, "consumoElectrico": 60, "impacto_temperatura": -10},
	{"id_producto": 7, "nombreProducto": "Corsario HydroLeak AIO (1U)", "categoria": "Refrigeración", "costo": 1500.0, "espacioNecesario": 1, "consumoElectrico": 90, "impacto_temperatura": -18},
	{"id_producto": 8, "nombreProducto": "VertiFrío Liebert InRow (2U)", "categoria": "Refrigeración", "costo": 6200.0, "espacioNecesario": 2, "consumoElectrico": 800, "impacto_temperatura": -45},
	{"id_producto": 9, "nombreProducto": "TermoTake Chiller H2O-Max (3U)", "categoria": "Refrigeración", "costo": 11000.0, "espacioNecesario": 3, "consumoElectrico": 1500, "impacto_temperatura": -90},
	{"id_producto": 10, "nombreProducto": "SubMarino Pod Dieléctrico (4U)", "categoria": "Refrigeración", "costo": 21000.0, "espacioNecesario": 4, "consumoElectrico": 600, "impacto_temperatura": -160},
	{"id_producto": 11, "nombreProducto": "TrippCorto Regleta PDU-800 (1U)", "categoria": "Energía", "costo": 700.0, "espacioNecesario": 1, "consumoElectrico": 20, "aumento_watts": 800, "impacto_temperatura": 1},
	{"id_producto": 12, "nombreProducto": "APagón Smart-UPS 1500VA (2U)", "categoria": "Energía", "costo": 2200.0, "espacioNecesario": 2, "consumoElectrico": 60, "aumento_watts": 1200, "impacto_temperatura": 3},
	{"id_producto": 13, "nombreProducto": "Tragón 9PX Doble Conversión (2U)", "categoria": "Energía", "costo": 4200.0, "espacioNecesario": 2, "consumoElectrico": 110, "aumento_watts": 2000, "impacto_temperatura": 6},
	{"id_producto": 14, "nombreProducto": "Chispazoneider Symmetra Li-Ion (3U)", "categoria": "Energía", "costo": 7800.0, "espacioNecesario": 3, "consumoElectrico": 160, "aumento_watts": 4000, "impacto_temperatura": 5},
	{"id_producto": 15, "nombreProducto": "Tésla MegaPila Nuclear-Pack (4U)", "categoria": "Energía", "costo": 15000.0, "espacioNecesario": 4, "consumoElectrico": 250, "aumento_watts": 9000, "impacto_temperatura": 8},
	{"id_producto": 16, "nombreProducto": "MacroTik RouterBordo HEX-24 (1U)", "categoria": "Red", "costo": 1200.0, "espacioNecesario": 1, "consumoElectrico": 40, "impacto_anchoDeBanda": 100, "impacto_temperatura": 3},
	{"id_producto": 17, "nombreProducto": "Chisco Catalizador 2960-Giga (1U)", "categoria": "Red", "costo": 900.0, "espacioNecesario": 1, "consumoElectrico": 35, "impacto_anchoDeBanda": 50, "impacto_temperatura": 2},
	{"id_producto": 18, "nombreProducto": "FuerteNet FortiMuro 600F (2U)", "categoria": "Red", "costo": 4800.0, "espacioNecesario": 2, "consumoElectrico": 150, "impacto_anchoDeBanda": 100, "impacto_temperatura": 6},
	{"id_producto": 19, "nombreProducto": "Arisca EtherSwitch 100G-Spine (2U)", "categoria": "Red", "costo": 9500.0, "espacioNecesario": 2, "consumoElectrico": 350, "impacto_anchoDeBanda": 400, "impacto_temperatura": 12},
	{"id_producto": 20, "nombreProducto": "Junípero PTX-TeraCore Óptico (3U)", "categoria": "Red", "costo": 18000.0, "espacioNecesario": 3, "consumoElectrico": 700, "impacto_anchoDeBanda": 1000, "impacto_temperatura": 25},
]

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
	if USAR_LISTA_DE_PRUEBA and lista_productos.get_child_count() == 0:
		generar_catalogo(PRODUCTOS_PRUEBA)


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
