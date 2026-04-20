#!/bin/bash
set -euo pipefail

# Get weather for a location (with caching and auto-cache)
# Usage: weather-for.sh <location>
# Example: weather-for.sh "Eglisau"

LOCATION="${1:-}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_FILE="${HOME}/.cache/meteoswiss-ogd/locations.json"

# Format current time (when we query)
QUERY_TIME=$(date '+%H:%M')
QUERY_DATE=$(date '+%d.%m.%Y')
QUERY_WEEKDAY=$(date '+%A')

if [[ -z "$LOCATION" || "$1" == "--help" || "$1" == "-h" ]]; then
  cat << 'EOF'
Usage: weather-for.sh <location>

Get current weather for a location. Uses cache if available,
otherwise searches and auto-caches the best match.

Examples:
  weather-for.sh "Eglisau"
  weather-for.sh "Zürich"
  weather-for.sh "Bern"
EOF
  exit "${LOCATION:+1}"
fi

mkdir -p "$(dirname "$CACHE_FILE")"
[[ -f "$CACHE_FILE" ]] || echo '{}' > "$CACHE_FILE"

# Try cache first
if [[ -f "$CACHE_FILE" ]]; then
  CACHED=$(jq -r ".\"$LOCATION\" // empty" "$CACHE_FILE" 2>/dev/null || echo "")
  if [[ -n "$CACHED" ]]; then
    STATION_ABBR=$(echo "$CACHED" | jq -r '.station_abbr // empty')
    POINT_ID=$(echo "$CACHED" | jq -r '.point_id // empty')
    POSTAL_CODE=$(echo "$CACHED" | jq -r '.postal_code // empty')
    STATION_NAME=$(echo "$CACHED" | jq -r '.station_name // empty')
    
    if [[ -n "$STATION_ABBR" ]]; then
      # Show query time and location info
      echo "🕐 Abfrage: ${QUERY_WEEKDAY}, ${QUERY_DATE} ${QUERY_TIME}"
      echo "📍 $LOCATION (gespeichert: $(echo "$CACHED" | jq -r '.updated // "unknown"' | cut -dT -f1))"
      echo "   Station: $STATION_ABBR (${STATION_NAME:-?})"
      [[ -n "$POSTAL_CODE" ]] && echo "   PLZ: $POSTAL_CODE"
      echo ""
      
      # Get weather data
      WEATHER_DATA=$("$SCRIPT_DIR/current-weather.sh" "$STATION_ABBR" 2>/dev/null) || {
        echo "❌ Fehler beim Laden der Wetterdaten"
        exit 1
      }
      
      # Extract timestamp and format it (Date field = YYYYMMDDHHmm)
      TIMESTAMP=$(echo "$WEATHER_DATA" | grep "^Date=" | cut -d'=' -f2 || echo "")
      if [[ -n "$TIMESTAMP" && ${#TIMESTAMP} -eq 12 ]]; then
        # Parse YYYYMMDDHHmm (UTC)
        YEAR=${TIMESTAMP:0:4}
        MONTH=${TIMESTAMP:4:2}
        DAY=${TIMESTAMP:6:2}
        HOUR=${TIMESTAMP:8:2}
        MIN=${TIMESTAMP:10:2}
        echo "🌡️  Aktuelles Wetter (MeteoSwiss-Daten vom ${DAY}.${MONTH}. ${HOUR}:${MIN} UTC):"
      else
        echo "🌡️  Aktuelles Wetter:"
      fi
      
      echo "$WEATHER_DATA" | while IFS='=' read -r key value; do
        case "$key" in
          tre200s0) echo "   Temperatur: ${value}°C" ;;
          ure200s0) echo "   Luftfeuchtigkeit: ${value}%" ;;
          rre150z0) echo "   Niederschlag: ${value}mm" ;;
          fu3010z0) echo "   Wind: ${value}km/h" ;;
          fu3010z1) echo "   Böen: ${value}km/h" ;;
          dkl010z0) echo "   Windrichtung: ${value}°" ;;
          prestas0) echo "   Luftdruck: ${value}hPa" ;;
        esac
      done
      exit 0
    fi
  fi
fi

# Not cached - search and auto-cache
echo "🕐 ${QUERY_WEEKDAY}, ${QUERY_DATE} ${QUERY_TIME}"
echo "🔍 Suche: $LOCATION"
echo ""

