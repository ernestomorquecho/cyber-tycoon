extends PanelContainer
class_name IncidenteAlerta
## Aviso de incidente del Data Center (se construye por código; lo crea el Dashboard).
## Muestra la descripción, una cuenta regresiva y un botón por cada acción que
## manda el servidor. El servidor decide si la acción era la correcta; aquí solo
## se envía la elegida (GameData.resolver_incidente) y se muestra el resultado.
## La cuenta regresiva es solo visual: el vencimiento real lo decide el servidor.

const COLOR_BORDE := Color(1.0, 0.3, 0.3)
const COLOR_FONDO := Color(0.12, 0.03, 0.04, 0.95)
const COLOR_OK := Color(0.4, 0.9, 0.5)
const SEGUNDOS_RESULTADO := 5.0
# Ancho fijo del texto: un Label con ajuste de línea necesita un ancho conocido;
# si no, se mide con ancho 0 (una palabra por renglón) y el panel queda altísimo.
const ANCHO_TEXTO := 524.0

var _titulo: Label
var _descripcion: Label
var _tiempo: Label
var _botones: VBoxContainer
var _resultado: Label
var _id_incidente: int = 0
var _segundos: float = 0.0
var _esperando: bool = false


func _ready() -> void:
	visible = false
	mouse_filter = Control.MOUSE_FILTER_STOP
	custom_minimum_size = Vector2(560, 0)
	# Centrado en pantalla (ver _centrar): arriba (y = 70) salen los avisos
	# flotantes del Dashboard, como el del apagón parcial, que llega junto con
	# la falla eléctrica.
	set_anchors_preset(Control.PRESET_TOP_LEFT)
	resized.connect(_centrar)
	get_viewport().size_changed.connect(_centrar)

	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COLOR_FONDO
	estilo.border_color = COLOR_BORDE
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(8)
	estilo.set_content_margin_all(18)
	add_theme_stylebox_override("panel", estilo)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 10)
	add_child(vbox)

	var cabecera := HBoxContainer.new()
	vbox.add_child(cabecera)
	_titulo = Label.new()
	_titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_titulo.add_theme_color_override("font_color", COLOR_BORDE)
	_titulo.add_theme_font_size_override("font_size", 22)
	cabecera.add_child(_titulo)
	_tiempo = Label.new()
	_tiempo.add_theme_color_override("font_color", Color.WHITE)
	_tiempo.add_theme_font_size_override("font_size", 22)
	cabecera.add_child(_tiempo)

	_descripcion = Label.new()
	_descripcion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_descripcion.custom_minimum_size.x = ANCHO_TEXTO
	_descripcion.add_theme_color_override("font_color", Color(0.9, 0.9, 0.92))
	vbox.add_child(_descripcion)

	var pregunta := Label.new()
	pregunta.text = "¿Qué acción tomas?"
	pregunta.add_theme_color_override("font_color", Color(1, 0.85, 0.4))
	vbox.add_child(pregunta)

	_botones = VBoxContainer.new()
	_botones.add_theme_constant_override("separation", 6)
	vbox.add_child(_botones)

	_resultado = Label.new()
	_resultado.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_resultado.custom_minimum_size.x = ANCHO_TEXTO
	_resultado.visible = false
	vbox.add_child(_resultado)

	GameData.incidente_actualizado.connect(_on_incidente_actualizado)
	GameData.incidente_resultado.connect(_on_incidente_resultado)
	if not GameData.incidente.is_empty():
		_on_incidente_actualizado(GameData.incidente)


## Encoge el panel a su contenido actual (los botones de antes ya se borraron)
## y lo vuelve a centrar.
func _ajustar() -> void:
	size = Vector2.ZERO
	_centrar()


## El tamaño depende del texto y de cuántas opciones hay, así que se centra
## cada vez que cambia (o cambia la pantalla, p. ej. al girar el celular).
func _centrar() -> void:
	var area := get_parent_area_size()
	position = ((area - size) / 2.0).floor()
	position.y = maxf(position.y, 10.0)


func _process(delta: float) -> void:
	if not visible or _id_incidente == 0:
		return
	_segundos = maxf(0.0, _segundos - delta)
	var total := int(ceil(_segundos))
	_tiempo.text = "%02d:%02d" % [int(total / 60.0), total % 60]
	_tiempo.add_theme_color_override("font_color", COLOR_BORDE if _segundos <= 15.0 else Color.WHITE)


func _on_incidente_actualizado(incidente: Dictionary) -> void:
	if incidente.is_empty():
		_id_incidente = 0
		if not _resultado.visible:
			visible = false
		return

	_id_incidente = int(incidente.get("id_incidente", 0))
	_segundos = float(incidente.get("segundos_restantes", 90))
	_esperando = false
	_titulo.text = "⚠ INCIDENTE: %s" % str(incidente.get("titulo", ""))
	_descripcion.text = str(incidente.get("descripcion", ""))
	_resultado.visible = false

	for hijo in _botones.get_children():
		hijo.queue_free()
	for opcion in incidente.get("opciones", []):
		if not opcion is Dictionary:
			continue
		var boton := Button.new()
		boton.text = str(opcion.get("texto", opcion.get("id", "")))
		boton.custom_minimum_size = Vector2(0, 40)
		boton.pressed.connect(_on_opcion_pressed.bind(str(opcion.get("id", ""))))
		_botones.add_child(boton)
	visible = true
	_ajustar.call_deferred()


func _on_opcion_pressed(accion: String) -> void:
	if _esperando or _id_incidente == 0:
		return
	_esperando = true
	for boton in _botones.get_children():
		boton.disabled = true
	GameData.resolver_incidente(_id_incidente, accion)


func _on_incidente_resultado(exito: bool, mensaje: String) -> void:
	_esperando = false
	_id_incidente = 0
	for boton in _botones.get_children():
		boton.disabled = true
	_tiempo.text = ""
	_resultado.text = ("✔ " if exito else "✘ ") + mensaje
	_resultado.add_theme_color_override("font_color", COLOR_OK if exito else COLOR_BORDE)
	_resultado.visible = true
	visible = true
	_ajustar.call_deferred()
	var mostrado := _resultado.text
	get_tree().create_timer(SEGUNDOS_RESULTADO).timeout.connect(func():
		# Si mientras tanto llegó otro incidente, ese ya reemplazó el texto.
		if is_instance_valid(self) and _resultado.text == mostrado and _id_incidente == 0:
			_resultado.visible = false
			visible = false
	)
