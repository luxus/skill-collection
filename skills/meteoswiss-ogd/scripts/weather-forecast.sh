#!/bin/bash
set -euo pipefail

# Get weather forecast for a location (with caching)
# Usage: weather-forecast.sh <location> [days]
# Example: weather-forecast.sh "Eglisau" 3

LOCATION="${1:-}"
DAYS="${2:-3}"
SCRIPT_DIR="$(cd "$(dirname "${BASH_SOURCE[0]}")" && pwd)"
CACHE_FILE="${HOME}/.cache/meteoswiss-ogd/locations.json"

if [[ -z "$LOCATION" || "$1" == "--help" || "$1" == "-h" ]]; then
  cat << 'EOF'
Usage: weather-forecast.sh <location> [days]

Get weather forecast for a location. Shows daily forecast.
Uses cache for station/point lookup.

Arguments:
  location    City name (must be cached or searchable)
  days        Number of days to show (default: 3, max: 7)

Examples:
  weather-forecast.sh "Eglisau"
  weather-forecast.sh "Zürich" 5
  weather-forecast.sh "Bern" 7

Requires:
  - Location cached (use weather-cache.sh set)
  - Or location searchable (will prompt to cache)
EOF
  exit "${LOCATION:+1}"
fi

# Validate days
if ! [[ "$DAYS" =~ ^[0-9]+$ ]] || [[ "$DAYS" -lt 1 ]] || [[ "$DAYS" -gt 7 ]]; then
  echo "Error: days must be 1-7"
  exit 1
fi

# Check cache
POINT_ID=""
STATION_ABBR=""
if [[ -f "$CACHE_FILE" ]]; then
  CACHED=$(jq -r ".\"$LOCATION\" // empty" "$CACHE_FILE" 2>/dev/null || echo "")
  if [[ -n "$CACHED" ]]; then
    POINT_ID=$(echo "$CACHED" | jq -r '.point_id // empty')
    STATION_ABBR=$(echo "$CACHED" | jq -r '.station_abbr // empty')
    POSTAL_CODE=$(echo "$CACHED" | jq -r '.postal_code // empty')
    STATION_NAME=$(echo "$CACHED" | jq -r '.station_name // empty')
    echo "📍 $LOCATION (PLZ: ${POSTAL_CODE:-?}, cached)"
    echo "   Station: ${STATION_ABBR:-?} (${STATION_NAME:-?})"
    echo "   Point ID: ${POINT_ID:-?}"
  fi
fi

# If not cached, try to find
if [[ -z "$POINT_ID" && -z "$STATION_ABBR" ]]; then
  echo "🔍 Location not cached. Searching: $LOCATION"
  echo ""
  
  # Search forecast points
  RESULTS=$("$SCRIPT_DIR/search-forecast-points.sh" "$LOCATION" 2>/dev/null | head -5)
  if [[ -n "$RESULTS" ]]; then
    echo "Forecast points found:"
    echo "$RESULTS"
    echo ""
    echo "💡 Cache this location first:"
    FIRST=$(echo "$RESULTS" | head -1)
    PID=$(echo "$FIRST" | awk -F'|' '{print $1}' | xargs)
    echo "   weather-cache.sh set \"$LOCATION\" \"PLZ\" \"\" \"\" \"$PID\""
    echo "   Then run: weather-forecast.sh \"$LOCATION\""
    exit 1
  fi
  
  # Search stations
  RESULTS=$("$SCRIPT_DIR/search-stations.sh" "$LOCATION" 2>/dev/null | head -5)
  if [[ -n "$RESULTS" ]]; then
    echo "Stations found (need point_id for forecast):"
    echo "$RESULTS"
    echo ""
    echo "💡 Find point_id with:"
    FIRST=$(echo "$RESULTS" | head -1)
    ABBR=$(echo "$FIRST" | awk -F'|' '{print $1}' | xargs)
    echo "   search-forecast-points.sh \"$ABBR\""
    exit 1
  fi
  
  echo "❌ Location not found: $LOCATION"
  exit 1
fi

echo ""
echo "🔮 Forecast (next $DAYS days):"
echo ""

# Helper: convert parameter to readable
describe_param() {
  case "$1" in
    tre200dx) echo "🌡️  Max Temp" ;;
    tre200dn) echo "🌡️  Min Temp" ;;
    rka150d0) echo "🌧️  Rain" ;;
    jp2000d0) echo "☀️  Icon" ;;
    *) echo "$1" ;;
  esac
}

# Try to get forecast via forecast.sh (handles API quirks)
if [[ -n "$POINT_ID" ]]; then
  # Try to get max temp forecast
  TEMP_DATA=$("$SCRIPT_DIR/forecast.sh" "$POINT_ID" tre200dx 2>/dev/null | tail -n +2 | head -$DAYS || true)
  
  if [[ -n "$TEMP_DATA" ]]; then
    echo "Daily Forecast (Station):"
    echo "$TEMP_DATA" | while IFS=';' read -r pid d0 d1 d2 d3 d4 d5 d6 d7 rest; do
      [[ -z "$d0" ]] && continue
      echo "  Today:     ${d0}°C max"
      [[ -n "$d1" && "$DAYS" -ge 2 ]] && echo "  +1 day:    ${d1}°C max"
      [[ -n "$d2" && "$DAYS" -ge 3 ]] && echo "  +2 days:   ${d2}°C max"
      [[ -n "$d3" && "$DAYS" -ge 4 ]] && echo "  +3 days:   ${d3}°C max"
      [[ -n "$d4" && "$DAYS" -ge 5 ]] && echo "  +4 days:   ${d4}°C max"
      [[ -n "$d5" && "$DAYS" -ge 6 ]] && echo "  +5 days:   ${d5}°C max"
      [[ -n "$d6" && "$DAYS" -ge 7 ]] && echo "  +6 days:   ${d6}°C max"
      break
    done
  else
    echo "⚠️  Forecast API not available (STAC limitation)"
    echo ""
    echo "Try manual forecast from SKILL.md:"
    echo "  1. Get ITEM: curl -s '.../items?limit=10' | jq -r '.features | map(.id) | sort | reverse | first'"
    echo "  2. Get ASSET_URL for parameter (tre200dx for daily max temp)"
    echo "  3. Download CSV and filter for point_id=$POINT_ID"
    echo ""
    if [[ -n "$STATION_ABBR" ]]; then
      echo "📊 Current weather as fallback:"
      "$SCRIPT_DIR/current-weather.sh" "$STATION_ABBR" 2>/dev/null | grep -E "(tre200s0|ure200s0|fu3010z0)" | while IFS='=' read -r key value; do
        case "$key" in
          tre200s0) echo "   Current temp: ${value}°C" ;;
          ure200s0) echo "   Humidity: ${value}%" ;;
          fu3010z0) echo "   Wind: ${value}km/h" ;;
        esac
      done
    fi
  fi
else
  echo "⚠️  No point_id cached for $LOCATION"
  echo "   Forecast requires point_id (postal code location)"
  echo "   Current weather only available via station:"
  if [[ -n "$STATION_ABBR" ]]; then
    "$SCRIPT_DIR/current-weather.sh" "$STATION_ABBR" 2>/dev/null | head -5
  fi
fi

echo ""
echo "💡 Tip: For full forecast data, use manual STAC queries from SKILL.md"
