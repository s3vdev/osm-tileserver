# 🗺️ Offline OpenStreetMap Tile-Server (Docker-basiert)

Ein vollständiger, offlinefähiger OpenStreetMap Tile-Server – lokal gehostet per Docker, ideal für eigene Kartenanwendungen oder Intranets.

![Tile-Server Vorschau](germany-osm-tileserver.png)

---

## 📁 Verzeichnisstruktur

```
osm-server/
├── import/
│   ├── region.osm.pbf       ← OSM-Daten (z. B. Germany von Geofabrik)
│   ├── style/               ← Style-Verzeichnis (osm-carto, LUA, .style)
│   └── tiles/               ← Muss manuell existieren!
```

---

## 🚀 Setup in 5 Schritten

### 1. Repository vorbereiten

```bash
mkdir -p ~/osm-server/import/style
mkdir -p ~/osm-server/import/tiles
cd ~/osm-server
```

---

### 2. OSM-Daten herunterladen

```bash
wget https://download.geofabrik.de/europe/germany-latest.osm.pbf -O import/region.osm.pbf
```

---

### 3. Datenbank importieren

```bash
docker run -d \
  --name osm-import-background \
  -v $(pwd)/import:/data \
  overv/openstreetmap-tile-server import
```

### Logs prüfen:

```bash
docker logs -f osm-import-background
```

Fertig, wenn du siehst:
```
+ sudo -u renderer touch /data/database/planet-import-complete
+ service postgresql stop
```

---

### 4. Tile-Server starten

```bash
docker rm -f osm-server 2>/dev/null || true

docker run -d \
  --name osm-server \
  --shm-size=1g \
  -p 8080:80 \
  -v $(pwd)/import:/data \
  overv/openstreetmap-tile-server run
```

---

### 5. Test im Browser

```txt
http://<dein-server>:8080
```

---

## ✅ Status-Checkliste

| Aufgabe                                                | Status |
|---------------------------------------------------------|--------|
| PBF-Datei liegt als `region.osm.pbf` in `import/`       | ✅     |
| Style-Verzeichnis `import/style/` vorhanden             | ✅     |
| Verzeichnis `import/tiles/` vorhanden                   | ✅     |
| Import erfolgreich abgeschlossen                        | ✅     |
| Tile-Server läuft auf Port 8080                         | ✅     |

---

## 🔧 Nützliche Befehle

```bash
# Nur letzte 50 Zeilen vom Import:
docker logs osm-import-background | tail -n 50

# Prüfen ob Import noch läuft:
docker ps | grep osm-import-background

# Tile-Server-Logs anzeigen:
docker logs -f osm-server

# Tile-Server stoppen:
docker rm -f osm-server

# Tile-Server Ressourcennutzung:
docker stats
```

---

## ℹ️ Hinweis

Verwendetes Image:  
👉 [`overv/openstreetmap-tile-server`](https://hub.docker.com/r/overv/openstreetmap-tile-server)

Start erfolgt **ohne Docker Compose**, stattdessen direkt über `docker run` (besser kontrollierbar).
