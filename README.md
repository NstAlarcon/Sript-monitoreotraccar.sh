🛰️ ANTILOSS – Traccar Auto-Healing Monitor v2.4

Monitoreo avanzado, auto-recuperación y protección anti-caídas para servidores Traccar.

📌 Descripción

Este script proporciona un sistema de monitoreo avanzado para Traccar, capaz de detectar fallos, reiniciar automáticamente el servicio, enviar alertas por WhatsApp, bloquear dispositivos GPS flooders y hasta reiniciar todo el servidor si es necesario.

Ha sido diseñado para entornos de producción donde la estabilidad es crítica y un solo GPS defectuoso puede afectar todo el sistema.

🚀 Características principales
🟢 Monitoreo automático de Traccar

Verifica el estado del servicio.

Si está detenido → intenta reiniciarlo.

Notifica cada intento vía WhatsApp.

🔄 Auto-recuperación inteligente

Lleva un contador de fallos consecutivos.

Si Traccar falla 3 veces seguidas → reinicia el servidor completo.

Evita loops infinitos reseteando el contador al recuperarse.

🧠 Interpretación de errores en lenguaje natural

Detecta errores como:

“Premature end of file”

OutOfMemoryError

Exception

Problemas con Log4j

Los resume y los explica de forma amigable.

📋 Reporte de salud (se envía SIEMPRE)

Incluye:

Estado general

RAM

CPU

Uptime

Confirmación de que no hay errores

🛰️ Detector de GPS Flooders

Protege el servidor de dispositivos que envían demasiadas posiciones:

Identifica GPS con más de 25 posiciones por minuto

Informa vía WhatsApp

Registra en logs

🛑 Bloqueo automático de Flooders

Si un GPS supera el límite:

Se deshabilita automáticamente en Traccar vía API

Se notifica por WhatsApp

Se registra en /var/log/monitoreo_traccar.log

🧹 Limpieza automática de logs

Evita saturación del journal.

🏗️ Arquitectura del script
monitoreo.sh
│
├── Limpieza de logs
├── Verificación de servicio
├── Auto-reinicio de Traccar
├── Auto-reboot del servidor
├── Lectura de RAM / CPU
├── Detección de errores
├── Detector de Flooders
├── Bloqueo automático
└── Reporte de salud

📦 Requisitos
Dependencias

Bash

curl

MySQL/MariaDB client

systemd (para systemctl)

journalctl

Traccar 5.x / 6.x

API de WhatsApp/endpoint propio (HTTP POST)

Permisos

Debe ejecutarse con root, ya que:

reinicia servicio

reinicia servidor

lee journal

usa MySQL

accede a /var/tmp

⚙️ Configuración

Editar estas variables:

NUMERO="aquitunumerowhasapp"       # Número de WhatsApp al que se enviarán alertas
ENDPOINT="http://IP:PORT/enviar"  # API para enviar mensajes
DB_USER="root"             # Usuario DB
DB_PASS="CONTRASEÑA"       # Contraseña DB


Colocar el script en:

/root/monitoreo.sh


Dar permisos:

chmod +x /root/monitoreo.sh


Programar ejecución automática cada 5 min:

crontab -e

*/5 * * * * /root/monitoreo.sh

🛰️ Explicación de cada módulo
1️⃣ Limpieza de logs

Elimina entradas de más de 2 días para evitar saturación:

journalctl -u traccar --vacuum-time=2d

2️⃣ Verificación del estado de Traccar

Si está detenido → intenta reiniciar.

3️⃣ Auto-recovery

Registra intentos fallidos en /var/tmp/traccar_fails.count.

Si llega a 3 fallos → reinicio general del VPS.

4️⃣ Métricas del proceso

Obtiene RAM y CPU del proceso Java:

ps -p $PID -o %mem=
ps -p $PID -o %cpu=

5️⃣ Detección e interpretación de errores

Detecta errores importantes en los últimos logs y los interpreta en texto humano.

6️⃣ Detector de GPS Flooders

Consulta MySQL:

SELECT deviceid, COUNT(*)
FROM positions
WHERE fixTime > NOW() - INTERVAL 1 MINUTE
HAVING COUNT(*) > 25

7️⃣ Bloqueo automático

Llama a la API de Traccar:

curl -X PUT "http://localhost:8082/api/devices/$ID" \
-d '{"disabled": true}'

8️⃣ Reporte de salud

Se envía SIEMPRE que no haya errores críticos.

🔓 Cómo desbloquear un dispositivo Flooder
📌 Desde Traccar (recomendado)

Ir a Dispositivos

Seleccionar el dispositivo

Cambiar “Deshabilitado” → false

Guardar

📌 Desde API
curl -X PUT "http://localhost:8082/api/devices/17" \
-H "Content-Type: application/json" \
-d '{"id":17,"disabled":false}'

📌 Desde MySQL
UPDATE devices SET disabled = 0 WHERE id = 17;

📄 Archivos generados
/var/log/monitoreo_traccar.log

Contiene:

Intentos de reinicio

Errores detectados

Bloqueos de flooders

Reportes enviados

/var/tmp/traccar_fails.count

Guarda cuántas veces seguidas falló Traccar.

📬 Notificaciones por WhatsApp

Ejemplos:

✔ Servicio caído
⚠️ Traccar detenido. Intento de reinicio #2

✔ Flooder detectado
🚨 GPS FLOODER DETECTADO
ID 17 – Toyota Hilux
47 posiciones/min

✔ Bloqueo automático
⛔ Bloqueando dispositivo flooder: Hilux (ID 17)

✔ Estado normal
📋 REPORTE DE SALUD
🧠 RAM: 31%
⚙️ CPU: 5%
🟢 Todo funcionando correctamente.

🔐 Seguridad

No expone contraseñas en logs

No deja dispositivos bloqueados sin aviso

No ejecuta acciones destructivas

Auto-reboot solo ocurre en falla real (3 veces seguidas)

Protege contra loops infinitos

🧪 Pruebas recomendadas

Detener Traccar manualmente:

systemctl stop traccar


Ejecutar el script:

./monitoreo.sh


Debe:

Detectar caída

Reiniciar

Notificar

Simular flooder
Insertar 30 posiciones/min:

INSERT INTO positions ...


O configurar un GPS a 1 segundo.

Debe:

Detectarlo

Alertar

Bloquear

Forzar 3 fallos seguidos
Renombrar temporalmente el .jar
Debe disparar reboot.

📃 Licencia

MIT – uso libre para proyectos Traccar y monitoreo.

✨ Autor

Néstor – Antiloss GPS
Monitoreo avanzado y anti-caídas para servidores Traccar en producción.
