# README Profesor — Cómo conectar Cyber Tycoon a un servidor

El juego (Godot) no guarda nada por sí solo: todo (créditos, compras, racks,
tickets) vive en el **backend** (API Node.js + MySQL). Por eso, antes de jugar,
el juego debe saber **a qué servidor conectarse**.

Ese dato está en **una sola línea de un solo archivo**:

| Archivo | Línea | Qué contiene |
| :--- | :--- | :--- |
| `Scripts/Session.gd` | **9** | `static var base_url: String = "..."` |

Hoy viene configurado así (servidor del equipo en la Orange Pi):

```gdscript
static var base_url: String = "https://cybertycoon-server.tail45d52a.ts.net"
```

> **Reglas de la URL:** sin `/api` al final y sin `/` al final. El juego agrega
> solo las rutas (`/api/auth/login`, `/api/tienda/...`).

---

## Opción A — Usar el servidor del equipo (recomendado)

1. No cambies nada: `base_url` ya apunta al servidor.
2. Revisa que el servidor esté encendido abriendo en el navegador:
   `https://cybertycoon-server.tail45d52a.ts.net/api/health`
   Debe responder `{"status":"OK", ...}`.
3. Entra al **panel docente**:
   `https://cybertycoon-server.tail45d52a.ts.net/admin-dashboard`
   - Regístrate como profesor (nombre, correo, contraseña y la **clave maestra
     institucional**; pídela al administrador del servidor).
   - Crea una **clase** y anota su código (`CT-XXXXX`).
   - Da de alta a los **alumnos** de esa clase.
4. Abre el proyecto en Godot y presiona **F5**. En el login escribe el nombre
   del alumno y el código de la clase.

---

## Opción B — Pruebas locales (servidor en tu propia computadora)

Úsala para desarrollar o probar sin depender del servidor del equipo.

### 1. Levantar el backend local
Requiere **Docker Desktop** y el repositorio del backend clonado.

```powershell
cd ruta\al\backend
copy .env.example .env      # la primera vez; edita los valores dentro
docker compose up -d --build
docker compose ps           # ct-mysql y ct-api deben decir "healthy"
```

Comprueba en el navegador: `http://127.0.0.1:3000/api/health`

> Si tu base local se creó **antes** de alguna migración (`database/migrations/`
> del backend), aplícalas todas con este comando desde la carpeta del backend.
> Las que ya estaban aplicadas responden `Duplicate column name ...`: es normal.
> ```powershell
> foreach ($f in Get-ChildItem database\migrations\*.sql) { "== $($f.Name)"; docker cp $f.FullName ct-mysql:/tmp/migracion.sql; docker exec ct-mysql sh -c 'mysql -uroot -p$MYSQL_ROOT_PASSWORD --default-character-set=utf8mb4 cyber_tycoon < /tmp/migracion.sql' }
> ```

### 2. Apuntar el juego a tu computadora
En `Scripts/Session.gd`, **línea 9**, cambia la URL por:

```gdscript
static var base_url: String = "http://127.0.0.1:3000"
```

### 3. Crear profesor, clase y alumnos locales
Tu base local es **independiente** del servidor del equipo: hay que crear todo de nuevo.

1. Abre `http://127.0.0.1:3000/admin-dashboard`.
2. Regístrate como profesor usando como clave maestra el valor de
   `ADMIN_REGISTRATION_KEY` de **tu** archivo `.env` del backend.
3. Crea una clase y da de alta alumnos.
4. En Godot presiona **F5** e inicia sesión con un alumno local.

### 4. Volver al servidor del equipo
Regresa la línea 9 de `Scripts/Session.gd` a:

```gdscript
static var base_url: String = "https://cybertycoon-server.tail45d52a.ts.net"
```

## Problemas comunes

| Síntoma | Causa probable | Solución |
| :--- | :--- | :--- |
| "SIN RESPUESTA DEL SERVIDOR" en el login | Servidor apagado o URL mal escrita | Revisa `/api/health` en el navegador y la línea 9 de `Session.gd` |
| "EL CÓDIGO DE CLASE NO EXISTE" | Código de otro servidor (local vs. equipo) | Crea la clase en el panel del mismo servidor al que apunta el juego |
| "ESTUDIANTE NO REGISTRADO EN ESTA CLASE" | El alumno no fue dado de alta | Agrégalo desde el panel docente |
| La clave maestra es rechazada | Se usa la clave de otro servidor | Cada servidor tiene la suya en su `.env` |
