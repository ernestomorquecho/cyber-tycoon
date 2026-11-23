extends Control
class_name InventarioModal
## Va sobre el nodo raíz "Inventario" de Escenas/Inventario.tscn.
## Mismo diseño base que la Tienda: marco pixel, cabecera con dinero y
## reputación, pestañas de filtro por categoría y una cuadrícula de tarjetas.
## Todo lo que se muestra viene del servidor vía GameData; esta pantalla no
## suma ni resta métricas por su cuenta.

const ItemCardScene: PackedScene = preload("res://Escenas/Inventario/InventoryItemCard.tscn")
const Estilo := preload("res://Scripts/EstiloTienda.gd")
const MENSAJE_SEGUNDOS := 3.0
const ESCENA_DASHBOARD := "res://Escenas/Dashboard.tscn"

# "id" debe coincidir con los grupos de EstiloTienda.grupo_de().
const FILTROS := [
	{"id": "todos", "texto": "TODOS"},
	{"id": "servidores", "texto": "SERVIDORES"},
	{"id": "refrigeracion", "texto": "REFRIGERACIÓN"},
	{"id": "energia", "texto": "ENERGÍA"},
	{"id": "redes", "texto": "REDES"},
	{"id": "otros", "texto": "OTROS"},
]

@onready var _dinero_label: Label = %Dinero
@onready var _reputacion_label: Label = %Reputacion
@onready var _watts_label: Label = %WattsLabel
@onready var _temp_label: Label = %TempLabel
@onready var _boton_cerrar: Button = %CloseButton
@onready var _barra_filtros: HBoxContainer = %BarraFiltros
@onready var _scroll: ScrollContainer = %Scroll
@onready var _lista: GridContainer = %ListaEquipos
@onready var _mensaje_label: Label = %Mensaje
@onready var _conteo_label: Label = %Conteo

var _tarjetas: Array[InventoryItemCard] = []
var _botones_filtro: Dictionary = {}
var _filtro_actual: String = "todos"
var _id_mensaje: int = 0
var _recibido: bool = false


func _ready() -> void:
	_boton_cerrar.pressed.connect(_cerrar)
	Estilo.aplicar_boton(_boton_cerrar, Estilo.PELIGRO)
	_mensaje_label.text = ""
	_crear_filtros()

	GameData.inventario_recibido.connect(_on_inventario_recibido)
	GameData.inventario_error.connect(_on_inventario_error)
	GameData.estado_actualizado.connect(_refresh_header)
	GameData.creditos_actualizados.connect(func(_saldo: float): _refresh_header())

	_limpiar_lista()
	_refresh_header()
	_actualizar_conteo()
	GameData.solicitar_inventario()


func _unhandled_input(event: InputEvent) -> void:
	if event.is_action_pressed("ui_cancel"): # Esc
		get_viewport().set_input_as_handled()
		_cerrar()


func _cerrar() -> void:
	if get_tree().current_scene == self:
		# Corrida sola (F6): no hay Dashboard debajo, se vuelve a él.
		get_tree().change_scene_to_file(ESCENA_DASHBOARD)
	else:
		# Popup del Dashboard: basta con quitarlo.
		queue_free()


# --- Cabecera: dinero, reputación, consumo y temperatura ---

func _refresh_header() -> void:
	_dinero_label.text = Estilo.formato_dinero(GameData.creditos)
	_reputacion_label.text = str(GameData.reputacion)
	_watts_label.text = "%s / %s W" % [
		Estilo.formato_dinero(roundf(GameData.carga_electrica)),
		Estilo.formato_dinero(roundf(GameData.capacidad_watts))]
	_temp_label.text = "%d °C" % roundi(GameData.temperatura)
	_temp_label.add_theme_color_override("font_color", _color_temperatura(GameData.temperatura))


func _color_temperatura(t: float) -> Color:
	if t >= 80.0:
		return Estilo.PELIGRO
	if t >= 60.0:
		return Estilo.ACENTOS["energia"]
	return Estilo.ACENTOS["refrigeracion"]


# --- Filtros por categoría (igual que en la Tienda) ---

