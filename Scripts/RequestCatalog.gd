extends RefCounted
class_name RequestCatalog
## Catálogo de solicitudes. Cada solicitante tiene un catálogo FIJO de 50
## solicitudes distintas (CATALOG_SIZE).
##
## Por ahora los 10 solicitantes comparten la misma lista base (TEMPLATES, 50
## entradas que escribí como punto de partida: ajusta títulos, requisitos y
## recompensas a tu gusto). Para darle a un solicitante su propio catálogo,
## agrega su lista de 50 en CATALOG_OVERRIDES con el índice del solicitante
## como llave (0 = av1, 1 = av2, ...). Un override con un tamaño distinto de 50
## se ignora y se avisa en consola.
##
## Campos de cada solicitud:
##   titulo, tf = teraflops, bw = ancho de banda, mem = memoria,
##   rc / pc = recompensa / penalización en créditos,
##   rr / pr = recompensa / penalización de reputación,
##   decision = segundos para aceptar, process = segundos de procesamiento.

const CATALOG_SIZE := 50

const CATALOG_OVERRIDES := {}

const TEMPLATES := [
	{"titulo": "Sitio Web Corporativo", "tf": 4, "bw": 30, "mem": 4, "rc": 120, "pc": 40, "rr": 8, "pr": 11, "decision": 32, "process": 23},
	{"titulo": "Correo Electrónico Institucional", "tf": 3, "bw": 40, "mem": 8, "rc": 110, "pc": 37, "rr": 8, "pr": 11, "decision": 32, "process": 22},
	{"titulo": "Respaldo Nocturno de Archivos", "tf": 5, "bw": 60, "mem": 8, "rc": 130, "pc": 43, "rr": 8, "pr": 11, "decision": 32, "process": 24},
	{"titulo": "Tienda en Línea Básica", "tf": 8, "bw": 70, "mem": 8, "rc": 160, "pc": 53, "rr": 9, "pr": 13, "decision": 34, "process": 26},
	{"titulo": "Portal de Citas Médicas", "tf": 6, "bw": 50, "mem": 8, "rc": 150, "pc": 50, "rr": 8, "pr": 11, "decision": 33, "process": 25},
	{"titulo": "Blog de Noticias Local", "tf": 3, "bw": 25, "mem": 4, "rc": 90, "pc": 30, "rr": 8, "pr": 11, "decision": 32, "process": 22},
	{"titulo": "Intranet de Recursos Humanos", "tf": 5, "bw": 35, "mem": 8, "rc": 120, "pc": 40, "rr": 8, "pr": 11, "decision": 32, "process": 24},
	{"titulo": "Sistema de Reservaciones de Hotel", "tf": 7, "bw": 60, "mem": 8, "rc": 155, "pc": 52, "rr": 9, "pr": 13, "decision": 34, "process": 26},
	{"titulo": "Hospedaje Web PYME", "tf": 12, "bw": 50, "mem": 8, "rc": 150, "pc": 50, "rr": 8, "pr": 11, "decision": 36, "process": 30},
	{"titulo": "Base de Datos de Inventario", "tf": 14, "bw": 80, "mem": 16, "rc": 200, "pc": 67, "rr": 11, "pr": 15, "decision": 37, "process": 31},
	{"titulo": "Plataforma de Cursos en Línea", "tf": 16, "bw": 120, "mem": 16, "rc": 260, "pc": 87, "rr": 14, "pr": 20, "decision": 38, "process": 33},
	{"titulo": "API de Pagos para Comercio", "tf": 18, "bw": 100, "mem": 16, "rc": 280, "pc": 93, "rr": 16, "pr": 22, "decision": 39, "process": 34},
	{"titulo": "Servidor de Videollamadas", "tf": 15, "bw": 250, "mem": 16, "rc": 270, "pc": 90, "rr": 15, "pr": 21, "decision": 38, "process": 32},
	{"titulo": "Servidor Streaming Video", "tf": 20, "bw": 350, "mem": 16, "rc": 300, "pc": 100, "rr": 17, "pr": 24, "decision": 40, "process": 36},
	{"titulo": "Almacenamiento de Fotografías", "tf": 11, "bw": 150, "mem": 32, "rc": 220, "pc": 73, "rr": 12, "pr": 17, "decision": 36, "process": 29},
	{"titulo": "CRM para Equipo de Ventas", "tf": 13, "bw": 70, "mem": 16, "rc": 210, "pc": 70, "rr": 12, "pr": 17, "decision": 36, "process": 30},
	{"titulo": "Sistema de Facturación Electrónica", "tf": 17, "bw": 90, "mem": 16, "rc": 260, "pc": 87, "rr": 14, "pr": 20, "decision": 38, "process": 34},
	{"titulo": "Servidor de Juegos Multijugador", "tf": 19, "bw": 300, "mem": 16, "rc": 300, "pc": 100, "rr": 17, "pr": 24, "decision": 40, "process": 35},
	{"titulo": "Portal Gubernamental de Trámites", "tf": 15, "bw": 110, "mem": 16, "rc": 250, "pc": 83, "rr": 14, "pr": 20, "decision": 38, "process": 32},
	{"titulo": "Analítica de Ventas en Tiempo Real", "tf": 18, "bw": 130, "mem": 24, "rc": 290, "pc": 97, "rr": 16, "pr": 22, "decision": 39, "process": 34},
	{"titulo": "Procesamiento IA / ML", "tf": 30, "bw": 200, "mem": 32, "rc": 450, "pc": 150, "rr": 25, "pr": 35, "decision": 45, "process": 44},
	{"titulo": "Renderizado de Animación 3D", "tf": 38, "bw": 180, "mem": 32, "rc": 520, "pc": 173, "rr": 29, "pr": 41, "decision": 49, "process": 50},
	{"titulo": "Simulación Climática Regional", "tf": 42, "bw": 150, "mem": 64, "rc": 600, "pc": 200, "rr": 33, "pr": 46, "decision": 51, "process": 54},
	{"titulo": "Minería de Datos para Banco", "tf": 34, "bw": 220, "mem": 48, "rc": 500, "pc": 167, "rr": 28, "pr": 39, "decision": 47, "process": 47},
	{"titulo": "Reconocimiento de Imágenes Médicas", "tf": 36, "bw": 160, "mem": 48, "rc": 540, "pc": 180, "rr": 30, "pr": 42, "decision": 48, "process": 49},
	{"titulo": "Plataforma de Trading Bursátil", "tf": 28, "bw": 400, "mem": 32, "rc": 480, "pc": 160, "rr": 27, "pr": 38, "decision": 44, "process": 42},
	{"titulo": "Análisis Genómico Universitario", "tf": 44, "bw": 120, "mem": 64, "rc": 640, "pc": 213, "rr": 35, "pr": 49, "decision": 52, "process": 55},
	{"titulo": "Entrenamiento de Modelo de Lenguaje", "tf": 48, "bw": 260, "mem": 64, "rc": 700, "pc": 233, "rr": 35, "pr": 49, "decision": 54, "process": 58},
	{"titulo": "Traducción Automática Masiva", "tf": 32, "bw": 210, "mem": 32, "rc": 470, "pc": 157, "rr": 26, "pr": 36, "decision": 46, "process": 46},
	{"titulo": "Procesamiento de Imágenes Satelitales", "tf": 40, "bw": 320, "mem": 48, "rc": 580, "pc": 193, "rr": 32, "pr": 45, "decision": 50, "process": 52},
	{"titulo": "Mitigar Ataque DDoS", "tf": 10, "bw": 300, "mem": 8, "rc": 260, "pc": 87, "rr": 14, "pr": 20, "decision": 20, "process": 23},
	{"titulo": "Contener Fuerza Bruta en SSH", "tf": 6, "bw": 40, "mem": 4, "rc": 180, "pc": 60, "rr": 10, "pr": 14, "decision": 20, "process": 20},
	{"titulo": "Responder a Ransomware en NAS", "tf": 16, "bw": 90, "mem": 16, "rc": 380, "pc": 127, "rr": 21, "pr": 29, "decision": 20, "process": 28},
	{"titulo": "Bloquear Campaña de Phishing", "tf": 8, "bw": 60, "mem": 8, "rc": 200, "pc": 67, "rr": 11, "pr": 15, "decision": 20, "process": 21},
	{"titulo": "Analizar Malware en Servidor de Correo", "tf": 12, "bw": 70, "mem": 16, "rc": 300, "pc": 100, "rr": 17, "pr": 24, "decision": 20, "process": 25},
	{"titulo": "Alerta de Intrusión en Firewall", "tf": 9, "bw": 80, "mem": 8, "rc": 240, "pc": 80, "rr": 13, "pr": 18, "decision": 20, "process": 22},
	{"titulo": "Contener Hackeo del Portal Web", "tf": 14, "bw": 110, "mem": 16, "rc": 340, "pc": 113, "rr": 19, "pr": 27, "decision": 20, "process": 26},
	{"titulo": "Ataque de Inyección SQL a la Base de Datos", "tf": 13, "bw": 90, "mem": 16, "rc": 330, "pc": 110, "rr": 18, "pr": 25, "decision": 20, "process": 25},
	{"titulo": "Alerta Térmica en el Rack Principal", "tf": 4, "bw": 20, "mem": 4, "rc": 200, "pc": 67, "rr": 11, "pr": 15, "decision": 20, "process": 18},
	{"titulo": "Detener Intrusión en Servidor de Archivos", "tf": 15, "bw": 100, "mem": 16, "rc": 360, "pc": 120, "rr": 20, "pr": 28, "decision": 20, "process": 27},
	{"titulo": "Migración a Nube Híbrida", "tf": 24, "bw": 280, "mem": 32, "rc": 420, "pc": 140, "rr": 23, "pr": 32, "decision": 42, "process": 39},
	{"titulo": "Recuperación ante Desastres", "tf": 22, "bw": 200, "mem": 32, "rc": 400, "pc": 133, "rr": 22, "pr": 31, "decision": 41, "process": 38},
	{"titulo": "Balanceador de Carga para Ecommerce", "tf": 17, "bw": 450, "mem": 16, "rc": 330, "pc": 110, "rr": 18, "pr": 25, "decision": 38, "process": 34},
	{"titulo": "Centro de Llamadas Virtual", "tf": 14, "bw": 220, "mem": 16, "rc": 280, "pc": 93, "rr": 16, "pr": 22, "decision": 37, "process": 31},
	{"titulo": "Red de Sensores IoT para Fábrica", "tf": 12, "bw": 180, "mem": 16, "rc": 260, "pc": 87, "rr": 14, "pr": 20, "decision": 36, "process": 30},
	{"titulo": "Respaldo Cifrado para Despacho Legal", "tf": 10, "bw": 90, "mem": 16, "rc": 240, "pc": 80, "rr": 13, "pr": 18, "decision": 35, "process": 28},
	{"titulo": "Portal de Telemedicina", "tf": 21, "bw": 260, "mem": 32, "rc": 400, "pc": 133, "rr": 22, "pr": 31, "decision": 40, "process": 37},
	{"titulo": "Sistema Bancario de Cajeros", "tf": 26, "bw": 150, "mem": 32, "rc": 460, "pc": 153, "rr": 26, "pr": 36, "decision": 43, "process": 41},
	{"titulo": "Servidor Universitario de Exámenes", "tf": 19, "bw": 140, "mem": 16, "rc": 310, "pc": 103, "rr": 17, "pr": 24, "decision": 40, "process": 35},
	{"titulo": "Plataforma de Ciudad Inteligente", "tf": 33, "bw": 380, "mem": 48, "rc": 560, "pc": 187, "rr": 31, "pr": 43, "decision": 46, "process": 46},
]


