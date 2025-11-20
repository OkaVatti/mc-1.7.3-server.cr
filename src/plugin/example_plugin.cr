require "../src/crystal_mc/crystal_mc"
require "../src/plugin/plugin"

class ExamplePlugin < CrystalMC::Plugin::Plugin
  def initialize(server : CrystalMC::Server)
    super(server)
    @name = "ExamplePlugin"
    @version = "1.0.0"
    @author = "CrystalMC Team"
    @description = "An example plugin demonstrating the plugin API"
  end

  def on_enable
    log_info "Example plugin is starting!"

    # Register a custom command
    register_command("example") do |player, args|
      player.send_message("§aHello from ExamplePlugin!")
      player.send_message("§7You passed #{args.size} arguments: #{args.join(", ")}")
    end

    register_command("heal") do |player, args|
      player.heal(20.0_f32)
      player.send_message("§aYou have been healed!")
    end

    register_command("fly") do |player, args|
      player.send_message("§cFlight is not implemented yet!")
    end

    # Schedule a repeating task
    schedule_repeating_task(0, 200) do # Every 10 seconds
      @server.broadcast("§e[Reminder] This server is running ExamplePlugin!")
    end

    log_info "Example plugin enabled successfully!"
  end

  def on_disable
    log_info "Example plugin is shutting down!"
  end

  def on_player_join(player : CrystalMC::World::Player)
    player.send_message("§6Welcome #{player.username}! This server has ExamplePlugin installed.")
  end

  def on_player_quit(player : CrystalMC::World::Player)
    @server.broadcast("§e#{player.username} left the game")
  end

  def on_player_chat(player : CrystalMC::World::Player, message : String) : String?
    # Add player name coloring
    if player.username.starts_with?("Admin")
      return "§c[ADMIN] #{player.username}: §f#{message}"
    end
    message
  end

  def on_block_break(player : CrystalMC::World::Player, x : Int32, y : Int32, z : Int32) : Bool
    block = @server.world.get_block(x, y, z)
    if block.id == CrystalMC::World::Block::BEDROCK
      player.send_message("§cYou cannot break bedrock!")
      return false
    end
    true
  end

  def on_block_place(player : CrystalMC::World::Player, x : Int32, y : Int32, z : Int32, block : CrystalMC::World::Block) : Bool
    # Example: Prevent placing TNT (block ID 46)
    if block.id == 46_u8
      player.send_message("§cTNT is disabled on this server!")
      return false
    end
    true
  end

  def on_command(player : CrystalMC::World::Player, command : String, args : Array(String)) : Bool
    # Example: Handle a command that wasn't registered
    if command == "time"
      if args.size > 0 && args[0] == "day"
        @server.world.time = 0
        player.send_message("§aSet time to day")
        return true
      elsif args.size > 0 && args[0] == "night"
        @server.world.time = 14000
        player.send_message("§aSet time to night")
        return true
      end
    end
    false
  end
end
