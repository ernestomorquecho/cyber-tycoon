extends Resource
class_name TicketData
## Espeja una fila real de Tickets_Soporte tal como la regresa
## GET /api/tickets/pendientes (ver src/routes/tickets.routes.js del backend).

@export var id_ticket: int = 0
@export var descripcion: String = ""
@export var icon: Texture2D # la tabla no maneja ícono/cliente todavía, placeholder

@export var teraflops_requeridos: float = 0.0
@export var anchoDeBanda_requerido: float = 0.0
@export var memoriaRequerida: float = 0.0

@export var recompensa_creditos: float = 0.0
@export var penalizacion_creditos: float = 0.0
@export var recompensa_reputacion: int = 0
@export var penalizacion_reputacion: int = 0

@export var fecha_limite: String = ""       # datetime ISO que regresa MySQL
@export var tiempo_para_completado: int = 30 # segundos, viene de "tiempoParaCompletado"


@export var decision_time_seconds: float = 15.0
