# skill-collection

Personal skill collection for Pi AI Agent - Swiss weather data and more.

## MeteoSwiss OGD Skill

Swiss weather data from MeteoSwiss Open Government Data. No API key required.

### Quick Start

```bash
# For end users (human readable)
./weather 8001              # Zürich weather + forecast
./weather "Bern" 3          # Bern, 3 day forecast
./rain-check 4001           # Simple yes/no rain check

# For AI Agents (JSON output)
./weather-agent "Zürich"    # Structured data for interpretation
```

### Features

- **Postal codes**: Enter any Swiss 4-digit PLZ
- **City names**: Works with and without umlauts (Zürich = Zurich)
- **Auto-caching**: Databases built on first run (~2 min), then instant
- **Distance-based matching**: Finds nearest weather station with precise coordinates
- **JSON for agents**: Structured output for AI interpretation

### How It Works

1. **First run**: Downloads station metadata, builds local database (~2 min)
2. **Query**: Resolves PLZ/city to nearest station using Haversine distance
3. **Fetch**: Gets current weather + forecast from MeteoSwiss CSV endpoints
4. **Cache**: Subsequent queries use cached mapping

### Automatic Updates

Weather station databases are automatically updated monthly via GitHub Actions and published as releases.

**Download latest databases:**
```bash
curl -L https://github.com/luxus/skill-collection/releases/latest/download/plz-station-map.json
curl -L https://github.com/luxus/skill-collection/releases/latest/download/city-plz-map.json
```

### Files

- `weather` - Main CLI (human readable)
- `weather-agent` - AI Agent interface (JSON output)
- `weather-json` - Alternative JSON wrapper
- `rain-check` - Simple yes/no rain forecast
- `data/` - Pre-built databases (updated monthly)

### Installation

```bash
# Via Pi
pi install git:github.com/luxus/skill-collection

# Or manually
git clone https://github.com/luxus/skill-collection.git
```

### Data Source

- **Provider**: [MeteoSwiss](https://www.meteoswiss.admin.ch/)
- **Open Data**: [data.geo.admin.ch](https://data.geo.admin.ch)
- **License**: Open Government Data (CC BY 4.0)
- **Update**: Every 10 minutes (current), hourly (forecast)

## License

MIT - See LICENSE file
