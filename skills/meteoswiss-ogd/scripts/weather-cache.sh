#!/bin/bash
set -euo pipefail

# Cache manager for MeteoSwiss weather locations
# Usage: weather-cache.sh [get|set|list|delete] [location] [data...]
# Stored in ~/.cache/meteoswiss-ogd/locations.json

CACHE_DIR="${HOME}/.cache/meteoswiss-ogd"
CACHE_FILE="$CACHE_DIR/locations.json"

mkdir -p "$CACHE_DIR"

# Initialize empty cache if needed
[[ -f "$CACHE_FILE" ]] || echo '{}' > "$CACHE_FILE"

get_cache() {
  jq -r ".$1 // empty" "$CACHE_FILE" 2>/dev/null || echo ""
}

set_cache() {
  local location="$1"
  local postal_code="${2:-}"
  local station_abbr="${3:-}"
  local station_name="${4:-}"
  local point_id="${5:-}"
  
  # Read current cache
  local temp_file=$(mktemp)
  jq --arg loc "$location" \
     --arg pc "$postal_code" \
     --arg sa "$station_abbr" \
     --arg sn "$station_name" \
     --arg pid "$point_id" \
     '.[$loc] = {
       postal_code: $pc,
       station_abbr: $sa,
       station_name: $sn,
       point_id: $pid,
       updated: now | todate
     }' "$CACHE_FILE" > "$temp_file" && mv "$temp_file" "$CACHE_FILE"
  
  echo "Saved: $location"
}

list_cache() {
  echo "Cached locations:"
  jq -r 'to_entries | .[] | "  \(.key): station=\(.value.station_abbr // "?"), plz=\(.value.postal_code // "?"), point=\(.value.point_id // "?")"' "$CACHE_FILE" 2>/dev/null || echo "  (empty)"
}

delete_cache() {
  local location="$1"
  local temp_file=$(mktemp)
  jq "del(.\"$location\")" "$CACHE_FILE" > "$temp_file" && mv "$temp_file" "$CACHE_FILE"
  echo "Deleted: $location"
}

# CLI
CMD="${1:-list}"
LOC="${2:-}"

case "$CMD" in
  get)
    if [[ -z "$LOC" ]]; then
      echo "Usage: weather-cache.sh get <location>"
      exit 1
    fi
    RESULT=$(get_cache "$LOC")
    if [[ -n "$RESULT" ]]; then
      echo "$RESULT" | jq -r 'to_entries | .[] | "\(.key)=\(.value)"'
    else
      echo "Location not cached: $LOC"
      exit 1
    fi
    ;;
  set)
    if [[ -z "$LOC" ]]; then
      cat << 'EOF'
Usage: weather-cache.sh set <location> [postal_code] [station_abbr] [station_name] [point_id]

Example:
  weather-cache.sh set "Eglisau" "8193" "LAE" "Lägern" "819300"
  weather-cache.sh set "Zürich" "8000" "SMA" "Zürich/Fluntern" "48"
EOF
      exit 1
    fi
    set_cache "$LOC" "${3:-}" "${4:-}" "${5:-}" "${6:-}"
    ;;
  list|ls)
    list_cache
    ;;
  delete|rm)
    if [[ -z "$LOC" ]]; then
      echo "Usage: weather-cache.sh delete <location>"
      exit 1
    fi
    delete_cache "$LOC"
    ;;
  *)
    cat << 'EOF'
Usage: weather-cache.sh [get|set|list|delete] [args]

Commands:
  get <location>              Get cached data for location
  set <location> [fields...]  Save location data
  list                        List all cached locations
  delete <location>           Remove location from cache

Examples:
  weather-cache.sh set "Eglisau" "8193" "LAE" "Lägern" "819300"
  weather-cache.sh get "Eglisau"
  weather-cache.sh list
EOF
    ;;
esac
