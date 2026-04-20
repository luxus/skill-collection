#!/bin/bash
set -euo pipefail

# Get current weather for a Swiss weather station
# Usage: current-weather.sh <station_abbr>
# Requires: curl, awk
# Example: current-weather.sh SMA

STATION="${1:-}"

if [[ -z "$STATION" || "$1" == "--help" || "$1" == "-h" ]]; then
  cat << 'EOF'
Usage: current-weather.sh <station_abbr>

Get current weather measurements for a Swiss weather station.
Data source: MeteoSwiss Open Data (VQHA80.csv, updated every 10 min)

Arguments:
  station_abbr  Station abbreviation (e.g., SMA, BER, GVE, LUG, BAS)

Output: key=value pairs for temperature, humidity, wind, pressure, etc.

Examples:
  current-weather.sh SMA    # Zürich
  current-weather.sh BER    # Bern
  current-weather.sh GVE    # Genève
EOF
  exit "${STATION:+1}"
fi

STATION=$(echo "$STATION" | tr '[:lower:]' '[:upper:]')
URL="https://data.geo.admin.ch/ch.meteoschweiz.messwerte-aktuell/VQHA80.csv"

DATA=$(curl -sf "$URL") || { echo "Error: failed to fetch weather data" >&2; exit 1; }

# Extract header and matching row
HEADER=$(echo "$DATA" | head -1)
ROW=$(echo "$DATA" | awk -F';' -v s="$STATION" '$1==s')

if [[ -z "$ROW" ]]; then
  echo "Error: station '$STATION' not found" >&2
  echo "Hint: use search-stations.sh to find valid abbreviations" >&2
  exit 1
fi

# Parse and output key=value pairs
echo "$HEADER" | awk -F';' -v row="$ROW" '
BEGIN { split(row, vals, ";") }
{
  for (i = 1; i <= NF; i++) {
    if (vals[i] != "" && vals[i] != "-") {
      gsub(/^[ \t]+|[ \t]+$/, "", $i)
      gsub(/^[ \t]+|[ \t]+$/, "", vals[i])
      print $i "=" vals[i]
    }
  }
}'
