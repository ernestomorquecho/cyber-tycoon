extends Control
class_name Rack
## Va sobre el nodo raíz de Escenas/Dashboard/Rack.tscn.
## Dibuja un rack del carrusel: una franja por cada U del rack. Cada equipo
## enciende tantas franjas como U ocupa (un servidor 2U = 2 franjas).
##   - Encendido: verde/cian parpadeando (rojo rápido si hay alerta térmica)
##   - Apagado:   gris tenue fijo (sigue ocupando su lugar)
##   - Libre:     casi negro

const COLOR_OK_A := Color(0, 1, 0.25490196)   # #00FF41
const COLOR_OK_B := Color(0, 1, 1)            # #00FFFF
const COLOR_ALERT := Color(1, 0.11764706, 0.11764706)
const COLOR_ALERT_DIM := Color(0.3, 0, 0)
const COLOR_OFF := Color(0.35, 0.35, 0.38)
const COLOR_EMPTY := Color(0.15, 0.15, 0.15)

# Tamaño de cada franja: 14 franjas deben caber dentro del marco de rack.png.
const LED_SIZE := Vector2(130, 14)
const LED_SEPARATION := 5

@onready var _id_label: Label = %RackIdLabel
@onready var _usage_label: Label = %UsageLabel
@onready var _slots_grid: GridContainer = %SlotsGrid
@onready var _blink_timer: Timer = $BlinkTimer

var _data: RackData
var _leds_encendidos: Array = []
var _blink_on: bool = true
var _firma: String = "" # evita reconstruir las franjas si nada cambió


func _ready() -> void:
	_slots_grid.add_theme_constant_override("v_separation", LED_SEPARATION)
	_blink_timer.timeout.connect(_on_blink_timer_timeout)


func setup(data: RackData) -> void:
	var alerta_previa := _data.en_alerta if _data else false
	_data = data
	_data.en_alerta = alerta_previa
	_id_label.text = "RACK %02d" % data.id_rack
	_usage_label.text = "%d/%d U" % [data.espacio_usado, data.espacio_total]

	var firma := "%d|%s" % [data.espacio_total, JSON.stringify(data.equipos)]
	if firma != _firma:
		_firma = firma
		_rebuild_slots()


## Acelera el parpadeo a rojo intenso (temperatura crítica).
func set_alert(active: bool) -> void:
	if _data == null:
		return
	_data.en_alerta = active
	_blink_timer.wait_time = 0.15 if active else 0.5


func _rebuild_slots() -> void:
	for child in _slots_grid.get_children():
		child.queue_free()
	_leds_encendidos.clear()

	# slot -> encendido (true/false); los slots libres no aparecen
	var ocupacion := {}
	for equipo in _data.equipos:
		var inicio := int(equipo.get("slot_inicio", 0))
		for i in int(equipo.get("espacio", 1)):
			ocupacion[inicio + i] = bool(equipo.get("encendido", true))

	for slot in range(_data.espacio_total):
		var led := ColorRect.new()
		led.custom_minimum_size = LED_SIZE
		led.mouse_filter = Control.MOUSE_FILTER_IGNORE
		if not ocupacion.has(slot):
			led.color = COLOR_EMPTY
		elif ocupacion[slot]:
			led.color = COLOR_OK_A
			_leds_encendidos.append(led)
		else:
			led.color = COLOR_OFF
		_slots_grid.add_child(led)


func _on_blink_timer_timeout() -> void:
	if _data == null:
		return
	_blink_on = not _blink_on
	for led in _leds_encendidos:
		if _data.en_alerta:
			led.color = COLOR_ALERT if _blink_on else COLOR_ALERT_DIM
		else:
			led.color = COLOR_OK_A if _blink_on else COLOR_OK_B
