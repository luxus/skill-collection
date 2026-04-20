#!/bin/bash
set -euo pipefail

# Get pollen data for a Swiss station
# Usage: pollen.sh <station_abbr>
# Requires: curl, iconv, awk
# Example: pollen.sh ZUE

STATION="${1:-}"

if [[ -z "$STATION" || "$1" == "--help" || "$1" == "-h" ]]; then
  cat << 'EOF'
Usage: pollen.sh <station_abbr>

Get pollen concentration data for a Swiss station.
Data source: MeteoSwiss Open Data (ogd-pollen)

Arguments:
  station_abbr  Station abbreviation (e.g., PZH, PBE, PGE, PLO, PLU)

Output: key=value pairs for pollen types (particles/m³)

Common stations:
  PZH = Zürich
  PBE = Bern
  PGE = Genève
  PLO = Locarno
  PLU = Lugano

Pollen types:
  kabetud1 = Birch (Birke)
  khpoacd1 = Grasses (Gräser)
  kaalnud1 = Alder (Erle)
  kacoryd1 = Hazel (Hasel)

Examples:
  pollen.sh ZUE    # Zürich
  pollen.sh BE     # Bern
EOF
  exit "${STATION:+1}"
fi

STATION=$(echo "$STATION" | tr '[:upper:]' '[:lower:]')
URL="https://data.geo.admin.ch/ch.meteoschweiz.ogd-pollen/${STATION}/ogd-pollen_${STATION}_d_recent.csv"

DATA=$(curl -sf "$URL") || { echo "Error: failed to fetch pollen data (check station abbreviation)" >&2; exit 1; }

echo "$DATA" \
  | iconv -f latin1 -t utf-8 \
  | awk -F';' '
    NR == 1 {
      for (i = 1; i <= NF; i++) header[i] = $i
      next
    }
    { last = $0 }
    END {
      split(last, vals, ";")
      for (i = 1; i <= NF; i++) {
        if (vals[i] != "" && vals[i] != "-" && header[i] != "station_abbr" && header[i] != "reference_timestamp") {
          print header[i] "=" vals[i]
        }
      }
    }'
