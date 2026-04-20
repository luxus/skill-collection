#!/bin/bash
set -euo pipefail

# Simple rain check: Will it rain today/tomorrow?
# Usage: will-it-rain.sh <location> [days]
# Example: will-it-rain.sh "Zürich" 2

LOCATION="${1:-}"
DAYS="${2:-2}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_FILE="${HOME}/.cache/meteoswiss-ogd/locations.json"

if [[ -z "$LOCATION" || "$1" == "--help" || "$1" == "-h" ]]; then
  cat << 'EOF'
Usage: will-it-rain.sh <location> [days]

Quick rain check for Swiss locations. Shows simple yes/no with amounts.

Arguments:
  location    City name (must be cached)
  days        Check next N days (default: 2, max: 5)

Examples:
  will-it-rain.sh "Zürich"
  will-it-rain.sh "Bern" 3
  will-it-rain.sh "Genf" 1

Output:
  🌧️  YES - 4.5mm rain expected tomorrow
  ☀️  NO - No rain expected today
EOF
  exit "${LOCATION:+1}"
fi

if ! [[ "$DAYS" =~ ^[0-9]+$ ]] || [[ "$DAYS" -lt 1 ]] || [[ "$DAYS" -gt 5 ]]; then
  echo "Error: days must be 1-5"
  exit 1
fi

# Check cache
POINT_ID=""
if [[ -f "$CACHE_FILE" ]]; then
  CACHED=$(jq -r ".\"$LOCATION\" // empty" "$CACHE_FILE" 2>/dev/null || echo "")
  if [[ -n "$CACHED" ]]; then
    POINT_ID=$(echo "$CACHED" | jq -r '.point_id // empty')
    POSTAL_CODE=$(echo "$CACHED" | jq -r '.postal_code // empty')
  fi
fi

if [[ -z "$POINT_ID" ]]; then
  echo "❌ Location not cached: $LOCATION"
  echo ""
  echo "Cache it first:"
  echo "  weather-cache.sh set \"$LOCATION\" \"PLZ\" \"STATION\" \"NAME\" \"POINTID\""
  echo ""
  echo "Or search:"
  echo "  search-forecast-points.sh \"$LOCATION\""
  exit 1
fi

# Fetch rain forecast
get_rain_data() {
  local point_id="$1"
  
  for offset in 0 1 2; do
    local date_str=$(date -v-${offset}d +%Y%m%d 2>/dev/null || date -d "${offset} days ago" +%Y%m%d 2>/dev/null || echo "")
    [[ -z "$date_str" ]] && continue
    
    local item_id="${date_str}-ch"
    local url="https://data.geo.admin.ch/ch.meteoschweiz.ogd-local-forecasting/${item_id}/rka150d0_ch.${item_id}.csv"
    
    local data=$(curl -sf "$url" 2>/dev/null | awk -F';' -v pid="$point_id" 'NR==1 || $1==pid' || true)
    if [[ -n "$data" ]]; then
      echo "$data"
      return 0
    fi
  done
  
  return 1
}

RAIN_DATA=$(get_rain_data "$POINT_ID" || true)

if [[ -z "$RAIN_DATA" ]]; then
  echo "⚠️  Cannot fetch rain forecast for $LOCATION"
  exit 1
fi

echo "🌦️  Rain check: $LOCATION"
echo ""

# Parse rain data
echo "$RAIN_DATA" | awk -F';' -v days="$DAYS" '
NR==1 { 
  for (i=2; i<=NF && i-2<days; i++) {
    day_num = i-2
    if (day_num == 0) day_label = "Today"
    else if (day_num == 1) day_label = "Tomorrow"
    else day_label = "+" day_num " days"
    headers[i] = day_label
  }
}
NR==2 {
  for (i=2; i<=NF && i-2<days; i++) {
    rain = $i + 0  # convert to number
    if (rain > 0) {
      printf "  🌧️  YES - %.1fmm expected %s\n", rain, headers[i]
    } else {
      printf "  ☀️  NO   - No rain expected %s\n", headers[i]
    }
  }
}'

echo ""

# Current rain check (from current weather if station available)
STATION_ABBR=$(jq -r ".\"$LOCATION\".station_abbr // empty" "$CACHE_FILE" 2>/dev/null || echo "")
if [[ -n "$STATION_ABBR" ]]; then
  CURRENT=$("$SCRIPT_DIR/current-weather.sh" "$STATION_ABBR" 2>/dev/null | grep "rre150z0=" | cut -d'=' -f2 || echo "")
  if [[ -n "$CURRENT" && $(echo "$CURRENT > 0" | bc 2>/dev/null || echo "0") == "1" ]]; then
    echo "🌧️  Currently raining: ${CURRENT}mm in last 10min"
  elif [[ -n "$CURRENT" ]]; then
    echo "☀️  Not raining currently"
  fi
fi
