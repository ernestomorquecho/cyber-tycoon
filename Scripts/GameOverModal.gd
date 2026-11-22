extends Control
class_name GameOverModal
## Modal de fin de partida (CLAUDE.md §5 "Reputación en Cero").
## Se construye por código, sin escena: el Dashboard lo crea cuando GameData
## reporta estado_partida == "GAME_OVER". Muestra las estadísticas finales que
## manda el servidor y ofrece reiniciar (POST /api/usuario/reset) o salir.

signal salir_solicitado

const FUENTE_TITULO := preload("res://login/fonts/cyber_pixel.fnt")
const COLOR_PELIGRO := Color(0.95, 0.42, 0.42)
const COLOR_TEXTO := Color(0.85, 0.87, 0.9)

var _stats_label: Label
var _mensaje_label: Label
var _boton_reiniciar: Button
var _boton_salir: Button
var _confirmando: bool = false


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP # bloquea los clics al Dashboard de abajo

	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.75)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	add_child(centro)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = Vector2(560, 0)
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = Color(0.07, 0.08, 0.11)
	estilo.border_color = COLOR_PELIGRO
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(8)
	estilo.set_content_margin_all(28)
	panel.add_theme_stylebox_override("panel", estilo)
	centro.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 16)
	panel.add_child(vbox)

	var titulo := Label.new()
	titulo.text = "GAME OVER"
	titulo.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	titulo.add_theme_font_override("font", FUENTE_TITULO)
	titulo.add_theme_font_size_override("font_size", 40)
	titulo.add_theme_color_override("font_color", COLOR_PELIGRO)
	vbox.add_child(titulo)

	var explicacion := Label.new()
	explicacion.text = "Tu reputación llegó a 0: los clientes dejaron de confiar en tu Data Center."
	explicacion.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	explicacion.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	explicacion.add_theme_color_override("font_color", COLOR_TEXTO)
	vbox.add_child(explicacion)

	_stats_label = Label.new()
	_stats_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_stats_label.add_theme_color_override("font_color", Color.WHITE)
	vbox.add_child(_stats_label)

	_mensaje_label = Label.new()
	_mensaje_label.horizontal_alignment = HORIZONTAL_ALIGNMENT_CENTER
	_mensaje_label.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_mensaje_label.add_theme_color_override("font_color", COLOR_PELIGRO)
	vbox.add_child(_mensaje_label)

	var botones := HBoxContainer.new()
	botones.alignment = BoxContainer.ALIGNMENT_CENTER
	botones.add_theme_constant_override("separation", 20)
	vbox.add_child(botones)

	_boton_reiniciar = Button.new()
	_boton_reiniciar.custom_minimum_size = Vector2(240, 48)
	_boton_reiniciar.pressed.connect(_on_reiniciar_pressed)
	botones.add_child(_boton_reiniciar)

	_boton_salir = Button.new()
	_boton_salir.text = "SALIR"
	_boton_salir.custom_minimum_size = Vector2(140, 48)
	_boton_salir.pressed.connect(func(): salir_solicitado.emit())
	botones.add_child(_boton_salir)

	GameData.partida_reiniciada.connect(_on_partida_reiniciada)
	actualizar()


## Vuelve a pintar las estadísticas con lo último que mandó el servidor.
func actualizar() -> void:
	if _stats_label == null:
		return
	var e: Dictionary = GameData.estadisticas
	_stats_label.text = "Créditos finales: $%d\nContratos completados: %d\nAtaques resueltos: %d\nEquipos instalados: %d" % [
		roundi(GameData.creditos),
		int(e.get("contratos_finalizados", 0)),
		int(e.get("ataques_resueltos", 0)),
		int(e.get("equipos", 0)),
	]
	_confirmando = false
	_boton_reiniciar.disabled = false
	_boton_reiniciar.text = "REINICIAR PARTIDA"


## Dos toques: reiniciar borra todo el equipo comprado, así que se confirma.
func _on_reiniciar_pressed() -> void:
	if not _confirmando:
		_confirmando = true
		_boton_reiniciar.text = "¿SEGURO? TOCA DE NUEVO"
		_mensaje_label.text = "Se borrarán tus equipos y tickets. Empezarás con $1,000 y 50 de reputación."
		return
	_boton_reiniciar.disabled = true
	_boton_reiniciar.text = "REINICIANDO..."
	_mensaje_label.text = ""
	GameData.reiniciar_partida()


func _on_partida_reiniciada(exito: bool, mensaje: String) -> void:
	if exito:
		return # el Dashboard ve estado_partida == ACTIVE y quita este modal
	_mensaje_label.text = mensaje
	actualizar()
