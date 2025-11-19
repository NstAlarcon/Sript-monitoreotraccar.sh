#!/bin/bash
# ======================================================
# 🛰️ MONITOREO AVANZADO DE TRACCAR (v2.4)
# ======================================================
# Incluye:
# ✔ Limpieza de logs
# ✔ Detección de errores
# ✔ Interpretación en lenguaje natural
# ✔ Reporte de salud SIEMPRE
# ✔ Reinicio automático de Traccar
# ✔ Reboot si Traccar falla 3 veces seguidas
# ✔ Detector de GPS Flooders (más de 25/min)
# ✔ Bloqueo automático de flooders
# ✔ Alertas a WhatsApp

SERVICIO="traccar"
LOG="/var/log/monitoreo_traccar.log"
FECHA=$(date "+%Y-%m-%d %H:%M:%S")
ENDPOINT="http://159.54.130.253:3000/enviar"
NUMERO="50245214000"

DB_USER="root"
DB_PASS="-Nesala6794"
DB_NAME="antiloss"

# ======================================================
# 📤 FUNCIÓN PARA ENVIAR A WHATSAPP
# ======================================================
enviar_whatsapp() {
    MENSAJE=$(echo "$1" | tr '\n' ' ' | tr -d '"' | cut -c1-500)
    /usr/bin/curl -s -X POST "$ENDPOINT" \
        -H "Content-Type: application/json" \
        -d "{\"numero\":\"$NUMERO\",\"mensaje\":\"$MENSAJE\"}" \
        >> "$LOG" 2>&1
}

# ======================================================
# 🔁 AUTO-RECOVERY: CONTADOR DE FALLOS
# ======================================================
COUNT_FILE="/var/tmp/traccar_fails.count"
if [ ! -f "$COUNT_FILE" ]; then
    echo "0" > "$COUNT_FILE"
fi

RETRY_COUNT=$(cat $COUNT_FILE)

# ======================================================
# 🧹 Limpieza de logs del journal (solo de Traccar)
# ======================================================
journalctl -u traccar --vacuum-time=2d >/dev/null 2>&1

# ======================================================
# 1️⃣ ESTADO DEL SERVICIO + AUTO RECUPERACIÓN
# ======================================================
STATUS=$(systemctl is-active $SERVICIO)

if [ "$STATUS" != "active" ]; then

    echo "$FECHA - ⚠️ Traccar detenido. Intento de reinicio #$((RETRY_COUNT+1))" | tee -a "$LOG"
    enviar_whatsapp "⚠️ $FECHA - Traccar detenido. Intento de reinicio #$((RETRY_COUNT+1))"

    systemctl restart $SERVICIO
    sleep 12

    NEW_STATUS=$(systemctl is-active $SERVICIO)

    if [ "$NEW_STATUS" = "active" ]; then
        echo "0" > "$COUNT_FILE"
        enviar_whatsapp "🟢 $FECHA - Traccar se recuperó correctamente en el intento #$((RETRY_COUNT+1))"
    else
        RETRY_COUNT=$((RETRY_COUNT+1))
        echo "$RETRY_COUNT" > "$COUNT_FILE"

        enviar_whatsapp "❌ $FECHA - Traccar sigue sin arrancar (fallo #$RETRY_COUNT)."

        if [ "$RETRY_COUNT" -ge 3 ]; then
            enviar_whatsapp "🚨 $FECHA - Traccar falló 3 veces consecutivas. Reiniciando el servidor completo..."
            echo "0" > "$COUNT_FILE"
            echo "$FECHA - 🚨 Reboot total por fallos consecutivos" >> "$LOG"
            sleep 5
            reboot
        fi
    fi
fi

# ======================================================
# 2️⃣ MÉTRICAS RAM Y CPU
# ======================================================
PID=$(pgrep -f "tracker-server.jar")
if [ -n "$PID" ]; then
    MEM=$(ps -p $PID -o %mem= | awk '{print $1}')
    CPU=$(ps -p $PID -o %cpu= | awk '{print $1}')
