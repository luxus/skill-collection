---
name: meteoswiss-ogd
description: >-
  MeteoSwiss Open Government Data für AI Agents.
  Liefert strukturierte Wetterdaten für Interpretation durch den Agent.
  Unterstützt Postleitzahlen und Ortsnamen.
globs: []
---

# MeteoSwiss Open Government Data (Agent Interface)

**Datenquelle:** `data.geo.admin.ch` (MeteoSwiss Open Data)  
**Update-Interval:** Alle 10 Minuten (Wetter), stündlich (Prognose)

## Für AI Agents

Dieser Skill ist optimiert für AI Agents. Der Agent ruft das Interface auf, 
verarbeitet die strukturierten JSON-Daten und generiert natürliche Antworten.

### Haupt-Interface

```bash
${CLAUDE_SKILL_DIR}/weather-agent <query>
```

**Query-Formate:**
- Postleitzahl: `8001`, `4001`, `6003`
- Ortsname: `"Zürich"`, `"Bern"`, `"Basel"`
- Natürliche Sprache: `"Wetter in Zürich"`, `"Regnet es morgen?"`

**Return:** JSON mit allen relevanten Daten

### Beispiel-Response

```json
{
  "query_plz": "8001",
  "station": "SMA",
  "station_name": "Zürich / Fluntern",
  "current": {
    "temperature_c": 14.9,
    "humidity_percent": 34.0,
    "wind_speed_kmh": 4.3,
    "precipitation_mm": 0.0
  },
  "forecast": [
    {
      "day_label": "Heute",
      "max_temp_c": 14.9,
      "min_temp_c": 6.4,
      "rain_mm": 0.0,
      "will_rain": false
    },
    {
      "day_label": "Morgen",
      "max_temp_c": 13.5,
      "min_temp_c": 4.9,
      "rain_mm": 0.0,
      "will_rain": false
    }
  ],
  "rain_analysis": {
    "rain_today": false,
    "rain_tomorrow": false,
    "rainy_days_count": 0,
    "next_rain_day": null
  }
}
```

### Agent Interpretation

Der Agent sollte:

1. **Daten interpretieren:** Temperaturen, Regen, Wind in natürlicher Sprache
2. **Kontext geben:** "Angenehme 15°C", "Frische 4°C nachts"
3. **Regen-Wahrscheinlichkeit:** Basierend auf `rain_mm` und `will_rain`
4. **Empfehlungen:** Regenschirm, Jacke, Sonnenschutz je nach Wetter

### Beispiel-Workflow

**User:** "Wie wird das Wetter morgen in Zürich?"

**Agent:**
```bash
${CLAUDE_SKILL_DIR}/weather-agent "Zürich"
```

**Interpretation:**
- JSON zeigt: `forecast[1]` (Morgen)
- Temperatur: 13.5°C max, 4.9°C min
- Regen: 0mm, `will_rain: false`
- **Antwort:** "Morgen in Zürich wird es kühl mit 13°C tagsüber und 5°C nachts. Kein Regen erwartet, es bleibt trocken."

### Nutzung

**Wetterabfrage:**
```bash
${CLAUDE_SKILL_DIR}/weather-agent "Zürich"
```

**Regen-Check:**
```bash
${CLAUDE_SKILL_DIR}/weather-agent "8001" | jq '.rain_analysis'
```

**Nur Temperatur:**
```bash
${CLAUDE_SKILL_DIR}/weather-agent "Bern" | jq '.current.temperature_c'
```

### Datenbank

Beim ersten Aufruf wird automatisch gebaut:
- `~/.cache/meteoswiss-ogd/plz-station-map.json` (~3200 PLZ → Stationen)
- `~/.cache/meteoswiss-ogd/city-plz-map.json` (~4000 Ortsnamen → PLZ)

Dauer: ~2 Minuten (einmalig), danach sofort verfügbar.

---

## Alternative Interfaces (für Debugging)

Falls nötig, gibt es auch:

- `./weather` — Menschenlesbare Ausgabe
- `./weather-json` — JSON-Wrapper für das Bash-Script
- `./rain-check` — Einfacher Ja/Nein Regen-Check

Diese sind für Endnutzer gedacht, nicht für Agent-Operationen.

---

## Technische Details

**Parameter-Codes (für Referenz):**
- `tre200s0` — Temperatur 2m (aktuell)
- `tre200dx` — Tagesmax Temperatur
- `tre200dn` — Tagesmin Temperatur
- `rka150d0` — Niederschlag (Tageswert)
- `ure200s0` — Luftfeuchte
- `fu3010z0` — Windgeschwindigkeit
- `fu3010z1` — Böen
- `dkl010z0` — Windrichtung

**CSV-URLs:**
- Aktuell: `https://data.geo.admin.ch/ch.meteoschweiz.messwerte-aktuell/VQHA80.csv`
- Prognose: `https://data.geo.admin.ch/ch.meteoschweiz.ogd-local-forecasting/{DATE}-ch/vnut12.lssw.{DATE}1100.{PARAM}.csv`
