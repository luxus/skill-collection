---
name: meteoswiss-ogd
description: >-
  Access Swiss weather data from MeteoSwiss Open Government Data.
  Current conditions, forecasts, and pollen data via direct HTTP.
  No API key required. Free public data from data.geo.admin.ch.
globs: []
---

# MeteoSwiss Open Government Data

Access Swiss weather data directly from MeteoSwiss OGD. All data is free, no API key required.

**Data source:** `data.geo.admin.ch`  
**Format:** CSV with semicolon (`;`) delimiters  
**Encoding:** Metadata CSVs are Latin1 — pipe through `iconv -f latin1 -t utf-8`

## Quick Reference

| Data | URL / Method | Updates |
|------|-------------|---------|
| Current weather | `VQHA80.csv` | 10 min |
| Station metadata | STAC `ogd-smn` → `meta_stations.csv` | Daily |
| Forecast metadata | STAC `ogd-local-forecasting` → `meta_point.csv` | Daily |
| Forecast data | STAC items → parameter CSVs | Hourly |
| Pollen data | `ogd-pollen/{abbr}/ogd-pollen_{abbr}_d_recent.csv` | Daily |

STAC API: `https://data.geo.admin.ch/api/stac/v1`

---

## 1. Current Weather

Get real-time measurements for any Swiss weather station:

```bash
curl -s 'https://data.geo.admin.ch/ch.meteoschweiz.messwerte-aktuell/VQHA80.csv' \
  | awk -F';' 'NR==1 || $1=="SMA"'
```

**Key parameters:**
- `tre200s0` — Temperature (°C)
- `ure200s0` — Humidity (%)
- `rre150z0` — Precipitation (mm)
- `fu3010z0` — Wind speed (km/h)
- `fu3010z1` — Wind gusts (km/h)
- `dkl010z0` — Wind direction (°)

**Common station codes:**
- `SMA` — Zürich / Kloten
- `BER` — Bern / Zollikofen
- `GVE` — Genève / Cointrin
- `LUG` — Lugano
- `BAS` — Basel / Binningen

---

## 2. Find Stations

Search weather stations by name, canton, or abbreviation:

```bash
curl -s 'https://data.geo.admin.ch/ch.meteoschweiz.ogd-smn/ogd-smn_meta_stations.csv' \
  | iconv -f latin1 -t utf-8 \
  | awk -F';' 'NR==1 || tolower($0) ~ /zurich/'
```

Search forecast locations (~6000 points: stations, postal codes, mountains):

```bash
# Get metadata URL from STAC
META_URL=$(curl -s 'https://data.geo.admin.ch/api/stac/v1/collections/ch.meteoschweiz.ogd-local-forecasting' \
  | jq -r '.assets | to_entries | map(select(.key | contains("meta_point"))) | first | .value.href')

# Search by postal code
curl -s "$META_URL" | iconv -f latin1 -t utf-8 \
  | awk -F';' 'NR==1 || $3 ~ /8001/'
```

**Point types:** 1=station, 2=postal_code, 3=mountain

---

## 3. Forecasts

Two-step process: get latest STAC item, then download parameter CSVs.

**Note:** The STAC API sometimes returns documentation format instead of JSON. If you encounter parse errors, use the manual curl commands shown below.

```bash
# Step 1: Get latest forecast item
ITEM=$(curl -s 'https://data.geo.admin.ch/api/stac/v1/collections/ch.meteoschweiz.ogd-local-forecasting/items?limit=10' \
  | jq -r '.features | map(.id) | sort | reverse | first')

# Step 2: Get daily max temperature for point_id=48 (Zurich)
ASSET_URL=$(curl -s "https://data.geo.admin.ch/api/stac/v1/collections/ch.meteoschweiz.ogd-local-forecasting/items/$ITEM" \
  | jq -r '.assets | to_entries | map(select(.key | contains("tre200dx"))) | sort_by(.key) | last | .value.href')

curl -s "$ASSET_URL" | awk -F';' 'NR==1 || $1=="48"'
```

**Daily parameters (stations):**
- `tre200dx` — Max temperature
- `tre200dn` — Min temperature
- `rka150d0` — Precipitation total
- `jp2000d0` — Weather icon code

**Hourly parameters (all locations):**
- `tre200h0` — Temperature
- `rre150h0` — Precipitation
- `jww003i0` — 3-hourly weather icon

**Weather icons:** `https://www.meteoschweiz.admin.ch/static/resources/weather-symbols/{CODE}.svg`

---

## 4. Pollen Data

Pollen measurements from 16 stations across Switzerland:

```bash
# Zurich station (PZH)
curl -s 'https://data.geo.admin.ch/ch.meteoschweiz.ogd-pollen/pzh/ogd-pollen_pzh_d_recent.csv' \
  | iconv -f latin1 -t utf-8 \
  | awk -F';' 'NR==1{print} {last=$0} END{print last}'
```

**Common pollen stations:**
- `PZH` — Zürich
- `PBE` — Bern
- `PGE` — Genève
- `PLO` — Locarno
- `PLU` — Lugano

**Pollen types:**
- `kabetud1` — Birch (Betula)
- `khpoacd1` — Grasses (Poaceae)
- `kaalnud1` — Alder (Alnus)
- `kacoryd1` — Hazel (Corylus)

Resolution `d1` = calendar day (0-0 UTC). Values in particles/m³.

---

## Helper Scripts

Use the bundled scripts for easier access (handle encoding, error checking):

```bash
# Current weather
${CLAUDE_SKILL_DIR}/scripts/current-weather.sh SMA

# Search stations
${CLAUDE_SKILL_DIR}/scripts/search-stations.sh zurich

# Search forecast points
${CLAUDE_SKILL_DIR}/scripts/search-forecast-points.sh 8001

# Get forecast
${CLAUDE_SKILL_DIR}/scripts/forecast.sh 48

# Pollen data
${CLAUDE_SKILL_DIR}/scripts/pollen.sh ZUE

# Quick weather with caching (recommended)
${CLAUDE_SKILL_DIR}/scripts/weather-for.sh "Eglisau"
```

All scripts support `--help` for detailed usage.

---

## Location Caching

Save frequently used locations to avoid repeated searches:

```bash
# Save a location
${CLAUDE_SKILL_DIR}/scripts/weather-cache.sh set "Eglisau" "8193" "LAE" "Lägern" "819300"

# Quick weather lookup (uses cache)
${CLAUDE_SKILL_DIR}/scripts/weather-for.sh "Eglisau"

# List all cached locations
${CLAUDE_SKILL_DIR}/scripts/weather-cache.sh list

# Get cached data
${CLAUDE_SKILL_DIR}/scripts/weather-cache.sh get "Eglisau"

# Delete from cache
${CLAUDE_SKILL_DIR}/scripts/weather-cache.sh delete "Eglisau"
```

Cache stored in: `~/.cache/meteoswiss-ogd/locations.json`

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| Station not found | Check metadata CSV for valid abbreviations |
| Empty data | Station may be offline — try nearby station |
| Garbled text | Add `iconv -f latin1 -t utf-8` to pipeline |
| 403/404 on pollen | Use lowercase abbreviation, check it's a pollen station |
| Missing values | Shown as `-` or empty fields in CSV |

---

## Full Reference

See `${CLAUDE_SKILL_DIR}/REFERENCE.md` for complete parameter tables, weather icon codes, and STAC collection details.
