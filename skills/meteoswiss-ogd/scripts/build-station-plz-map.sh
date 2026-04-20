#!/bin/bash
set -euo pipefail

# Build complete PLZ → Station mapping using coordinates
# Downloads all stations and forecast points, finds nearest station for each PLZ

CACHE_DIR="${HOME}/.cache/meteoswiss-ogd"
STATIONS_FILE="${CACHE_DIR}/all-stations.csv"
POINTS_FILE="${CACHE_DIR}/all-points.csv"
MAP_FILE="${CACHE_DIR}/plz-station-map.json"

mkdir -p "$CACHE_DIR"

echo "🔄 Lade alle Wetterstationen..."
curl -sf "https://data.geo.admin.ch/ch.meteoschweiz.ogd-smn/ogd-smn_meta_stations.csv" \
  | iconv -f latin1 -t utf-8 > "$STATIONS_FILE"

# Header: station_abbr;station_name;station_canton;station_height_masl;station_coordinates_wgs84_lat;station_coordinates_wgs84_lon
STATION_COUNT=$(tail -n +2 "$STATIONS_FILE" | wc -l)
echo "✓ $STATION_COUNT Stationen geladen"

echo ""
echo "🔄 Lade alle Prognose-Orte (~6000)..."
curl -sf "https://data.geo.admin.ch/ch.meteoschweiz.ogd-local-forecasting/ogd-local-forecasting_meta_point.csv" \
  | iconv -f latin1 -t utf-8 > "$POINTS_FILE"

# Header: point_id;point_type_id;station_abbr;postal_code;point_name;...;point_coordinates_wgs84_lat;point_coordinates_wgs84_lon
POINT_COUNT=$(tail -n +2 "$POINTS_FILE" | wc -l)
echo "✓ $POINT_COUNT Orte geladen"

echo ""
echo "🔄 Berechne beste Station für jede PLZ..."

# Python für Koordinaten-Berechnung
python3 << 'PY' - "$STATIONS_FILE" "$POINTS_FILE" "$MAP_FILE"
import csv
import sys
import json
import math
from pathlib import Path

stations_file = sys.argv[1]
points_file = sys.argv[2]
output_file = sys.argv[3]

# Load stations
stations = {}
with open(stations_file, 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f, delimiter=';')
    for row in reader:
        abbr = row.get('station_abbr', '')
        if abbr:
            try:
                lat = float(row.get('station_coordinates_wgs84_lat', 0))
                lon = float(row.get('station_coordinates_wgs84_lon', 0))
                stations[abbr] = {
                    'name': row.get('station_name', ''),
                    'canton': row.get('station_canton', ''),
                    'lat': lat,
                    'lon': lon
                }
            except ValueError:
                pass

print(f"  {len(stations)} Stationen mit Koordinaten")

# Load points (filter for postal codes - type 2, or stations - type 1)
plz_points = {}
with open(points_file, 'r', encoding='utf-8') as f:
    reader = csv.DictReader(f, delimiter=';')
    for row in reader:
        plz = row.get('postal_code', '').strip()
        point_type = row.get('point_type_id', '')
        
        # Type 2 = postal code, Type 1 = station
        if plz and point_type in ['1', '2']:
            try:
                lat = float(row.get('point_coordinates_wgs84_lat', 0))
                lon = float(row.get('point_coordinates_wgs84_lon', 0))
                station_abbr = row.get('station_abbr', '')
                
                if plz not in plz_points:
                    plz_points[plz] = []
                
                plz_points[plz].append({
                    'point_id': row.get('point_id', ''),
                    'type': point_type,
                    'name': row.get('point_name', ''),
                    'lat': lat,
                    'lon': lon,
                    'station_abbr': station_abbr  # if type 1
                })
            except ValueError:
                pass

print(f"  {len(plz_points)} einzigartige PLZ gefunden")

# Haversine distance
def haversine(lat1, lon1, lat2, lon2):
    R = 6371  # km
    phi1 = math.radians(lat1)
    phi2 = math.radians(lat2)
    delta_phi = math.radians(lat2 - lat1)
    delta_lambda = math.radians(lon2 - lon1)
    
    a = math.sin(delta_phi/2)**2 + math.cos(phi1) * math.cos(phi2) * math.sin(delta_lambda/2)**2
    c = 2 * math.atan2(math.sqrt(a), math.sqrt(1-a))
    return R * c

# Pre-build station point_id lookup
station_point_ids = {}
for row in csv.DictReader(open(points_file, 'r', encoding='utf-8'), delimiter=';'):
    if row.get('point_type_id') == '1' and row.get('station_abbr'):
        try:
            station_point_ids[row['station_abbr']] = row['point_id']
        except:
            pass

print(f"  {len(station_point_ids)} Stationen mit point_ids gefunden")

# Build mapping: for each PLZ, find nearest station
mapping = {}
errors = 0

for plz, points in plz_points.items():
    # Use first point for this PLZ (usually there's one main point per PLZ)
    point = points[0]
    
    # If it's a station type (1), use that station directly
    if point['type'] == '1' and point['station_abbr'] in stations:
        st = stations[point['station_abbr']]
        station_abbr = point['station_abbr']
        # Get the station's point_id (for forecasts)
        station_point_id = station_point_ids.get(station_abbr, point['point_id'])
        mapping[plz] = {
            'station': station_abbr,
            'station_name': st['name'],
            'point_id': station_point_id,  # Station's point_id for forecasts
            'plz_point_id': point['point_id'],  # PLZ location point_id
            'distance_km': 0.0
        }
        continue
    
    # Find nearest station by distance
    nearest = None
    min_dist = float('inf')
    
    for abbr, st in stations.items():
        try:
            dist = haversine(point['lat'], point['lon'], st['lat'], st['lon'])
            if dist < min_dist:
                min_dist = dist
                nearest = abbr
        except:
            pass
    
    if nearest and min_dist < 100:  # Max 100km
        st = stations[nearest]
        # Get the station's point_id for forecasts
        station_point_id = station_point_ids.get(nearest, '')
        mapping[plz] = {
            'station': nearest,
            'station_name': st['name'],
            'point_id': station_point_id,  # Station's point_id for forecasts
            'plz_point_id': point['point_id'],  # PLZ location point_id  
            'distance_km': round(min_dist, 1)
        }
    else:
        errors += 1

print(f"  {len(mapping)} PLZ erfolgreich zugeordnet")
if errors > 0:
    print(f"  {errors} PLZ konnten nicht zugeordnet werden (zu weit weg)")

# Save mapping
with open(output_file, 'w', encoding='utf-8') as f:
    json.dump(mapping, f, indent=2, ensure_ascii=False)

print(f"\n✓ Mapping gespeichert: {output_file}")
print(f"  Beispiel: 8000 → {mapping.get('8000', {}).get('station_name', 'n/a')}")
print(f"  Beispiel: 8280 → {mapping.get('8280', {}).get('station_name', 'n/a')}")
PY

echo ""
echo "💡 Nutzung im weather Script:"
echo "   jq -r '.\"8280\".station' ~/.cache/meteoswiss-ogd/plz-station-map.json"
echo ""
echo "Fertig!"
