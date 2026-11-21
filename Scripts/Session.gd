extends RefCounted
class_name Session
## Punto único donde vive el token del jugador autenticado.
## login.gd escribe aquí el token de POST /api/auth/login (GameData.token_jwt
## solo reenvía a esta variable). Si jwt_token está vacío (escena corrida suelta
## sin login), Helpdesk.gd y TicketCard.gd caen a modo simulación.

static var jwt_token: String = ""
static var base_url: String = "https://cybertycoon-server.tail45d52a.ts.net"


static func auth_headers() -> PackedStringArray:
	return PackedStringArray([
		"Content-Type: application/json",
		"Authorization: Bearer %s" % jwt_token
	])