# Try direct station search first
RESULTS=$("$SCRIPT_DIR/search-stations.sh" "$LOCATION" 2>/dev/null | head -5)
if [[ -n "$RESULTS" ]]; then
  # Take first result and auto-cache
  FIRST_LINE=$(echo "$RESULTS" | head -1)
  STATION=$(echo "$FIRST_LINE" | awk -F'|' '{print $1}' | xargs)
  NAME=$(echo "$FIRST_LINE" | awk -F'|' '{print $2}' | xargs)
  CANTON=$(echo "$FIRST_LINE" | awk -F'|' '{print $3}' | xargs)
  
  echo "✓ Gefunden: $NAME ($CANTON)"
  echo "  Station: $STATION"
  echo "  → Wird automatisch gespeichert..."
  echo ""
  
  # Auto-cache (without point_id, will be added later if needed)
  jq --arg loc "$LOCATION" \
     --arg sa "$STATION" \
     --arg sn "$NAME" \
     '.[$loc] = {
       station_abbr: $sa,
       station_name: $sn,
       postal_code: "",
       point_id: "",
       updated: now | todate
     }' "$CACHE_FILE" > "${CACHE_FILE}.tmp" && mv "${CACHE_FILE}.tmp" "$CACHE_FILE"
  
  # Now show weather for this station
  echo "📍 $LOCATION (gespeichert: heute)"
  echo "   Station: $STATION ($NAME)"
  echo ""
  
  WEATHER_DATA=$("$SCRIPT_DIR/current-weather.sh" "$STATION" 2>/dev/null) || {
    echo "❌ Fehler beim Laden der Wetterdaten"
    exit 1
  }
  
  TIMESTAMP=$(echo "$WEATHER_DATA" | grep "^Date=" | cut -d'=' -f2 || echo "")
  if [[ -n "$TIMESTAMP" && ${#TIMESTAMP} -eq 12 ]]; then
    YEAR=${TIMESTAMP:0:4}
    MONTH=${TIMESTAMP:4:2}
    DAY=${TIMESTAMP:6:2}
    HOUR=${TIMESTAMP:8:2}
    MIN=${TIMESTAMP:10:2}
    echo "🌡️  Aktuelles Wetter (MeteoSwiss-Daten vom ${DAY}.${MONTH}. ${HOUR}:${MIN} UTC):"
  else
    echo "🌡️  Aktuelles Wetter:"
  fi
  
  echo "$WEATHER_DATA" | while IFS='=' read -r key value; do
    case "$key" in
      tre200s0) echo "   Temperatur: ${value}°C" ;;
      ure200s0) echo "   Luftfeuchtigkeit: ${value}%" ;;
      rre150z0) echo "   Niederschlag: ${value}mm" ;;
      fu3010z0) echo "   Wind: ${value}km/h" ;;
      fu3010z1) echo "   Böen: ${value}km/h" ;;
      dkl010z0) echo "   Windrichtung: ${value}°" ;;
      prestas0) echo "   Luftdruck: ${value}hPa" ;;
    esac
  done
  
  echo ""
  echo "💡 Für Prognose den Ort mit PLZ ergänzen:"
  echo "   weather-cache.sh set \"$LOCATION\" \"PLZ\" \"$STATION\" \"$NAME\" \"POINTID\""
  exit 0
fi

# Try forecast points for better location matching
RESULTS=$("$SCRIPT_DIR/search-forecast-points.sh" "$LOCATION" 2>/dev/null | head -5)
if [[ -n "$RESULTS" ]]; then
  echo "Orte für Prognose gefunden:"
  echo "$RESULTS" | nl
  echo ""
  echo "💡 Speichere einen Ort:"
  FIRST=$(echo "$RESULTS" | head -1)
  PID=$(echo "$FIRST" | awk -F'|' '{print $1}' | xargs)
  TYPE=$(echo "$FIRST" | awk -F'|' '{print $2}' | xargs)
  echo "   weather-cache.sh set \"$LOCATION\" \"PLZ\" \"\" \"\" \"$PID\""
  exit 0
fi

echo "❌ Kein Ergebnis für: $LOCATION"
echo "Versuche eine nahegelegene Stadt oder Postleitzahl."
exit 1
