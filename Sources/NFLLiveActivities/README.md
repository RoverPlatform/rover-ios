# RoverNFLLiveActivities

NFL-specific Live Activity widget implementation for displaying live game scores and updates.

## Asset Catalog

This module includes an asset catalog with team logos and brand colors for all 32 NFL teams.

### Adding Team Assets

To add or update team branding:

1. **Team Logos**: Add team logo images to `Resources/Assets.xcassets/TeamLogos/[ABBREVIATION].imageset/`
   - Use the team's official abbreviation (e.g., KC, SF, DAL)
   - SVG format is preferred for resolution-independent scaling
   - Logo should be square and work well on both light and dark backgrounds

2. **Team Colors**: Add team primary brand color to `Resources/Assets.xcassets/TeamColors/[ABBREVIATION].colorset/`
   - Use the same abbreviation as the logo
   - Define both light and dark mode variants if needed
   - Use the team's primary brand color

### Team Abbreviations

The following 32 NFL team abbreviations are supported (using ESPN standard):

- ARI (Arizona Cardinals)
- ATL (Atlanta Falcons)
- BAL (Baltimore Ravens)
- BUF (Buffalo Bills)
- CAR (Carolina Panthers)
- CHI (Chicago Bears)
- CIN (Cincinnati Bengals)
- CLE (Cleveland Browns)
- DAL (Dallas Cowboys)
- DEN (Denver Broncos)
- DET (Detroit Lions)
- GB (Green Bay Packers)
- HOU (Houston Texans)
- IND (Indianapolis Colts)
- JAX (Jacksonville Jaguars)
- KC (Kansas City Chiefs)
- LAC (Los Angeles Chargers)
- LAR (Los Angeles Rams)
- LV (Las Vegas Raiders)
- MIA (Miami Dolphins)
- MIN (Minnesota Vikings)
- NE (New England Patriots)
- NO (New Orleans Saints)
- NYG (New York Giants)
- NYJ (New York Jets)
- PHI (Philadelphia Eagles)
- PIT (Pittsburgh Steelers)
- SF (San Francisco 49ers)
- SEA (Seattle Seahawks)
- TB (Tampa Bay Buccaneers)
- TEN (Tennessee Titans)
- WAS (Washington Commanders)

### Adding Assets

Team logo images need to be added manually to the imagesets:
1. Navigate to `Resources/Assets.xcassets/TeamLogos/[ABBREVIATION].imageset/`
2. Replace the placeholder SVG file with the actual team logo
3. Update team colors in `Resources/Assets.xcassets/TeamColors/[ABBREVIATION].colorset/Contents.json`
4. The asset catalog will be automatically compiled into the module bundle

Note: Team assets are referenced directly by abbreviation. Ensure all 32 NFL teams have corresponding logo and color assets in the catalog. Abbreviations follow ESPN's standard and can be updated based on server API requirements.
