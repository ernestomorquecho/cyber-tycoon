extends RefCounted
## Colores y estilos de la tienda (dark mode + acentos neón, bordes cuadrados
## estilo pixel). Lo usan catalogo.gd y TarjetaProducto.gd para que todo se vea
## como un solo sistema.

# --- Base (fondo #0D1117 / bordes #30363D del documento de diseño) ---
const FONDO_TARJETA := Color(0.071, 0.086, 0.110)
const FONDO_IMAGEN := Color(0.043, 0.051, 0.063)
const BORDE := Color(0.188, 0.212, 0.239)
const TEXTO := Color(0.902, 0.929, 0.953)
const TEXTO_SECUNDARIO := Color(0.545, 0.580, 0.620)
const DINERO := Color(0.961, 0.773, 0.259)
const PELIGRO := Color(1.0, 0.420, 0.420)

# --- Un acento neón por categoría ---
const ACENTOS := {
	"servidores": Color(0.180, 0.827, 1.000),   # cian
	"refrigeracion": Color(0.239, 0.949, 0.690), # menta
	"energia": Color(1.000, 0.624, 0.263),       # naranja
	"redes": Color(0.725, 0.549, 1.000),         # violeta
	"otros": Color(0.545, 0.580, 0.620),         # gris
}

# --- Colores de cada dato técnico en la tarjeta ---
const STAT_CONSUMO := Color(1.000, 0.851, 0.300)
const STAT_ESPACIO := Color(0.700, 0.740, 0.790)


## Agrupa el producto según el texto de su categoría. Tolera variantes que
## pueda mandar la BD ("Refrigeración" / "Enfriamiento", "Red" / "Redes"...).
static func grupo_de(producto: Dictionary) -> String:
	var c := str(producto.get("categoria", "")).to_lower()
	if c.contains("serv"):
		return "servidores"
	if c.contains("refri") or c.contains("enfri"):
		return "refrigeracion"
	if c.contains("energ") or c.contains("poder") or c.contains("power"):
		return "energia"
	if c.begins_with("red") or c.contains("network"):
		return "redes"
	return "otros"


static func color_de(grupo: String) -> Color:
	return ACENTOS.get(grupo, ACENTOS["otros"])


## Caja plana de esquinas cuadradas con borde.
static func caja(fondo: Color, borde: Color, grosor: int = 2, margen: int = 0) -> StyleBoxFlat:
	var s := StyleBoxFlat.new()
	s.bg_color = fondo
	s.border_color = borde
	s.set_border_width_all(grosor)
	s.set_corner_radius_all(0)
	if margen > 0:
		s.set_content_margin_all(margen)
	return s


## Estilo neón para un botón. Con relleno_al_presionar = true, el estado
## "presionado" se rellena con el color (útil para pestañas de filtro).
static func aplicar_boton(btn: Button, acento: Color, relleno_al_presionar: bool = false) -> void:
	var presionado := _caja_boton(
		acento if relleno_al_presionar else acento.darkened(0.5),
		acento.lightened(0.25))
	btn.add_theme_stylebox_override("normal", _caja_boton(acento.darkened(0.8), acento.darkened(0.3)))
	btn.add_theme_stylebox_override("hover", _caja_boton(acento.darkened(0.65), acento))
	btn.add_theme_stylebox_override("pressed", presionado)
	btn.add_theme_stylebox_override("hover_pressed", presionado)
	btn.add_theme_stylebox_override("disabled", _caja_boton(Color(0.078, 0.090, 0.106), BORDE))
	btn.add_theme_stylebox_override("focus", StyleBoxEmpty.new())

	var texto_presionado := Color(0.05, 0.07, 0.09) if relleno_al_presionar else Color.WHITE
	btn.add_theme_color_override("font_color", acento.lightened(0.2))
	btn.add_theme_color_override("font_hover_color", Color.WHITE)
	btn.add_theme_color_override("font_pressed_color", texto_presionado)
	btn.add_theme_color_override("font_hover_pressed_color", texto_presionado)
	btn.add_theme_color_override("font_disabled_color", Color(0.36, 0.39, 0.43))
	btn.mouse_default_cursor_shape = Control.CURSOR_POINTING_HAND


static func _caja_boton(fondo: Color, borde: Color) -> StyleBoxFlat:
	var s := caja(fondo, borde, 2)
	s.set_content_margin(SIDE_LEFT, 14)
	s.set_content_margin(SIDE_RIGHT, 14)
	s.set_content_margin(SIDE_TOP, 6)
	s.set_content_margin(SIDE_BOTTOM, 6)
	return s


## 15000.0 -> "15,000"; si trae centavos, 1999.5 -> "1999.50".
static func formato_dinero(valor: float) -> String:
	if not is_equal_approx(valor, roundf(valor)):
		return String.num(valor, 2)
	var entero := roundi(valor)
	var digitos := str(absi(entero))
	var salida := ""
	var cuenta := 0
	for i in range(digitos.length() - 1, -1, -1):
		salida = digitos[i] + salida
		cuenta += 1
		if cuenta % 3 == 0 and i > 0:
			salida = "," + salida
	return ("-" if entero < 0 else "") + salida
