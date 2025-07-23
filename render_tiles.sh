#!/bin/bash

CONTAINER=osm-server
MIN_ZOOM=9
MAX_ZOOM=18
BBOX="5.5 47.2 15.5 55.1"

LOGDIR="./render_logs"
DONELIST="$LOGDIR/done.txt"
mkdir -p "$LOGDIR"
touch "$DONELIST"

echo ""
echo "Starte Pre-Rendering von Zoom $MIN_ZOOM bis $MAX_ZOOM ..."
echo ""

# Prüfe ob Container läuft
if ! docker ps | grep -q "$CONTAINER"; then
    echo "ERROR: Container '$CONTAINER' läuft nicht!"
    echo "   Starte den Tile-Server mit:"
    echo "   docker run -d --name osm-server --shm-size=1g -p 8080:80 -v \$(pwd)/import:/data overv/openstreetmap-tile-server run"
    exit 1
fi

echo "OK: Container '$CONTAINER' läuft"

# Prüfe ob renderd im Container verfügbar ist
if ! docker exec "$CONTAINER" which render_list >/dev/null 2>&1; then
    echo "ERROR: render_list ist im Container nicht verfügbar!"
    echo "   Prüfe ob der Import abgeschlossen ist."
    exit 1
fi

echo "OK: render_list ist verfügbar"

# Prüfe Tile-Verzeichnis im Container
if ! docker exec "$CONTAINER" test -d "/var/lib/mod_tile/default"; then
    echo "WARNUNG: /var/lib/mod_tile/default existiert nicht"
    echo "   Versuche Verzeichnis zu erstellen..."
    docker exec "$CONTAINER" mkdir -p "/var/lib/mod_tile/default"
fi

echo ""
echo "Starte sequenzielles Rendering im Hintergrund..."
echo ""

# Starte das Script im Hintergrund mit nohup
nohup bash -c '
for ZOOM in $(seq '"$MIN_ZOOM"' '"$MAX_ZOOM"'); do
    if grep -q "^$ZOOM$" "'"$DONELIST"'"; then
        echo "OK: Zoom $ZOOM wurde bereits erledigt – übersprungen." >> "'"$LOGDIR"'/background.log"
        continue
    fi

    echo "Starte Zoom $ZOOM ..." >> "'"$LOGDIR"'/background.log"
    LOGFILE="'"$LOGDIR"'/zoom_$ZOOM.log"

    echo "=== Zoom $ZOOM Render Start ===" > "$LOGFILE"
    echo "Zeit: $(date)" >> "$LOGFILE"
    echo "Container: '"$CONTAINER"'" >> "$LOGFILE"
    echo "BBOX: '"$BBOX"'" >> "$LOGFILE"
    echo "" >> "$LOGFILE"
    
    docker exec "'"$CONTAINER"'" render_list \
        -a \
        -z $ZOOM -Z $ZOOM \
        -n 4 \
        -m default \
        -s /var/run/renderd/renderd.sock \
        -t /var/lib/mod_tile/default \
        '"$BBOX"' >> "$LOGFILE" 2>&1

    EXIT_CODE=$?
    echo "" >> "$LOGFILE"
    echo "=== Zoom $ZOOM Render Ende ===" >> "$LOGFILE"
    echo "Exit Code: $EXIT_CODE" >> "$LOGFILE"
    echo "Zeit: $(date)" >> "$LOGFILE"

    if [ $EXIT_CODE -eq 0 ]; then
        echo "$ZOOM" >> "'"$DONELIST"'"
        echo "OK: Zoom $ZOOM abgeschlossen." >> "'"$LOGDIR"'/background.log"
    else
        echo "ERROR: Fehler beim Rendern von Zoom $ZOOM (Exit Code: $EXIT_CODE)" >> "'"$LOGDIR"'/background.log"
        echo "   Log: $LOGFILE" >> "'"$LOGDIR"'/background.log"
        echo "Rendering gestoppt wegen Fehler." >> "'"$LOGDIR"'/background.log"
        exit 1
    fi
done

echo "ALLE ZOOM-LEVEL ERFOLGREICH GERENDERT!" >> "'"$LOGDIR"'/background.log"
' > "$LOGDIR/background.log" 2>&1 &

BACKGROUND_PID=$!
echo "Render-Prozess gestartet mit PID: $BACKGROUND_PID"
echo "Logs: $LOGDIR"
echo "Fortschritt verfolgen: tail -f $LOGDIR/background.log"
echo ""
echo "Du kannst dich jetzt abmelden - das Rendering läuft weiter!"
echo "Zum Stoppen: docker exec osm-server pkill -f render_list" 