else
    MEM="0"
    CPU="0"
fi

# ======================================================
# 3️⃣ DETECCIÓN DE ERRORES EN TRACCAR
# ======================================================
ERRORES=$(journalctl -u traccar -n 40 | grep -Ei "error|fatal|exception|premature|memory")

EXPLICACION=""
HAY_ERRORES=0

if [ -n "$ERRORES" ]; then
    HAY_ERRORES=1

    if echo "$ERRORES" | grep -qi "premature end of file"; then
        EXPLICACION+="⚠️ Archivo XML dañado o incompleto. "
    fi

    if echo "$ERRORES" | grep -qi "outofmemory"; then
        EXPLICACION+="🚨 Traccar se está quedando sin memoria. "
    fi

    if echo "$ERRORES" | grep -qi "exception"; then
        EXPLICACION+="⚠️ Excepción interna en Traccar. "
    fi

    if echo "$ERRORES" | grep -qi "log4j"; then
        EXPLICACION+="⚠️ Problema con Log4j detectado. "
    fi

    if [ -z "$EXPLICACION" ]; then
        EXPLICACION="⚠️ Se detectaron errores recientes en Traccar."
    fi

    enviar_whatsapp "🚨 $FECHA - Nuevos errores detectados en Traccar.  
Resumen: $(echo "$ERRORES" | tr '\n' ' ')  
Interpretación: $EXPLICACION"

    echo "$FECHA - Errores detectados: $EXPLICACION" >> "$LOG"
fi

# ======================================================
# 🛰️ 4️⃣ DETECTOR DE GPS FLOODERS (más de 25/min)
# ======================================================

FLOODERS=$(mysql -u $DB_USER -p$DB_PASS -N -e "
SELECT devices.id, devices.name, COUNT(*) AS total
FROM positions
JOIN devices ON positions.deviceid = devices.id
WHERE positions.fixTime > NOW() - INTERVAL 1 MINUTE
GROUP BY positions.deviceid
HAVING total > 25;
" $DB_NAME 2>/dev/null)

if [ -n "$FLOODERS" ]; then
    enviar_whatsapp "🚨 *GPS FLOODER DETECTADO*  
Uno o más dispositivos están enviando más de *25 posiciones por minuto*.  
Esto puede causar caídas del servidor.  
Detalle: $FLOODERS"

    echo "$FECHA - FLOODER DETECTADO: $FLOODERS" >> "$LOG"

    # ======================================================
    # 🛑 BLOQUEO AUTOMÁTICO DE GPS FLOODERS
    # ======================================================
    while read -r ID NAME TOTAL; do
        enviar_whatsapp "⛔ Bloqueando dispositivo flooder: $NAME (ID $ID), envió $TOTAL posiciones/min"

        curl -s -X PUT "http://localhost:8082/api/devices/$ID" \
        -H "Content-Type: application/json" \
        -d "{\"id\":$ID,\"disabled\":true}"

        echo "$FECHA - Dispositivo $NAME (ID $ID) bloqueado automáticamente" >> "$LOG"
    done <<< "$FLOODERS"
fi

# ======================================================
# 5️⃣ REPORTE DE SALUD (solo si NO hay errores)
# ======================================================
UPTIME=$(systemctl show -p ActiveEnterTimestamp traccar | cut -d= -f2)

if [ $HAY_ERRORES -eq 0 ]; then
    enviar_whatsapp "📋 *REPORTE DE SALUD - $FECHA*  
🟢 Sin errores detectados.  
🧠 RAM: ${MEM}%  
⚙️ CPU: ${CPU}%  
⏱️ Uptime: $UPTIME  
Todo funcionando correctamente."
fi

echo "$FECHA - Reporte enviado" >> "$LOG"
echo "--------------------------------------------------------" >> "$LOG"
