# MeteoSwiss OGD Reference

Complete reference for MeteoSwiss Open Government Data parameters and codes.

## Current Weather Parameters (VQHA80.csv)

Real-time measurements, updated every 10 minutes.

| Parameter | Description | Unit |
|-----------|-------------|------|
| `tre200s0` | Air temperature 2m above ground | °C |
| `ure200s0` | Relative humidity 2m above ground | % |
| `tde200s0` | Dew point temperature 2m | °C |
| `rre150z0` | Precipitation, 10-minute total | mm |
| `fu3010z0` | Mean wind speed 10min | km/h |
| `fu3010z1` | Wind gust peak (max) | km/h |
| `dkl010z0` | Wind direction | ° (0-360) |
| `sre000z0` | Sunshine duration, 10-minute total | min |
| `gre000z0` | Global radiation | W/m² |
| `prestas0` | Atmospheric pressure at station level | hPa |
| `pp0qffs0` | Pressure reduced to sea level (QFF) | hPa |
| `htoauts0` | Total snow depth | cm |

## Forecast Parameters — Daily (Stations only)

| Parameter | Description | Unit |
|-----------|-------------|------|
| `tre200dx` | Daily maximum temperature 2m | °C |
| `tre200dn` | Daily minimum temperature 2m | °C |
| `rka150d0` | Daily precipitation total | mm |
| `jp2000d0` | Weather pictogram code (daytime) | — |

## Forecast Parameters — Hourly (All locations)

| Parameter | Description | Unit |
|-----------|-------------|------|
| `tre200h0` | Hourly temperature 2m | °C |
| `rre150h0` | Hourly precipitation | mm |
| `jww003i0` | 3-hourly weather pictogram code | — |

## Weather Icons

SVG URL: `https://www.meteoschweiz.admin.ch/static/resources/weather-symbols/{CODE}.svg`

### Day Icons (1-35)

| Code | Description |
|------|-------------|
| 1 | Sunny |
| 2 | Mostly sunny, some clouds |
| 3 | Partly sunny, thick passing clouds |
| 4 | Overcast |
| 5 | Very cloudy |
| 6 | Sunny intervals, isolated showers |
| 7 | Sunny intervals, isolated sleet |
| 8 | Sunny intervals, snow showers |
| 9 | Overcast, some rain showers |
| 10 | Overcast, some sleet |
| 11 | Overcast, some snow showers |
| 12 | Sunny intervals, chance of thunderstorms |
| 13 | Sunny intervals, possible thunderstorms |
| 14 | Very cloudy, light rain |
| 15 | Very cloudy, light sleet |
| 16 | Very cloudy, light snow showers |
| 17 | Very cloudy, intermittent rain |
| 18 | Very cloudy, intermittent sleet |
| 19 | Very cloudy, intermittent snow |
| 20 | Very overcast with rain |
| 21 | Very overcast with frequent sleet |
| 22 | Very overcast with heavy snow |
| 23 | Very overcast, slight chance of storms |
| 24 | Very overcast with storms |
| 25 | Very cloudy, very stormy |
| 26 | High clouds |
| 27 | Stratus |
| 28 | Fog |
| 29 | Sunny intervals, scattered showers |
| 30 | Sunny intervals, scattered snow showers |
| 31 | Sunny intervals, scattered sleet |
| 32 | Sunny intervals, some showers |
| 33 | Short sunny intervals, frequent rain |
| 34 | Short sunny intervals, frequent snowfall |
| 35 | Overcast and dry |

### Night Icons (101-142)

Night codes = day code + 100

| Code | Description |
|------|-------------|
| 101 | Clear |
| 102 | Slightly overcast |
| 103 | Heavy cloud formations |
| 104 | Overcast |
| 105 | Very cloudy |
| ... | ... (add 100 to day codes 6-35) |
| 142 | Very cloudy, thundery snow showers |

## Pollen Types

| Code (d1) | Pollen type | Latin name |
|-----------|-------------|------------|
| `kaalnud1` | Alder | Alnus |
| `kabetud1` | Birch | Betula |
| `kacoryd1` | Hazel | Corylus |
| `kafagud1` | Beech | Fagus |
| `kafraxd1` | Ash | Fraxinus |
| `kaquerd1` | Oak | Quercus |
| `khpoacd1` | Grasses | Poaceae |

Resolution `d1` = calendar day (0-0 UTC). Values in particles/m³.

## Pollen Stations

| Abbr | Station name |
|------|--------------|
| PBE | Bern |
| PBS | Basel |
| PBU | Buchs (SG) |
| PCF | La Chaux-de-Fonds |
| PDS | Davos |
| PGE | Genève |
| PJU | Jungfraujoch |
| PLO | Locarno |
| PLS | Lausanne |
| PLU | Lugano |
| PLZ | Luzern |
| PMU | Münsterlingen |
| PNE | Neuchâtel |
| PPY | Payerne |
| PSN | Sion |
| PZH | Zürich |

URL pattern (lowercase): `https://data.geo.admin.ch/ch.meteoschweiz.ogd-pollen/{abbr}/ogd-pollen_{abbr}_d_recent.csv`

## STAC Collections

All at `https://data.geo.admin.ch/api/stac/v1/collections/{ID}`

| Collection ID | Description |
|---------------|-------------|
| `ch.meteoschweiz.ogd-smn` | SwissMetNet automatic stations |
| `ch.meteoschweiz.ogd-local-forecasting` | Local forecasts ~6000 locations |
| `ch.meteoschweiz.ogd-pollen` | Pollen concentration |
| `ch.meteoschweiz.ogd-smn-precip` | Precipitation measurements |
| `ch.meteoschweiz.ogd-smn-tower` | Tower measurements |
| `ch.meteoschweiz.ogd-nbcn` | Swiss NBCN climate stations |
| `ch.meteoschweiz.ogd-radiosounding` | Radiosounding data |

## Common Station Codes

| Code | Location | Canton |
|------|----------|--------|
| SMA | Zürich / Kloten | ZH |
| BER | Bern / Zollikofen | BE |
| GVE | Genève / Cointrin | GE |
| LUG | Lugano | TI |
| BAS | Basel / Binningen | BS |
| PAY | Payerne | VD |
| SIO | Sion | VS |
| CHZ | Chur | GR |
| StG | St. Gallen | SG |
| LUZ | Luzern | LU |
| AAR | Aarau | AG |
| NEU | Neuchâtel | NE |
| LCF | La Chaux-de-Fonds | NE |
| LOC | Locarno / Magadino | TI |
