#!/bin/bash
set -euo pipefail

# Get weather for a location (with caching)
# Usage: weather-for.sh <location>
# Example: weather-for.sh "Eglisau"

LOCATION="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_FILE="${HOME}/.cache/meteoswiss-ogd/locations.json"

# Format current time
CURRENT_TIME=$(date '+%H:%M')
CURRENT_DATE=$(date '+%d.%m.%Y')
CURRENT_WEEKDAY=$(date '+%A')

if [[ -z "$LOCATION" || "$1" == "--help" || "$1" == "-h" ]]; then
  cat << 'EOF'
Usage: weather-for.sh <location>

Get current weather for a location. Uses cache if available,
otherwise searches for nearest station.

Examples:
  weather-for.sh "Eglisau"
  weather-for.sh "Zürich"
  weather-for.sh "Bern"

First time: caches the location
Subsequent calls: uses cached station/point_id

Cache management:
  weather-cache.sh list      # show cached locations
  weather-cache.sh set "Name" "PLZ" "Station" "StationName" "PointID"
EOF
  exit "${LOCATION:+1}"
fi

# Try cache first
if [[ -f "$CACHE_FILE" ]]; then
  CACHED=$(jq -r ".\"$LOCATION\" // empty" "$CACHE_FILE" 2>/dev/null || echo "")
  if [[ -n "$CACHED" ]]; then
    STATION_ABBR=$(echo "$CACHED" | jq -r '.station_abbr // empty')
    POINT_ID=$(echo "$CACHED" | jq -r '.point_id // empty')
    POSTAL_CODE=$(echo "$CACHED" | jq -r '.postal_code // empty')
    
    if [[ -n "$STATION_ABBR" ]]; then
      # Show time and date
      echo "🕐 ${CURRENT_WEEKDAY}, ${CURRENT_DATE} ${CURRENT_TIME}"
      echo "📍 $LOCATION (cached: $(echo "$CACHED" | jq -r '.updated // "unknown"' | cut -dT -f1))"
      echo "   Station: $STATION_ABBR ($(echo "$CACHED" | jq -r '.station_name // ""'))"
      [[ -n "$POSTAL_CODE" ]] && echo "   PLZ: $POSTAL_CODE"
      echo ""
      
      # Get weather data with timestamp
      WEATHER_DATA=$("$SCRIPT_DIR/current-weather.sh" "$STATION_ABBR" 2>/dev/null)
      
      # Extract timestamp if present (format: reference_timestamp=YYYYMMDDHHmm)
      TIMESTAMP=$(echo "$WEATHER_DATA" | grep "^reference_timestamp=" | cut -d'=' -f2 || echo "")
      if [[ -n "$TIMESTAMP" && ${#TIMESTAMP} -eq 12 ]]; then
        # Parse YYYYMMDDHHmm
        YEAR=${TIMESTAMP:0:4}
        MONTH=${TIMESTAMP:4:2}
        DAY=${TIMESTAMP:6:2}
        HOUR=${TIMESTAMP:8:2}
        MIN=${TIMESTAMP:10:2}
        echo "🌡️  Current weather (updated: ${DAY}.${MONTH}. ${HOUR}:${MIN} UTC):"
      else
        echo "🌡️  Current weather:"
      fi
      
      echo "$WEATHER_DATA" | while IFS='=' read -r key value; do
        case "$key" in
          tre200s0) echo "   Temperature: ${value}°C" ;;
          ure200s0) echo "   Humidity: ${value}%" ;;
          rre150z0) echo "   Precipitation: ${value}mm" ;;
          fu3010z0) echo "   Wind: ${value}km/h" ;;
          fu3010z1) echo "   Gusts: ${value}km/h" ;;
          dkl010z0) echo "   Wind direction: ${value}°" ;;
        esac
      done
      exit 0
    fi
  fi
fi

# Not cached - search for stations
echo "🕐 ${CURRENT_WEEKDAY}, ${CURRENT_DATE} ${CURRENT_TIME}"
echo "🔍 Location not cached. Searching for: $LOCATION"
echo ""

# Try direct station search first
RESULTS=$("$SCRIPT_DIR/search-stations.sh" "$LOCATION" 2>/dev/null | head -5)
if [[ -n "$RESULTS" ]]; then
  echo "Stations found:"
  echo "$RESULTS" | nl
  echo ""
  echo "💡 Tip: Cache a location with:"
  echo "   weather-cache.sh set \"$LOCATION\" \"PLZ\" \"STATION\" \"NAME\" \"POINTID\""
  echo ""
  echo "Example for first result:"
  FIRST_LINE=$(echo "$RESULTS" | head -1)
  STATION=$(echo "$FIRST_LINE" | awk -F'|' '{print $1}' | xargs)
  NAME=$(echo "$FIRST_LINE" | awk -F'|' '{print $2}' | xargs)
  echo "   weather-cache.sh set \"$LOCATION\" \"\" \"$STATION\" \"$NAME\" \"\""
  exit 0
fi

# Try postal code search
RESULTS=$("$SCRIPT_DIR/search-forecast-points.sh" "$LOCATION" 2>/dev/null | head -5)
if [[ -n "$RESULTS" ]]; then
  echo "Forecast points found:"
  echo "$RESULTS" | nl
  exit 0
fi

echo "❌ No results found for: $LOCATION"
echo "Try a nearby city or postal code."
exit 1
