extends RefCounted
## Descripciones in-game del catálogo (la tabla Catalogo_Productos no tiene
## columna de descripción, así que viven aquí).
##
## Se buscan por NOMBRE (sin el sufijo "(1U)"), no por id, para que sigan
## funcionando aunque cambie el orden de los ids en la base de datos.
## Si el backend algún día manda un campo "descripcion", ese tiene prioridad.
##
## Para evitar conflictos de Git: Andrés edita solo DESCRIPCIONES_1_A_10 y
## Valeria solo DESCRIPCIONES_11_A_20.

const DESCRIPCIONES_1_A_10 := {
	"Dull PowerBorde R110":
		"Servidor de entrada de 1U, ideal para empezar a llenar tu rack. Incluye un " +
		"controlador de gestión remota (tipo iDRAC): permite encenderlo, reiniciarlo y " +
		"diagnosticarlo por red aunque el sistema operativo esté caído, sin entrar al " +
		"cuarto de servidores. Barato y de bajo consumo, pero con poca capacidad de cómputo.",

	"HachePe ProLiante DL360":
		"El servidor 1U de uso general más común en centros de datos reales. Su gestión " +
		"remota iLO te deja vigilar temperatura, fuentes y fallas de hardware a distancia, " +
		"clave para atender incidentes rápido. Ofrece buen cómputo por cada U ocupada, a " +
		"cambio de más consumo eléctrico y más calor que un servidor básico.",

	"Lenorvo OverThink SR650":
		"Servidor de 2U con más bahías de disco y ranuras de expansión. Su capacidad " +
		"permite virtualización: varias máquinas virtuales comparten un mismo equipo físico " +
		"y aprovechan mejor cada Watt. Ocupa el doble de espacio en el rack, así que " +
		"conviene planear dónde va antes de comprarlo.",

	"HyperMicro MegaBlade X12":
		"Chasis blade de 3U que aloja varios servidores delgados y los hace compartir " +
		"fuentes de poder, ventiladores y red. Logra alta densidad de cómputo por cada U, " +
		"pero concentra mucho calor y consumo en poco espacio: necesitarás refrigeración " +
		"dedicada para que no se sobrecaliente.",

	"Envidia DGX-9000 TensorHorno":
		"Servidor de 4U con aceleradores GPU para cargas de inteligencia artificial y " +
		"cálculo masivo. Aporta una enorme cantidad de TFlops, pero consume muchísima " +
		"energía y genera calor extremo. Sin refrigeración líquida o de precisión, tu " +
		"centro de datos se sobrecalienta.",

	"NocturnaBúho FanTray Industrial":
		"Bandeja de ventiladores de 1U que empuja el aire frío del pasillo frío hacia el " +
		"pasillo caliente, evitando que ambos se mezclen. Es económica y de bajo consumo, " +
		"pero su capacidad de disipación es limitada: sirve para racks con pocos " +
		"servidores o poco calor.",

	"Corsario HydroLeak AIO":
		"Enfriamiento líquido de ciclo cerrado: una placa fría absorbe el calor del " +
		"procesador y un radiador lo disipa. Retira más calor que el aire usando el mismo " +
		"espacio. En la vida real una fuga puede dañar el hardware, por eso se instala y " +
		"se revisa con cuidado.",

	"VertiFrío Liebert InRow":
		"Unidad de enfriamiento in-row de 2U: se coloca junto a los racks para llevar el " +
		"aire frío justo a la fuente de calor, un estándar en centros de datos de alta " +
		"densidad. Baja mucho la temperatura, pero consume bastante energía, así que " +
		"revisa tu capacidad en Watts antes de instalarla.",

	"TermoTake Chiller H2O-Max":
		"Chiller de agua: enfría un circuito cerrado que da servicio a varios equipos a " +
		"la vez. Maneja cargas térmicas grandes y es la opción para un centro de datos " +
		"que ya creció, pero su consumo eléctrico es alto y ocupa 3U de tu rack.",

	"SubMarino Pod Dieléctrico":
		"Enfriamiento por inmersión: los servidores se sumergen en un líquido dieléctrico " +
		"que no conduce electricidad y absorbe el calor directamente. Es la opción más " +
		"eficiente (mejora el PUE, la relación entre energía total y energía útil), ideal " +
		"para equipos como el TensorHorno, pero cuesta mucho y ocupa 4U.",
}

