extends Control
class_name Rack
## Va sobre el nodo raíz de Escenas/Dashboard/Rack.tscn.
## Dibuja un rack del carrusel: marco gris metálico + un LED por servidor
## instalado. Verde/cian parpadeando = estable. Rojo parpadeo rápido =
## sobrecarga o ciberataque activo (hay que abrir Inventario a apagar cosas).

const COLOR_OK_A := Color(0, 1, 0.25490196)   # #00FF41
const COLOR_OK_B := Color(0, 1, 1)            # #00FFFF
const COLOR_ALERT := Color(1, 0.11764706, 0.11764706)
const COLOR_ALERT_DIM := Color(0.3, 0, 0)
const COLOR_EMPTY := Color(0.15, 0.15, 0.15)

@onready var _id_label: Label = %RackIdLabel
@onready var _usage_label: Label = %UsageLabel
@onready var _slots_grid: GridContainer = %SlotsGrid
@onready var _blink_timer: Timer = $BlinkTimer

var _data: RackData
var _leds: Array = []
var _blink_on: bool = true


func _ready() -> void:
	_blink_timer.timeout.connect(_on_blink_timer_timeout)


func setup(data: RackData) -> void:
	_data = data
	_id_label.text = "RACK %02d" % data.id_rack
	_usage_label.text = "%d/%d U" % [data.espacio_usado, data.espacio_total]
	_rebuild_slots()


## Actívalo cuando el JSON del dashboard reporte sobrecarga o un ticket de
## ciberataque activo sobre este rack. Acelera el parpadeo a rojo intenso.
func set_alert(active: bool) -> void:
	if _data == null:
		return
	_data.en_alerta = active
	_blink_timer.wait_time = 0.15 if active else 0.5


func _rebuild_slots() -> void:
	for child in _slots_grid.get_children():
		child.queue_free()
	_leds.clear()

	for i in range(_data.espacio_total):
		var led := ColorRect.new()
		led.custom_minimum_size = Vector2(10, 10)
		led.color = COLOR_OK_A if i < _data.espacio_usado else COLOR_EMPTY
		_slots_grid.add_child(led)
		if i < _data.espacio_usado:
			_leds.append(led)


func _on_blink_timer_timeout() -> void:
	_blink_on = not _blink_on
	for led in _leds:
		if _data.en_alerta:
			led.color = COLOR_ALERT if _blink_on else COLOR_ALERT_DIM
		else:
			led.color = COLOR_OK_A if _blink_on else COLOR_OK_B
