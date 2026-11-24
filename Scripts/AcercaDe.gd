extends Control
class_name AcercaDe
## Pantalla "Acerca de" (se construye por código; la abre el botón Acerca_de del
## Dashboard). Mismo estilo que el aviso de incidentes pero en azul (informativo).
## Explica el juego por apartados y da el fundamento teórico de cada tipo de
## equipo e incidente, para que el estudiante relacione el juego con un Data
## Center real. Los valores del juego (70 / 85 °C, −40 %, 90 s...) deben coincidir
## con backend/src/config/juego.js.

const COLOR_FONDO := Color(0.04, 0.09, 0.16, 0.97)
const COLOR_BORDE := Color(0.13, 0.75, 0.95)
const COLOR_TITULO := Color(0.55, 0.88, 1.0)
const COLOR_TEXTO := Color(0.88, 0.92, 0.97)
const TAMANO_PANEL := Vector2(920, 580)

# [título de la pestaña, texto en BBCode]
const SECCIONES := [
	["Cómo se juega", """[font_size=22][color=#8ce0ff]Tu misión: administrar un Data Center[/color][/font_size]

Eres responsable de un centro de datos. Los [b]clientes[/b] te envían [b]tickets[/b] (solicitudes de servicio): si tienes la capacidad suficiente los aceptas, los entregas a tiempo y ganas dinero y [b]reputación[/b].

• [b]Créditos ($):[/b] los ganas con tickets entregados y con los [b]ingresos pasivos[/b] de tus servidores encendidos. Los gastas en la Tienda.
• [b]Reputación (0-100):[/b] sube al cumplir y baja al rechazar, dejar caducar o fallar. [color=#ff8a8a]Si llega a 0, la partida termina (Game Over).[/color]
• [b]Capacidad:[/b] cada ticket aparta TFLOPS, RAM y ancho de banda mientras está en proceso. Si apagas o vendes equipo a mitad de una entrega, el ticket falla.
• [b]Riesgos:[/b] temperatura, energía e [b]incidentes[/b] que llegan solos cada pocos minutos.

[b]Consejo:[/b] crece de forma equilibrada. Más servidores dan más capacidad, pero también más calor y más consumo eléctrico; sin refrigeración ni energía suficientes, el Data Center se apaga solo."""],

	["Incidentes", """[font_size=22][color=#8ce0ff]Incidentes: situaciones reales de operación[/color][/font_size]

Cada 2 a 4 minutos puede ocurrir un incidente. Tienes [b]90 segundos[/b] para elegir la acción correcta (+5 de reputación); si fallas o no respondes, pierdes reputación y dinero.

[b][color=#ffb347]Sobrecalentamiento (alerta térmica)[/color][/b]
Los procesadores convierten casi toda la energía que consumen en calor. Si no se extrae, los chips reducen su velocidad para protegerse ([i]thermal throttling[/i]) o se apagan, y su vida útil disminuye. Respuesta típica: [b]activar la refrigeración de emergencia[/b] y redistribuir la carga.

[b][color=#ff8a8a]Ataque de fuerza bruta (SSH)[/color][/b]
Un atacante prueba miles de contraseñas por segundo contra el acceso remoto (SSH) desde las mismas direcciones IP. Amenaza la [b]confidencialidad[/b] de los datos. Respuesta típica: [b]bloquear esas IP en el firewall[/b]; como prevención se usan llaves criptográficas en lugar de contraseñas, límite de intentos y autenticación de dos factores.

[b][color=#8ce0ff]Saturación de red[/color][/b]
Cuando el tráfico supera el ancho de banda, aumenta la latencia y se pierden paquetes: el servicio se vuelve lento aunque sobre cómputo. Puede ser un pico legítimo o un ataque de denegación de servicio (DDoS). Respuesta típica: [b]balancear la carga y aplicar QoS[/b] (calidad de servicio: priorizar el tráfico crítico).

[b][color=#ffe066]Falla en la red eléctrica[/color][/b]
Una caída de voltaje ([i]brownout[/i]) o un corte deja al Data Center sin la energía que necesita. Respuesta típica: [b]cambiar a la energía de respaldo (UPS)[/b], que entra al instante mientras se restablece la red o arranca un generador. En el juego la capacidad baja 40 % y, si el consumo no cabe, se apagan servidores del último instalado al primero ([b]apagón parcial[/b])."""],

	["Equipos del Data Center", """[font_size=22][color=#8ce0ff]¿Por qué existe cada tipo de equipo?[/color][/font_size]

Un Data Center necesita cuatro sistemas que se complementan: si falta uno, los demás no sirven. Todos se montan en [b]racks[/b] estándar de 19 pulgadas, medidos en [b]unidades (U)[/b] de 1.75 pulgadas (44.45 mm) de alto.

[b][color=#8ce0ff]1. Servidores: el cómputo[/color][/b]
Son el "producto" del Data Center: ahí corren las aplicaciones de los clientes (sitios web, bases de datos, inteligencia artificial). Su capacidad se mide en [b]TFLOPS[/b] (billones de operaciones de punto flotante por segundo) y en [b]memoria RAM[/b]. Los más potentes usan GPU para IA, pero consumen y calientan mucho más.

[b][color=#7dffb0]2. Refrigeración: sacar el calor[/color][/b]
Casi toda la electricidad que consume un servidor termina convertida en calor. Por eso existen ventiladores, refrigeración líquida, unidades de enfriamiento entre racks ([i]in-row[/i]), [i]chillers[/i] de agua e incluso inmersión en líquido dieléctrico (no conduce la electricidad). La guía ASHRAE TC 9.9 recomienda que el aire que entra a los servidores esté entre 18 y 27 °C.

[b][color=#ffe066]3. Energía: alimentar todo sin interrupciones[/color][/b]
• [b]PDU[/b] (unidad de distribución de energía): reparte la electricidad dentro del rack.
• [b]UPS[/b] (sistema de alimentación ininterrumpida): baterías que mantienen todo encendido durante un corte y filtran variaciones de voltaje. Los de [b]doble conversión[/b] transforman la corriente alterna a directa y de vuelta, aislando por completo al equipo de la red eléctrica.
Un corte de milisegundos puede reiniciar servidores; por eso se diseña con [b]redundancia[/b] (por ejemplo N+1: un equipo de respaldo más de los necesarios).

[b][color=#c9a0ff]4. Redes: conectar con los clientes[/color][/b]
• [b]Switch:[/b] conecta los equipos dentro del Data Center.
• [b]Router:[/b] conecta redes distintas (por ejemplo, con Internet) y decide la ruta de los paquetes.
• [b]Firewall:[/b] filtra el tráfico según reglas de seguridad.
• [b]Spine-leaf y fibra óptica:[/b] arquitectura y medio físico de los Data Centers modernos, con baja latencia y mucho ancho de banda.
Sin red suficiente, aunque haya cómputo de sobra, los clientes no pueden usar el servicio."""],

	["Temperatura y energía", """[font_size=22][color=#8ce0ff]Las reglas del juego y su porqué[/color][/font_size]

[b][color=#7dffb0]Temperatura[/color][/b]
• [b]Hasta 70 °C:[/b] operación normal.
• [b]71-85 °C (advertencia):[/b] los equipos reducen su rendimiento para no dañarse ([i]thermal throttling[/i]): tus ingresos pasivos bajan 40 % y los tickets entregados pagan 25 % menos.
• [b]Más de 85 °C (crítico):[/b] [color=#ff8a8a]apagado de emergencia[/color]. Se apagan servidores, del que más calienta al que menos, hasta volver a un nivel seguro; es lo que hacen los equipos reales para protegerse.
La refrigeración baja la temperatura; apagar equipos también.

[b][color=#ffe066]Energía[/color][/b]
• El consumo de los equipos encendidos no puede superar la capacidad eléctrica. Si no alcanza, un equipo nuevo queda [b]apagado[/b] hasta que compres unidades de energía.
• No puedes apagar ni vender una unidad de energía que está alimentando equipos encendidos: primero apaga servidores.
• Un equipo apagado conserva su lugar en el rack, pero no consume ni genera calor.

[b][color=#8ce0ff]Eficiencia energética (PUE)[/color][/b]
En la industria se usa el [b]PUE[/b] (Power Usage Effectiveness): energía total del Data Center dividida entre la energía que usan los equipos de TI. Un PUE de 1.0 sería perfecto; la diferencia se va sobre todo en refrigeración. Por eso enfriar bien, y no de más, es tan importante como tener servidores potentes."""],
]

