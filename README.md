# Lean Logs

A lightweight, passive logging mod for Luanti (Minetest) servers. 

**Lean Logs** does not interfere with gameplay. It does not block actions, kick players, or alter physics. It simply observes server events, records them to files, and flags suspicious activity for server administrators to review later.

## Features

- **Connection Logs:** Records player joins, leaves, and IP addresses.
- **Chat Logs:** Saves all public chat messages with timestamps.
- **Error Logger:** Hooks into `minetest.log` to catch and save all `[WARNING]` and `[ERROR]` messages from any mod into a dedicated `errors.log` file.
- **AutoClick Detection:** Logs players who punch more than 15 times per second.
- **Speed / Teleport Detection:** Logs players who move faster than 10 blocks per second.
- **Multi-Account Detection:** Logs when multiple player names connect from the same IP address.

## Log Files

The mod automatically creates a `logs/` folder inside your world directory (`worlds/YOUR_WORLD/logs/`). It generates the following files:

- `connections.log` (Joins, leaves, IPs)
- `chat.log` (Public chat)
- `errors.log` (Engine and mod warnings/errors)
- `detection.log` (Suspicious speed or click rates)

## Why "Lean"?

- **No `globalstep`:** Player speed is checked once per second, not 60 times per second. Punch counters are simple integers, not heavy tables.
- **Fast Math:** Uses squared distance instead of `vector.distance` to save CPU cycles on the hot path.

## License

- **Code:** GPL-3.0-only (Copyright (C) 2026 8a7l)