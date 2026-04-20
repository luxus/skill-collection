# skill-collection

Personal skill collection for Pi AI Agent - Swiss weather data and more.

## MeteoSwiss OGD Skill

Swiss weather data from [MeteoSwiss Open Government Data](https://www.meteoswiss.admin.ch/). No API key required.

### Quick Start

```bash
# Human readable output
./weather 8001              # Zürich weather + forecast
./weather "Bern" 3          # Bern, 3 day forecast
./rain-check 4001           # Simple yes/no rain check

# AI Agent interface (JSON)
./weather-agent "Zürich"    # Structured data for interpretation
```

### Features

- **Postal codes**: Any Swiss 4-digit PLZ (8001, 4001, etc.)
- **City names**: With/without umlauts (Zürich = Zurich)
- **Distance-based matching**: Finds nearest weather station
- **Auto-download**: Databases download automatically on first run
- **JSON for agents**: Structured output for AI interpretation

### How It Works

1. **First run**: Downloads pre-built database from GitHub Releases (~1 MB, few seconds)
2. **Query**: Resolves PLZ/city to nearest station using Haversine distance
3. **Fetch**: Gets current weather + forecast from MeteoSwiss CSV endpoints
4. **Cache**: Local cache for offline use

### Database Updates

Databases are **automatically updated monthly** via GitHub Actions:
- Workflow: `.github/workflows/update-databases.yml`
- Trigger: 1st of every month (or manual)
- Release: New release created with updated JSON files

**Pre-built databases** (download manually if needed):
```bash
curl -L -o ~/.cache/meteoswiss-ogd/plz-station-map.json \
  https://github.com/luxus/skill-collection/releases/latest/download/plz-station-map.json
  
curl -L -o ~/.cache/meteoswiss-ogd/city-plz-map.json \
  https://github.com/luxus/skill-collection/releases/latest/download/city-plz-map.json
```

### Files

| File | Purpose |
|------|---------|
| `weather` | Main CLI (human readable) |
| `weather-agent` | AI Agent interface (JSON) |
| `weather-json` | Alternative JSON wrapper |
| `rain-check` | Simple yes/no rain forecast |
| `data/` | Pre-built databases (committed to repo) |

### Installation

**Via Pi:**
```bash
pi install git:github.com/luxus/skill-collection
```

**Manual:**
```bash
git clone https://github.com/luxus/skill-collection.git
cd skill-collection/skills/meteoswiss-ogd
./weather 8001
```

### Data Source

| | |
|---|---|
| **Provider** | [MeteoSwiss](https://www.meteoswiss.admin.ch/) |
| **Open Data** | [data.geo.admin.ch](https://data.geo.admin.ch) |
| **License** | Open Government Data (CC BY 4.0) |
| **Updates** | Every 10 min (current), hourly (forecast) |

## CI/CD

### Database Updates

- **Workflow**: `.github/workflows/update-databases.yml`
- **Schedule**: 1st of every month at 00:00 UTC
- **Manual trigger**: Via GitHub Actions "Run workflow"
- **Output**: New release with `plz-station-map.json` and `city-plz-map.json`

### Releasing

When the workflow runs, it automatically:
1. Builds fresh databases from MeteoSwiss metadata
2. Creates a new release (e.g., `v42`)
3. Attaches JSON files as release assets
4. Updates the `latest` redirect

## License

MIT - See LICENSE file
