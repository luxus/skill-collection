# skill-collection

Personal skill collection for Pi AI Agent - Swiss weather data via MeteoSwiss Open Government Data.

## MeteoSwiss OGD Skill

**Datenquelle:** [MeteoSwiss Open Data](https://data.geo.admin.ch) - Kein API-Key nötig.

### Agent Interface (Primary)

```bash
./weather-agent "Zürich"     # JSON für Agent-Interpretation
./weather-agent 8001         # PLZ → JSON
./weather-agent "Regnet es morgen in Basel?"  # Natürliche Sprache → JSON
```

**Output:** Strukturiertes JSON mit `current` (aktuelles Wetter) und `forecast` (Prognose).

Der **Agent** (ich) interpretiert die Daten und antworte in natürlicher Sprache.

### CLI Tools (Debugging/Fallback)

```bash
./weather 8001              # Menschenlesbare Ausgabe
./rain-check 4001           # Einfacher Ja/Nein Regen-Check
./weather-json "Bern"       # Alternative JSON-Wrapper
```

### Features

| Feature | Beschreibung |
|---------|-------------|
| **PLZ** | Jede Schweizer 4-stellige Postleitzahl |
| **Ortsnamen** | Mit/ohne Umlaute (Zürich = Zurich) |
| **Auto-Download** | Datenbanken von GitHub Releases (~1 MB) |
| **Smart Matching** | Nächste Wetterstation via Koordinaten |
| **JSON Output** | Für AI-Interpretation optimiert |

### Erster Start

```bash
# Datenbanken werden automatisch heruntergeladen:
./weather-agent "Zürich"
# → Download von github.com/luxus/skill-collection/releases
# → ~1 MB, wenige Sekunden
```

### Datenbanken

**Automatische Updates:**
- Workflow: `.github/workflows/update-databases.yml`
- Release: https://github.com/luxus/skill-collection/releases
- Download: `curl -L https://github.com/luxus/skill-collection/releases/latest/download/plz-station-map.json`

**Lokaler Cache:**
- `~/.cache/meteoswiss-ogd/plz-station-map.json` (~3200 PLZ → Stationen)
- `~/.cache/meteoswiss-ogd/city-plz-map.json` (~4000 Orte → PLZ)

### Files

| File | Zweck | Nutzer |
|------|-------|--------|
| `weather-agent` | **JSON für Agent** | **AI Agent (ich)** |
| `weather` | Menschenlesbar | Debugging |
| `rain-check` | Ja/Nein Regen | Schnell-Check |
| `weather-json` | Alternative JSON | Legacy |

### Installation

```bash
# Via Pi
pi install git:github.com/luxus/skill-collection

# Manuell
git clone https://github.com/luxus/skill-collection.git
```

### Data Source

| | |
|---|---|
| **Provider** | [MeteoSwiss](https://www.meteoswiss.admin.ch/) |
| **Open Data** | [data.geo.admin.ch](https://data.geo.admin.ch) |
| **Lizenz** | Open Government Data (CC BY 4.0) |
| **Updates** | Alle 10 Min (Wetter), stündlich (Prognose) |

### CI/CD

- **Trigger:** 1. jeden Monats (oder manuell)
- **Workflow:** `.github/workflows/update-databases.yml`
- **Output:** Automatisches Release mit aktualisierten JSON-Dateien

## License

MIT - See LICENSE file
