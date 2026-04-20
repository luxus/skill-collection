#!/bin/bash
set -euo pipefail

# Get weather forecast for a location
# Usage: forecast.sh <point_id> [parameter]
# Requires: curl, awk, jq
# Example: forecast.sh 48 tre200dx

POINT_ID="${1:-}"
PARAM="${2:-tre200dx}"

if [[ -z "$POINT_ID" || "$1" == "--help" || "$1" == "-h" ]]; then
  cat << 'EOF'
Usage: forecast.sh <point_id> [parameter]

Get weather forecast for a Swiss location.
Data source: MeteoSwiss Open Data (ogd-local-forecasting)

Arguments:
  point_id    Location ID from search-forecast-points.sh
  parameter   Forecast parameter (default: tre200dx for daily max temp)
                Daily: tre200dx (max temp), tre200dn (min temp), 
                       rka150d0 (precip), jp2000d0 (weather icon)
                Hourly: tre200h0 (temp), rre150h0 (precip), jww003i0 (icon)

Output: date/time = value pairs

Examples:
  forecast.sh 48           # Daily max temp for Zürich (point_id=48)
  forecast.sh 48 tre200dn    # Daily min temp
  forecast.sh 48 rka150d0    # Daily precipitation

Note: STAC API sometimes returns documentation format instead of JSON.
If this happens, use manual curl commands from the SKILL.md documentation.
EOF
  exit "${POINT_ID:+1}"
fi

# Get latest forecast item
ITEM=$(curl -sf 'https://data.geo.admin.ch/api/stac/v1/collections/ch.meteoschweiz.ogd-local-forecasting/items?limit=10' 2>/dev/null \
  | jq -r '.features | map(.id) | sort | reverse | first' 2>/dev/null) || true

if [[ -z "$ITEM" || "$ITEM" == "null" ]]; then
  echo "Error: STAC API not returning valid data" >&2
  echo "Try manual approach from SKILL.md:" >&2
  echo '  ITEM=$(curl -s ... | jq -r ...)'
  echo '  ASSET_URL=$(curl -s ... | jq -r ...)'
  exit 1
fi

# Get asset URL for parameter
ASSET_URL=$(curl -sf "https://data.geo.admin.ch/api/stac/v1/collections/ch.meteoschweiz.ogd-local-forecasting/items/$ITEM" 2>/dev/null \
  | jq -r ".assets | to_entries | map(select(.key | contains(\"$PARAM\"))) | sort_by(.key) | last | .value.href" 2>/dev/null) || true

if [[ -z "$ASSET_URL" || "$ASSET_URL" == "null" ]]; then
  echo "Error: parameter '$PARAM' not found for item $ITEM" >&2
  exit 1
fi

# Download and filter for point_id
curl -sf "$ASSET_URL" \
  | awk -F';' -v pid="$POINT_ID" 'NR==1 || $1==pid' \
  || { echo "Error: failed to fetch forecast data" >&2; exit 1; }