static func get_catalog(requester_index: int) -> Array:
	if CATALOG_OVERRIDES.has(requester_index):
		var custom: Array = CATALOG_OVERRIDES[requester_index]
		if custom.size() == CATALOG_SIZE:
			return custom
		push_warning("[RequestCatalog] El catálogo del solicitante %d tiene %d solicitudes y debe tener %d; se usa el catálogo base." % [requester_index, custom.size(), CATALOG_SIZE])
	return TEMPLATES


## Revisa que cada solicitante tenga exactamente 50 solicitudes y sin títulos repetidos.
static func validate(requester_count: int) -> bool:
	var ok := true
	for r in requester_count:
		var catalog := get_catalog(r)
		if catalog.size() != CATALOG_SIZE:
			push_error("[RequestCatalog] El solicitante %d no tiene %d solicitudes." % [r, CATALOG_SIZE])
			ok = false
		var seen := {}
		for entry in catalog:
			if seen.has(entry["titulo"]):
				push_error("[RequestCatalog] Título repetido en el solicitante %d: %s" % [r, entry["titulo"]])
				ok = false
			seen[entry["titulo"]] = true
	return ok


static func make_ticket_data(requester_index: int, request_index: int) -> TicketData:
	var entry: Dictionary = get_catalog(requester_index)[request_index]
	var data := TicketData.new()
	data.titulo = entry["titulo"]
	data.descripcion = entry["titulo"]
	data.teraflops_requeridos = float(entry["tf"])
	data.anchoDeBanda_requerido = float(entry["bw"])
	data.memoriaRequerida = float(entry["mem"])
	data.recompensa_creditos = float(entry["rc"])
	data.penalizacion_creditos = float(entry["pc"])
	data.recompensa_reputacion = int(entry["rr"])
	data.penalizacion_reputacion = int(entry["pr"])
	data.decision_time_seconds = float(entry["decision"])
	data.tiempo_para_completado = int(entry["process"])
	data.requester_index = requester_index
	data.request_index = request_index
	return data
