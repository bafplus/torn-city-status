# Torn City Status

An [Omarchy](https://omarchy.org/) shell plugin that shows your Torn City player status, timers, and cooldowns in the status bar.

## Preview

<img width="644" height="510" alt="image" src="https://github.com/user-attachments/assets/66799b4f-aa9b-442f-b2b7-787477646c58" />


## Features

- Player status display (Online, Hospital, Jail, Traveling, etc.)
- Hospital, Jail, and Traveling timers
- Drug, Medical, and Booster cooldown timers
- Energy, Nerve, Happy, and Life bars
- Chain timer display
- Quick links to Hospital, Travel, and Gym

## Installation

```bash
omarchy plugin add https://github.com/bafplus/torn-city-status.git --enable
```

## Configuration

1. Get your API key from [Torn Preferences](https://www.torn.com/preferences.php#tab=api)
2. Click on the Torn City Status widget in the bar
3. Click the gear icon to open settings
4. Enter your API key

## Settings

| Setting | Default | Description |
|---------|---------|-------------|
| API Key | (empty) | Your Torn API key |
| Update Interval | 30 | How often to fetch data (seconds) |
| Warning Time | 60 | When to show expiry warnings (seconds) |

## License

MIT