func _crear_filtros() -> void:
	var grupo_botones := ButtonGroup.new()
	for f in FILTROS:
		var boton := Button.new()
		boton.text = f["texto"]
		boton.toggle_mode = true
		boton.button_group = grupo_botones
		boton.custom_minimum_size = Vector2(0, 34)
		var color: Color = Estilo.TEXTO_SECUNDARIO.lightened(0.3) if f["id"] == "todos" else Estilo.color_de(f["id"])
		Estilo.aplicar_boton(boton, color, true)
		boton.pressed.connect(_aplicar_filtro.bind(f["id"]))
		_barra_filtros.add_child(boton)
		_botones_filtro[f["id"]] = boton

	_botones_filtro["todos"].button_pressed = true
	for f in FILTROS:
		if f["id"] != "todos":
			_botones_filtro[f["id"]].visible = false


func _aplicar_filtro(id: String) -> void:
	_filtro_actual = id
	for tarjeta in _tarjetas:
		if is_instance_valid(tarjeta):
			tarjeta.visible = (id == "todos" or tarjeta.grupo == id)
	_scroll.scroll_vertical = 0


func _actualizar_filtros() -> void:
	var conteo := {}
	for tarjeta in _tarjetas:
		if is_instance_valid(tarjeta) and not tarjeta.is_queued_for_deletion():
			conteo[tarjeta.grupo] = int(conteo.get(tarjeta.grupo, 0)) + 1
	# Solo se muestran las pestañas de categorías que el jugador tiene.
	for f in FILTROS:
		if f["id"] != "todos":
			_botones_filtro[f["id"]].visible = conteo.has(f["id"])
	if _filtro_actual != "todos" and not conteo.has(_filtro_actual):
		_filtro_actual = "todos"
		_botones_filtro["todos"].button_pressed = true
	_aplicar_filtro(_filtro_actual)


# --- Lista de equipos ---

func _limpiar_lista() -> void:
	for child in _lista.get_children():
		child.queue_free()
	_tarjetas.clear()


func _on_inventario_recibido(items: Array) -> void:
	_recibido = true
	_limpiar_lista()
	for item_dict in items:
		if not item_dict is Dictionary:
			continue
		var data := InventoryItemData.desde_json(item_dict)
		data.icon = ImagenesProductos.cargar(data.nombre_producto)
		_spawn_item(data)
	_actualizar_filtros()
	_actualizar_conteo()


func _on_inventario_error(texto: String) -> void:
	_mostrar_mensaje(texto, true)


func _spawn_item(data: InventoryItemData) -> void:
	var card: InventoryItemCard = ItemCardScene.instantiate()
	_lista.add_child(card)
	card.setup(data)
	card.mensaje.connect(_on_card_mensaje)
	card.tree_exited.connect(_on_card_eliminada.bind(card))
	_tarjetas.append(card)


func _on_card_eliminada(card: InventoryItemCard) -> void:
	# Se vendió un equipo: se quita de la lista y se recalculan pestañas y conteo.
	_tarjetas.erase(card)
	if is_inside_tree() and not is_queued_for_deletion():
		_actualizar_filtros()
		_actualizar_conteo()


func _actualizar_conteo() -> void:
	var n := _tarjetas.size()
	if not _recibido:
		_conteo_label.text = "Cargando..."
	elif n == 0:
		_conteo_label.text = "Sin equipos: compra en la Tienda"
	else:
		_conteo_label.text = "%d equipo%s" % [n, "" if n == 1 else "s"]


func _on_card_mensaje(texto: String, es_error: bool) -> void:
	_mostrar_mensaje(texto, es_error)
	if es_error:
		# Puede que el inventario haya cambiado en otro lado (p. ej. ya se vendió):
		# se vuelve a pedir para que la pantalla coincida con el servidor.
		GameData.solicitar_inventario()


func _mostrar_mensaje(texto: String, es_error: bool) -> void:
	if texto.is_empty():
		return
	_id_mensaje += 1
	var id := _id_mensaje
	_mensaje_label.text = texto
	_mensaje_label.add_theme_color_override("font_color", Estilo.PELIGRO if es_error else Color(0.4, 0.9, 0.5))
	get_tree().create_timer(MENSAJE_SEGUNDOS).timeout.connect(func():
		if is_instance_valid(self) and id == _id_mensaje:
			_mensaje_label.text = ""
	)
