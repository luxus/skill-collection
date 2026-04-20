#!/bin/bash
set -euo pipefail

# Quick weather forecast for Swiss locations
# Usage: weather-forecast.sh <location> [days]
# Example: weather-forecast.sh "Bern" 3

LOCATION="${1:-}"
DAYS="${2:-3}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_FILE="${HOME}/.cache/meteoswiss-ogd/locations.json"

if [[ -z "$LOCATION" || "$1" == "--help" || "$1" == "-h" ]]; then
  cat << 'EOF'
Usage: weather-forecast.sh <location> [days]

Get weather forecast for a Swiss location.

Arguments:
  location    City name (must be cached first)
  days        Number of days (default: 3, max: 7)

Examples:
  weather-forecast.sh "Bern"
  weather-forecast.sh "Zürich" 5

First cache your location:
  weather-cache.sh set "Bern" "3000" "BER" "Bern/Zollikofen" "29"
EOF
  exit "${LOCATION:+1}"
fi

# Get point_id from cache
POINT_ID=""
STATION_ABBR=""
if [[ -f "$CACHE_FILE" ]]; then
  CACHED=$(jq -r ".\"$LOCATION\" // empty" "$CACHE_FILE" 2>/dev/null || echo "")
  if [[ -n "$CACHED" ]]; then
    POINT_ID=$(echo "$CACHED" | jq -r '.point_id // empty')
    STATION_ABBR=$(echo "$CACHED" | jq -r '.station_abbr // empty')
    POSTAL_CODE=$(echo "$CACHED" | jq -r '.postal_code // empty')
  fi
fi

if [[ -z "$POINT_ID" ]]; then
  echo "❌ $LOCATION nicht im Cache"
  echo ""
  echo "Cache zuerst:"
  echo "  weather-cache.sh set \"$LOCATION\" \"PLZ\" \"STATION\" \"NAME\" \"POINTID\""
  echo ""
  echo "Beispiel für Bern:"
  echo "  weather-cache.sh set \"Bern\" \"3000\" \"BER\" \"Bern/Zollikofen\" \"29\""
  exit 1
fi

# Get forecast data
TODAY=$(date +%Y%m%d)
ITEM_ID="${TODAY}-ch"
RUN_TIME="1100"  # 11:00 UTC run

echo "🔮 Prognose $LOCATION (Point ID: $POINT_ID)"
echo ""

# Fetch max temp
TEMP_URL="https://data.geo.admin.ch/ch.meteoschweiz.ogd-local-forecasting/${ITEM_ID}/vnut12.lssw.${TODAY}${RUN_TIME}.tre200dx.csv"
TEMP_DATA=$(curl -sf "$TEMP_URL" 2>/dev/null | awk -F';' -v pid="$POINT_ID" '$1==pid' | head -$DAYS || true)

# Fetch min temp
MIN_URL="https://data.geo.admin.ch/ch.meteoschweiz.ogd-local-forecasting/${ITEM_ID}/vnut12.lssw.${TODAY}${RUN_TIME}.tre200dn.csv"
MIN_DATA=$(curl -sf "$MIN_URL" 2>/dev/null | awk -F';' -v pid="$POINT_ID" '$1==pid' | head -$DAYS || true)

# Fetch rain
RAIN_URL="https://data.geo.admin.ch/ch.meteoschweiz.ogd-local-forecasting/${ITEM_ID}/vnut12.lssw.${TODAY}${RUN_TIME}.rka150d0.csv"
RAIN_DATA=$(curl -sf "$RAIN_URL" 2>/dev/null | awk -F';' -v pid="$POINT_ID" '$1==pid' | head -$DAYS || true)

if [[ -z "$TEMP_DATA" ]]; then
  echo "⚠️  Keine Prognose-Daten verfügbar"
  exit 1
fi

# Output header
printf "%-12s %8s %8s %8s\n" "Datum" "Max°C" "Min°C" "Regen"
echo "───────────────────────────────────────"

# Process and display
echo "$TEMP_DATA" | while IFS=';' read -r pid ptype date temp_max rest; do
  [[ -z "$pid" ]] && continue
  
  # Format date
  day=$(echo "$date" | cut -c7-8)
  month=$(echo "$date" | cut -c5-6)
  
  # Get min temp for this date
  temp_min=$(echo "$MIN_DATA" | awk -F';' -v d="$date" '$3==d {print $4}')
  
  # Get rain for this date
  rain=$(echo "$RAIN_DATA" | awk -F';' -v d="$date" '$3==d {print $4}')
  [[ -z "$rain" || "$rain" == "0" || "$rain" == "0.0" ]] && rain="-"
  
  # Determine day label
  if [[ "$date" == "${TODAY}0000" ]]; then
    label="Heute"
  elif [[ "$date" == "$(date -v+1d +%Y%m%d 2>/dev/null || date -d '+1 day' +%Y%m%d 2>/dev/null || echo '')0000" ]]; then
    label="Morgen"
  else
    label="${day}.${month}."
  fi
  
  printf "%-12s %8s %8s %8s\n" "$label" "$temp_max" "${temp_min:--}" "$rain"
done

echo ""

# Current weather as bonus
if [[ -n "$STATION_ABBR" ]]; then
  CURRENT=$("$SCRIPT_DIR/current-weather.sh" "$STATION_ABBR" 2>/dev/null | grep "tre200s0=" | cut -d'=' -f2 || echo "")
  if [[ -n "$CURRENT" ]]; then
    echo "🌡️  Aktuell: ${CURRENT}°C (Station: $STATION_ABBR)"
  fi
fi