# Valeria: estas 10 las dejó redactadas Andrés para completar el catálogo;
# edítalas libremente. Formato:  "Nombre sin (xU)": "texto".
const DESCRIPCIONES_11_A_20 := {
	"TrippCorto Regleta PDU-800":
		"Regleta de distribución de energía (PDU) montada en el rack. Reparte la " +
		"corriente a todos tus equipos y, en los modelos gestionables, mide el consumo " +
		"por salida y permite reiniciar un equipo a distancia. Aporta capacidad eléctrica " +
		"con muy poco espacio, pero nunca debes pasar la carga que soporta.",

	"APagón Smart-UPS 1500VA":
		"UPS (sistema de alimentación ininterrumpida) de 2U. Su batería mantiene tus " +
		"equipos encendidos durante un corte y filtra picos y variaciones de voltaje. " +
		"Te da los minutos necesarios para un apagado ordenado y evitar que un apagón " +
		"corrompa datos.",

	"Tragón 9PX Doble Conversión":
		"UPS de doble conversión: convierte la corriente de la red a continua y de " +
		"nuevo a alterna todo el tiempo, así tus equipos siempre reciben energía limpia " +
		"y no hay interrupción al fallar la red. Protege mejor que un UPS básico, pero " +
		"esa doble conversión gasta más energía y genera más calor.",

	"Chispazoneider Symmetra Li-Ion":
		"UPS modular de 3U con baterías de iones de litio. Duran más años, pesan menos " +
		"y ocupan menos que las de plomo-ácido, y puedes ampliar su capacidad por " +
		"módulos y sumar redundancia. Es una inversión alta que se paga con una " +
		"protección eléctrica más estable.",

	"Tésla MegaPila Nuclear-Pack":
		"Banco de baterías de gran capacidad para tener autonomía larga ante cortes " +
		"prolongados. En un centro de datos real se combina con un generador para " +
		"sostener la operación durante horas. Ofrece muchísimo respaldo eléctrico, pero " +
		"es caro y ocupa 4U de tu rack.",

	"MacroTik RouterBordo HEX-24":
		"Router de borde de 1U: la puerta de salida de tu centro de datos hacia otras " +
		"redes e Internet. Decide por dónde viaja cada paquete con su tabla de rutas. " +
		"Sin conectividad, tus servidores no pueden atender a nadie, por eso es una " +
		"compra básica.",

	"Chisco Catalizador 2960-Giga":
		"Switch de acceso gigabit de 1U. Conecta entre sí los servidores del rack y " +
		"permite separar el tráfico en VLAN para ordenar y aislar la red. Barato y de " +
		"poco consumo, ideal para crecer, aunque su ancho de banda es modesto.",

	"FuerteNet FortiMuro 600F":
		"Firewall de nueva generación de 2U: filtra el tráfico, detecta y bloquea " +
		"intrusos y crea túneles VPN seguros. Es una pieza clave de ciberseguridad: " +
		"frena los ataques antes de que lleguen a tus servidores y te ayuda a " +
		"resolver incidentes de seguridad.",

	"Arisca EtherSwitch 100G-Spine":
		"Switch de 2U con puertos de 100 Gigabit, pensado como \"spine\" en una " +
		"arquitectura spine-leaf: es la troncal que une a los demás switches con alto " +
		"ancho de banda y baja latencia. Mueve muchísimo tráfico, pero consume y " +
		"calienta más que un switch de acceso.",

	"Junípero PTX-TeraCore Óptico":
		"Router de núcleo de 3U con interfaces ópticas (fibra) capaz de mover " +
		"terabits por segundo: el backbone de un centro de datos grande. Ofrece un " +
		"ancho de banda enorme, pero es costoso, consume bastante energía y " +
		"necesita buena refrigeración.",
}


## Devuelve la descripción del producto, o "" si todavía no tiene.
static func buscar(nombre_producto: String) -> String:
	var buscada := clave(nombre_producto)
	for tabla in [DESCRIPCIONES_1_A_10, DESCRIPCIONES_11_A_20]:
		for nombre in tabla:
			if clave(nombre) == buscada:
				return tabla[nombre]
	return ""


# "Dull PowerBorde R110 (1U)" -> "dull powerborde r110"
# Pública: ImagenesProductos usa la misma regla para emparejar nombres.
static func clave(nombre: String) -> String:
	return nombre.split(" (")[0].strip_edges().to_lower()
