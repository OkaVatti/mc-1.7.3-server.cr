# CrystalMC - Minecraft Beta 1.7.3 Server

A high-performance Minecraft Beta 1.7.3 server implementation written in Crystal.

## Features

- ✅ Full Minecraft Beta 1.7.3 protocol support
- ✅ Advanced terrain generation with Perlin noise
- ✅ Cave generation
- ✅ Ore generation (coal, iron, gold)
- ✅ Multi-biome support
- ✅ Plugin system with event hooks
- ✅ Permission system
- ✅ Custom commands
- ✅ Player management
- ✅ Inventory system
- ✅ Health and respawn mechanics
- ✅ Configuration system
- ✅ 20 TPS server tick rate

## Requirements

- Crystal 1.14.0 or higher
- Linux/macOS (Windows via WSL)

## Installation
```bash
# Clone the repository
git clone https://github.com/yourusername/crystalmc.git
cd crystalmc

# Install dependencies
make install

# Build the server
make build

# Or build optimized release version
make release
```

## Running the Server
```bash
# Run with default settings
make run

# Run with custom settings
HOST=0.0.0.0 PORT=25565 MAX_PLAYERS=20 make run

# Or run the binary directly
./bin/minecraft-server
```

## Configuration

Edit `server.yml` to configure the server:
```yaml
server_name: "CrystalMC Server"
server_port: 25565
server_ip: "0.0.0.0"
max_players: 20
motd: "A Minecraft Beta 1.7.3 Server"
view_distance: 10
online_mode: false
difficulty: 1
gamemode: 0
pvp: true
world_name: "world"
```

## Plugin Development

Create a new plugin by extending the `Plugin` class:
```crystal
class MyPlugin < CrystalMC::Plugin::Plugin
  def initialize(server)
    super(server)
    @name = "MyPlugin"
    @version = "1.0.0"
    @author = "YourName"
  end

  def on_enable
    register_command("mycommand") do |player, args|
      player.send_message("Hello from MyPlugin!")
    end
  end

  def on_disable
    # Cleanup
  end
end
```

## Commands

### Built-in Commands

- `/help` - Show available commands
- `/list` - List online players
- `/tp <x> <y> <z>` - Teleport to coordinates
- `/time <set|add|day|night> [value]` - Change world time
- `/gamemode <0|1>` - Change game mode
- `/give <item_id> [amount]` - Give items
- `/kill` - Kill yourself
- `/heal` - Restore health
- `/spawn` - Teleport to spawn

### Plugin Commands (Example Plugin)

- `/warp [name]` - Teleport to warp or list warps
- `/setwarp <name>` - Set a warp point
- `/delwarp <name>` - Delete a warp
- `/home` - Teleport home
- `/sethome` - Set home location

## Development
```bash
# Format code
make format

# Run linter
make lint

# Run tests
make test
```

## Performance

CrystalMC is designed for performance:

- Maintains 20 TPS even with multiple players
- Efficient chunk generation and caching
- Optimized packet handling
- Low memory footprint

## Contributing

Contributions are welcome! Please feel free to submit pull requests.

## License

MIT License - See LICENSE file for details

## Acknowledgments

- Minecraft Beta 1.7.3 protocol documentation
- Crystal programming language community