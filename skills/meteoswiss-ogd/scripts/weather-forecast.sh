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
  weather-forecast.sh "Zürich"
  weather-forecast.sh "Bern" 5
  weather-forecast.sh "Genf" 3

Requires:
  - Location cached with point_id (use weather-cache.sh set)
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
    exit 1
  fi
  
  echo "❌ No forecast point found for: $LOCATION"
  exit 1
fi

echo "📍 $LOCATION (PLZ: ${POSTAL_CODE:-?})"
echo "   Station: ${STATION_ABBR:-?} (${STATION_NAME:-?})"
echo "   Point ID: ${POINT_ID:-?}"
echo ""

# Try to get forecast data
# Strategy: Try direct CSV URL patterns for recent forecast items

get_forecast_direct() {
  local point_id="$1"
  local param="$2"
  local days="$3"
  
  # Generate recent item IDs (format: YYYYMMDD-ch)
  # Try last 3 days
  for offset in 0 1 2; do
    local date_str=$(date -v-${offset}d +%Y%m%d 2>/dev/null || date -d "${offset} days ago" +%Y%m%d 2>/dev/null || echo "")
    [[ -z "$date_str" ]] && continue
    
    local item_id="${date_str}-ch"
    local url="https://data.geo.admin.ch/ch.meteoschweiz.ogd-local-forecasting/${item_id}/${param}_ch.${item_id}.csv"
    
    # Try to fetch
    local data=$(curl -sf "$url" 2>/dev/null | awk -F';' -v pid="$point_id" 'NR==1 || $1==pid' || true)
    if [[ -n "$data" ]]; then
      echo "$data"
      return 0
    fi
  done
  
  return 1
}

echo "🔮 Forecast (next $DAYS days):"
echo ""

if [[ -n "$POINT_ID" ]]; then
  # Try to get temperature (max) forecast
  TEMP_DATA=$(get_forecast_direct "$POINT_ID" "tre200dx" "$DAYS" || true)
  
  if [[ -n "$TEMP_DATA" ]]; then
    # Parse CSV output
    # Header: point_id;d0;d1;d2;d3;d4;d5;d6;...
    # Data:   48;14.5;15.2;16.1;...
    
    echo "$TEMP_DATA" | awk -F';' -v days="$DAYS" '
    NR==1 {
      # Parse header to get day offsets
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
        if ($i != "" && $i != "-") {
          printf "  %-10s %s°C max\n", headers[i] ":", $i
        }
      }
    }'
    
    # Try to get min temp
    MIN_DATA=$(get_forecast_direct "$POINT_ID" "tre200dn" "$DAYS" 2>/dev/null || true)
    if [[ -n "$MIN_DATA" ]]; then
      echo ""
      echo "  Min temps:"
      echo "$MIN_DATA" | awk -F';' -v days="$DAYS" '
      NR==1 { for (i=2; i<=NF && i-2<days; i++) headers[i] = $i }
      NR==2 {
        for (i=2; i<=NF && i-2<days; i++) {
          if ($i != "" && $i != "-") {
            printf "    %s: %s°C\n", headers[i], $i
          }
        }
      }'
    fi
    
    # Try to get precipitation
    RAIN_DATA=$(get_forecast_direct "$POINT_ID" "rka150d0" "$DAYS" 2>/dev/null || true)
    if [[ -n "$RAIN_DATA" ]]; then
      echo ""
      echo "  Rain (mm):"
      echo "$RAIN_DATA" | awk -F';' -v days="$DAYS" '
      NR==1 { for (i=2; i<=NF && i-2<days; i++) headers[i] = $i }
      NR==2 {
        for (i=2; i<=NF && i-2<days; i++) {
          if ($i != "" && $i != "-" && $i != "0.0" && $i != "0") {
            printf "    %s: %smm\n", headers[i], $i
          }
        }
      }'
    fi
    
  else
    echo "  ⚠️  Forecast data not available"
    echo ""
    echo "  The forecast CSVs may not be accessible with current date patterns."
    echo "  Try manual lookup from SKILL.md or check data.geo.admin.ch."
    echo ""
    
    if [[ -n "$STATION_ABBR" ]]; then
      echo "📊 Current weather (fallback):"
      "$SCRIPT_DIR/current-weather.sh" "$STATION_ABBR" 2>/dev/null | while IFS='=' read -r key value; do
        case "$key" in
          tre200s0) echo "   Temperature: ${value}°C" ;;
          ure200s0) echo "   Humidity: ${value}%" ;;
          rre150z0) echo "   Rain (10min): ${value}mm" ;;
          fu3010z0) echo "   Wind: ${value}km/h" ;;
          fu3010z1) echo "   Gusts: ${value}km/h" ;;
        esac
      done
    fi
  fi
else
  echo "  ⚠️  No point_id for $LOCATION"
  echo "      Need point_id (postal code location) for forecast"
fi

echo ""
echo "💡 Tip: Use 'search-forecast-points.sh' to find point_id for any location"