var _texto: RichTextLabel
var _scroll: ScrollContainer
var _botones: Array[Button] = []


func _ready() -> void:
	set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	mouse_filter = Control.MOUSE_FILTER_STOP # bloquea los clics al Dashboard

	var fondo := ColorRect.new()
	fondo.color = Color(0, 0, 0, 0.6)
	fondo.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	fondo.gui_input.connect(func(evento):
		if evento is InputEventMouseButton and evento.pressed:
			queue_free() # clic fuera del panel = cerrar
	)
	add_child(fondo)

	var centro := CenterContainer.new()
	centro.set_anchors_and_offsets_preset(Control.PRESET_FULL_RECT)
	centro.mouse_filter = Control.MOUSE_FILTER_IGNORE
	add_child(centro)

	var panel := PanelContainer.new()
	panel.custom_minimum_size = TAMANO_PANEL
	var estilo := StyleBoxFlat.new()
	estilo.bg_color = COLOR_FONDO
	estilo.border_color = COLOR_BORDE
	estilo.set_border_width_all(3)
	estilo.set_corner_radius_all(10)
	estilo.set_content_margin_all(20)
	panel.add_theme_stylebox_override("panel", estilo)
	centro.add_child(panel)

	var vbox := VBoxContainer.new()
	vbox.add_theme_constant_override("separation", 12)
	panel.add_child(vbox)

	# Cabecera: título + cerrar
	var cabecera := HBoxContainer.new()
	vbox.add_child(cabecera)
	var titulo := Label.new()
	titulo.text = "ℹ  ACERCA DE CYBER TYCOON"
	titulo.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	titulo.add_theme_color_override("font_color", COLOR_TITULO)
	titulo.add_theme_font_size_override("font_size", 24)
	cabecera.add_child(titulo)
	var cerrar := Button.new()
	cerrar.text = "  ✕  "
	cerrar.tooltip_text = "Cerrar (Esc)"
	cerrar.pressed.connect(queue_free)
	cabecera.add_child(cerrar)

	# Pestañas
	var pestanas := HBoxContainer.new()
	pestanas.add_theme_constant_override("separation", 8)
	vbox.add_child(pestanas)
	var grupo := ButtonGroup.new()
	for i in SECCIONES.size():
		var b := Button.new()
		b.text = SECCIONES[i][0]
		b.toggle_mode = true
		b.button_group = grupo
		b.custom_minimum_size.y = 38
		b.pressed.connect(_mostrar_seccion.bind(i))
		pestanas.add_child(b)
		_botones.append(b)

	# Contenido con scroll
	_scroll = ScrollContainer.new()
	_scroll.size_flags_vertical = Control.SIZE_EXPAND_FILL
	_scroll.horizontal_scroll_mode = ScrollContainer.SCROLL_MODE_DISABLED
	vbox.add_child(_scroll)
	_texto = RichTextLabel.new()
	_texto.bbcode_enabled = true
	_texto.fit_content = true
	_texto.autowrap_mode = TextServer.AUTOWRAP_WORD_SMART
	_texto.size_flags_horizontal = Control.SIZE_EXPAND_FILL
	_texto.custom_minimum_size.x = TAMANO_PANEL.x - 70 # ancho conocido: el ajuste de línea se mide bien
	_texto.add_theme_color_override("default_color", COLOR_TEXTO)
	_texto.add_theme_font_size_override("normal_font_size", 17)
	_texto.add_theme_font_size_override("bold_font_size", 17)
	_texto.add_theme_font_size_override("italics_font_size", 17)
	_texto.add_theme_constant_override("line_separation", 4)
	_scroll.add_child(_texto)

	_botones[0].button_pressed = true
	_mostrar_seccion(0)


func _unhandled_input(evento: InputEvent) -> void:
	if evento.is_action_pressed("ui_cancel"): # Esc o "atrás" en Android
		get_viewport().set_input_as_handled()
		queue_free()


func _mostrar_seccion(indice: int) -> void:
	_texto.text = SECCIONES[indice][1]
	_scroll.scroll_vertical = 0
