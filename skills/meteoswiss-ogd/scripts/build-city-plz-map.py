#!/usr/bin/env python3
"""
Build city name → PLZ mapping from forecast metadata
Handles umlauts, case variations, and creates fuzzy match index
"""

import csv
import json
import re
from pathlib import Path
from collections import defaultdict

def normalize(name):
    """Normalize for matching: lowercase, umlauts→base, special chars removed"""
    name = name.lower()
    # Umlaute and special chars
    replacements = {
        'ü': 'u', 'ä': 'a', 'ö': 'o',
        'é': 'e', 'è': 'e', 'ê': 'e',
        'à': 'a', 'á': 'a', 'â': 'a',
        'ô': 'o', 'ó': 'o', 'ò': 'o',
        'î': 'i', 'í': 'i', 'ì': 'i',
        'û': 'u', 'ú': 'u', 'ù': 'u',
        'ç': 'c', 'ñ': 'n',
        ' ': '', '-': '', '_': '', '.': '', ',': ''
    }
    for old, new in replacements.items():
        name = name.replace(old, new)
    # Remove remaining non-alphanumeric
    name = re.sub(r'[^a-z0-9]', '', name)
    return name

def build_mapping():
    cache_dir = Path.home() / '.cache/meteoswiss-ogd'
    cache_dir.mkdir(parents=True, exist_ok=True)
    
    points_file = cache_dir / 'all-points.csv'
    output_file = cache_dir / 'city-plz-map.json'
    
    if not points_file.exists():
        print("Error: all-points.csv not found. Run build-station-plz-map.sh first.")
        return
    
    # city_name → [plz1, plz2, ...]
    city_to_plz = defaultdict(list)
    # normalized → original name (for fuzzy matching)
    normalized_map = {}
    
    with open(points_file, 'r', encoding='utf-8') as f:
        reader = csv.DictReader(f, delimiter=';')
        for row in reader:
            name = row.get('point_name', '').strip()
            plz = row.get('postal_code', '').strip()
            point_type = row.get('point_type_id', '')
            
            # Only postal codes (type 2) and stations (type 1)
            if name and plz and point_type in ['1', '2']:
                if plz not in city_to_plz[name]:
                    city_to_plz[name].append(plz)
                
                # Build normalized index
                norm = normalize(name)
                if norm not in normalized_map:
                    normalized_map[norm] = name
    
    # For cities with multiple PLZ, pick the "main" one (usually lowest or most common)
    # Sort by frequency or just take first
    final_map = {}
    for city, plzs in city_to_plz.items():
        # Prefer PLZ ending in 00 or 01 (usually city center)
        main_plz = None
        for plz in sorted(plzs):
            if plz.endswith('00') or plz.endswith('01'):
                main_plz = plz
                break
        if not main_plz:
            main_plz = plzs[0]
        
        final_map[city] = {
            'plz': main_plz,
            'all_plz': plzs,
            'normalized': normalize(city)
        }
    
    # Add normalized variants for common cities
    common_variants = {
        'Zurich': 'Zürich',
        'Zuerich': 'Zürich', 
        'Geneve': 'Genève',
        'Geneva': 'Genève',
        'Basel': 'Basel',
        'Bale': 'Basel',
        'Bern': 'Bern',
        'Berne': 'Bern',
        'Luzern': 'Luzern',
        'Lucerne': 'Luzern',
        'Lausanne': 'Lausanne',
        'Winterthur': 'Winterthur',
        'StGallen': 'St. Gallen',
        'St.Gallen': 'St. Gallen',
        'Lugano': 'Lugano',
        'Locarno': 'Locarno',
        'Davos': 'Davos',
        'Interlaken': 'Interlaken',
    }
    
    for variant, canonical in common_variants.items():
        if canonical in final_map:
            final_map[variant] = final_map[canonical]
    
    # Save
    data = {
        'cities': final_map,
        'normalized_index': normalized_map,
        'stats': {
            'total_cities': len(set(city for city in final_map.keys())),
            'total_plz_mappings': len(final_map)
        }
    }
    
    with open(output_file, 'w', encoding='utf-8') as f:
        json.dump(data, f, indent=2, ensure_ascii=False)
    
    print(f"✓ {data['stats']['total_cities']} Orte gemappt")
    print(f"✓ Gespeichert: {output_file}")
    
    # Show examples
    examples = ['Zürich', 'Basel', 'Genève', 'Luzern', 'Winterthur', 'St. Gallen']
    print("\nBeispiele:")
    for ex in examples:
        if ex in final_map:
            info = final_map[ex]
            print(f"  {ex} → PLZ {info['plz']} ({len(info['all_plz'])} PLZ total)")

if __name__ == '__main__':
    build_mapping()
