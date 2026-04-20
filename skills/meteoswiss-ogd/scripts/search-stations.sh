#!/bin/bash
set -euo pipefail

# Search Swiss weather stations by name or canton
# Usage: search-stations.sh <query>
# Requires: curl, iconv, awk
# Example: search-stations.sh zürich

QUERY="${1:-}"

if [[ -z "$QUERY" || "$1" == "--help" || "$1" == "-h" ]]; then
  cat << 'EOF'
Usage: search-stations.sh <query>

Search SwissMetNet weather stations by name, canton, or abbreviation.
Data source: MeteoSwiss Open Data (ogd-smn_meta_stations.csv)

Arguments:
  query  Search term (case-insensitive, matches name/canton/abbr)

Output: abbr | name | canton | elevation | lat | lon

Examples:
  search-stations.sh zürich
  search-stations.sh ZH       # canton
  search-stations.sh SMA      # abbreviation
EOF
  exit "${QUERY:+1}"
fi

QUERY_LOWER=$(echo "$QUERY" | tr '[:upper:]' '[:lower:]')
URL="https://data.geo.admin.ch/ch.meteoschweiz.ogd-smn/ogd-smn_meta_stations.csv"

curl -sf "$URL" \
  | iconv -f latin1 -t utf-8 \
  | awk -F';' -v q="$QUERY_LOWER" '
    NR == 1 { next }
    {
      line = tolower($0)
      if (line ~ q) {
        printf "%s | %s | %s | %sm | %s, %s\n", $1, $2, $3, $11, $15, $16
      }
    }' || { echo "Error: failed to fetch station data" >&2; exit 1; }
