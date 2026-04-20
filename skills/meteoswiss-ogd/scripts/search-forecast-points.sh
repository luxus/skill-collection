#!/bin/bash
set -euo pipefail

# Search forecast locations by postal code or name
# Usage: search-forecast-points.sh <query>
# Requires: curl, iconv, awk, jq
# Example: search-forecast-points.sh 8001

QUERY="${1:-}"

if [[ -z "$QUERY" || "$1" == "--help" || "$1" == "-h" ]]; then
  cat << 'EOF'
Usage: search-forecast-points.sh <query>

Search forecast locations (~6000 points: stations, postal codes, mountains).
Data source: MeteoSwiss Open Data (ogd-local-forecasting)

Arguments:
  query  Search term (case-insensitive, matches postal code or name)

Output: point_id | type | postal_code | station | name

Examples:
  search-forecast-points.sh 8001     # Zürich postal code
  search-forecast-points.sh bern     # by name
  search-forecast-points.sh 1200    # Genève
EOF
  exit "${QUERY:+1}"
fi

QUERY_LOWER=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]')

# Get metadata URL from STAC
META_URL=$(curl -sf 'https://data.geo.admin.ch/api/stac/v1/collections/ch.meteoschweiz.ogd-local-forecasting' \
  | jq -r '.assets | to_entries | map(select(.key | contains("meta_point"))) | first | .value.href') \
  || { echo "Error: failed to fetch STAC metadata" >&2; exit 1; }

curl -sf "$META_URL" \
  | iconv -f latin1 -t utf-8 \
  | awk -F';' -v q="$QUERY_LOWER" '
    NR == 1 { next }
    {
      line = tolower($0)
      if (line ~ q) {
        type = $2 == "1" ? "station" : ($2 == "2" ? "postal" : "mountain")
        printf "%s | %s | %s | %s | %s\n", $1, type, $3, $4, $5
      }
    }' || { echo "Error: failed to fetch forecast points" >&2; exit 1; }
