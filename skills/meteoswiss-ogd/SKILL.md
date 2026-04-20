---
name: meteoswiss-ogd
description: >-
  Schweizer Wetterdaten von MeteoSwiss Open Government Data.
  Aktuelles Wetter, Prognosen, Regen-Check. Kein API-Key nötig.
globs: []
---

# MeteoSwiss Open Government Data

Schweizer Wetterdaten direkt von MeteoSwiss OGD. Alle Daten sind frei verfügbar, kein API-Key nötig.

**Datenquelle:** `data.geo.admin.ch`  
**Aktualisierung:** Alle 10 Minuten (Wetter), stündlich (Prognose)

---

## Schnellstart

### Einfachste Nutzung (ein Script, alles drin)

```bash
./weather 8001              # PLZ → Wetter + Prognose
./weather "Zürich"          # Ort → Wetter + Prognose
./weather "Zurich" 5        # Ohne Umlaut, 5-Tage Prognose
./weather 4001 1            # Basel, nur heute
```

**Funktioniert mit:**
- ✅ Postleitzahlen (4 Ziffern)
- ✅ Ortsnamen (mit/ohne Umlaute)
- ✅ Automatische Station-Zuordnung
- ✅ Caching für schnelle Wiederholung

### Für Agenten/Skills (JSON Output)

```bash
./weather-json 8001         # Strukturierte JSON-Daten
./weather-json "Bern" 3     # 3 Tage als JSON
```

### Einfache Ja/Nein-Fragen (Regen)

```bash
./rain-check 8001           # Regnet es heute/morgen?
./rain-check "Basel" 3      # Regen-Check 3 Tage
```

---

## Wie es funktioniert

1. **PLZ oder Ort eingeben** → Script findet automatisch nächste Wetterstation
2. **Datenbank wird erstellt** (beim ersten Lauf, ~2 Minuten)
3. **Abfrage** → Aktuelles Wetter + Prognose von MeteoSwiss
4. **Caching** → Folgende Aufrufe sind schneller

---

## Datenbank aufbauen (einmalig)

Beim ersten Lauf werden automatisch erstellt:
- `~/.cache/meteoswiss-ogd/plz-station-map.json` — ~3200 PLZ → Stationen
- `~/.cache/meteoswiss-ogd/city-plz-map.json` — ~4000 Ortsnamen → PLZ

Das dauert ~2 Minuten und ist dann dauerhaft verfügbar.

---

## Beispiele

### Wetterabfragen

```bash
# Aktuelles Wetter
./weather 8001
# → 14.9°C, Sonnig, Wind 4km/h

# Mit Prognose
./weather "Winterthur" 3
# → Heute: 14°C | Morgen: 12°C | Übermorgen: 15°C

# Nur heute, kurz
./weather 4001 1
```

### Regen-Check

```bash
# Einfache Ja/Nein-Antwort
./rain-check "Zürich"
# → Heute: ☀️ NEIN | Morgen: ☀️ NEIN

# Mehr Tage
./rain-check 6003 5
# → Lugano: Kein Regen für 5 Tage erwartet
```

### JSON für Verarbeitung

```bash
./weather-json 8001 | jq '.current.Temperatur'
# → 14.9

./weather-json "Bern" | jq '.forecast[0].max_c'
# → 11.0
```

---

## Technische Details

**Dateien im Skill:**
- `weather` — Hauptscript (Bash, alles in einem)
- `weather-json` — Python Wrapper für JSON Output
- `rain-check` — Einfacher Regen-Check
- `scripts/` — Hilfsscripts für Datenbank-Aufbau

**Cache:**
- `~/.cache/meteoswiss-ogd/` — Lokale Datenbanken

---

## Troubleshooting

| Problem | Lösung |
|---------|--------|
| "Ort nicht gefunden" | Versuche die PLZ direkt |
| "Datenbank nicht gefunden" | Erst `./weather <plz>` ausführen |
| Langsam beim ersten Mal | Normal, baut Datenbank auf |
| Umlaute funktionieren nicht | Versuche ohne: `Zurich` statt `Zürich` |

---

## Für Entwickler

**Rohdaten-URLs:**
- Aktuelles Wetter: `https://data.geo.admin.ch/ch.meteoschweiz.messwerte-aktuell/VQHA80.csv`
- Stationen: `https://data.geo.admin.ch/ch.meteoschweiz.ogd-smn/ogd-smn_meta_stations.csv`
- Prognose-Orte: `https://data.geo.admin.ch/ch.meteoschweiz.ogd-local-forecasting/ogd-local-forecasting_meta_point.csv`

Siehe `REFERENCE.md` für vollständige API-Dokumentation.
