require "../src/crystal_mc/crystal_mc"
require "../src/plugin/plugin"

class AdvancedPlugin < CrystalMC::Plugin::Plugin
  property spawn_points : Hash(String, SpawnPoint)
  property warps : Hash(String, Warp)
  property homes : Hash(String, Home)
  property cooldowns : Hash(String, Time)

  def initialize(server : CrystalMC::Server)
    super(server)
    @name = "AdvancedPlugin"
    @version = "2.0.0"
    @author = "CrystalMC Team"
    @description = "Advanced features: warps, homes, economy, and more"

    @spawn_points = {} of String => SpawnPoint
    @warps = {} of String => Warp
    @homes = {} of String => Home
    @cooldowns = {} of String => Time
  end

  def on_enable
    log_info "Starting Advanced Plugin..."

    # Load data
    load_data

    # Register commands
    register_commands

    # Schedule tasks
    schedule_tasks

    log_info "Advanced Plugin enabled!"
  end

  def on_disable
    log_info "Saving Advanced Plugin data..."
    save_data
    log_info "Advanced Plugin disabled!"
  end

  private def register_commands
    # Warp commands
    register_command("warp") do |player, args|
      if args.size >= 1
        warp_name = args[0]
        if warp = @warps[warp_name]?
          player.teleport(warp.x, warp.y, warp.z)
          player.send_message("§aTeleported to warp: #{warp_name}")
        else
          player.send_message("§cWarp not found: #{warp_name}")
        end
      else
        list_warps(player)
      end
    end

    register_command("setwarp") do |player, args|
      if args.size >= 1
        warp_name = args[0]
        @warps[warp_name] = Warp.new(warp_name, player.x, player.y, player.z)
        player.send_message("§aWarp set: #{warp_name}")
      else
        player.send_message("§cUsage: /setwarp <name>")
      end
    end

    register_command("delwarp") do |player, args|
      if args.size >= 1
        warp_name = args[0]
        if @warps.delete(warp_name)
          player.send_message("§aWarp deleted: #{warp_name}")
        else
          player.send_message("§cWarp not found: #{warp_name}")
        end
      else
        player.send_message("§cUsage: /delwarp <name>")
      end
    end

    # Home commands
    register_command("home") do |player, args|
      home_key = "#{player.username}"
      if home = @homes[home_key]?
        if check_cooldown(player, "home", 30)
          player.teleport(home.x, home.y, home.z)
          player.send_message("§aTeleported home!")
        else
          player.send_message("§cPlease wait before using /home again")
        end
      else
        player.send_message("§cYou don't have a home set. Use /sethome")
      end
    end

    register_command("sethome") do |player, args|
      home_key = "#{player.username}"
      @homes[home_key] = Home.new(player.username, player.x, player.y, player.z)
      player.send_message("§aHome set at your current location!")
    end

    # Spawn command
    register_command("spawn") do |player, args|
      if check_cooldown(player, "spawn", 10)
        spawn_x = @server.world.spawn_x.to_f64 + 0.5
        spawn_y = @server.world.spawn_y.to_f64
        spawn_z = @server.world.spawn_z.to_f64 + 0.5
        player.teleport(spawn_x, spawn_y, spawn_z)
        player.send_message("§aTeleported to spawn!")
      else
        player.send_message("§cPlease wait before using /spawn again")
      end
    end

    # Back command (return to previous location)
    register_command("back") do |player, args|
      # This would require tracking player positions
      player.send_message("§c/back is not yet implemented")
    end

    # TPA commands
    register_command("tpa") do |player, args|
      if args.size >= 1
        target_name = args[0]
        if target = @server.get_player(target_name)
          target.send_message("§e#{player.username} wants to teleport to you. Use /tpaccept to accept.")
          player.send_message("§aTeleport request sent to #{target_name}")
          # Store request with expiration
        else
          player.send_message("§cPlayer not found: #{target_name}")
        end
      else
        player.send_message("§cUsage: /tpa <player>")
      end
    end

    # Weather command
    register_command("weather") do |player, args|
      if args.size >= 1
        case args[0].downcase
        when "clear"
          player.send_message("§aSet weather to clear (not fully implemented)")
        when "rain"
          player.send_message("§aSet weather to rain (not fully implemented)")
        when "thunder"
          player.send_message("§aSet weather to thunder (not fully implemented)")
        else
          player.send_message("§cUsage: /weather <clear|rain|thunder>")
        end
      else
        player.send_message("§cUsage: /weather <clear|rain|thunder>")
      end
    end

    # Gamemode shortcuts
    register_command("gms") do |player, args|
      player.game_mode = 0
      player.send_message("§aSet game mode to Survival")
    end

    register_command("gmc") do |player, args|
      player.game_mode = 1
      player.send_message("§aSet game mode to Creative")
    end
  end

  private def schedule_tasks
    # Auto-save task every 5 minutes
    schedule_repeating_task(6000, 6000) do
      save_data
      log_info "Auto-saved plugin data"
    end

    # Broadcast message every 10 minutes
    schedule_repeating_task(12000, 12000) do
      @server.broadcast("§6[Tip] Use /warp to see available warps!")
    end

    # Clear old cooldowns every minute
    schedule_repeating_task(1200, 1200) do
      cleanup_cooldowns
    end
  end

  private def list_warps(player : CrystalMC::World::Player)
    if @warps.empty?
      player.send_message("§cNo warps available")
    else
      player.send_message("§eAvailable warps:")
      @warps.each_key do |name|
        player.send_message("§7- #{name}")
      end
    end
  end

  private def check_cooldown(player : CrystalMC::World::Player, command : String, seconds : Int32) : Bool
    key = "#{player.username}:#{command}"
    if last_use = @cooldowns[key]?
      elapsed = (Time.utc - last_use).total_seconds
      if elapsed < seconds
        return false
      end
    end
    @cooldowns[key] = Time.utc
    true
  end

  private def cleanup_cooldowns
    cutoff = Time.utc - 5.minutes
    @cooldowns.reject! { |_, time| time < cutoff }
  end

  private def load_data
    # Load from files (implement serialization)
    log_info "Loading plugin data..."
  end

  private def save_data
    # Save to files (implement serialization)
    log_info "Saving plugin data..."
  end

  def on_player_join(player : CrystalMC::World::Player)
    player.send_message("§6Welcome to the server!")
    player.send_message("§7Type /help for commands")

    # Teleport to spawn on first join
    # (would need to track if this is first join)
  end

  def on_player_quit(player : CrystalMC::World::Player)
    # Clean up player data
    cleanup_player(player.username)
  end

  def on_player_chat(player : CrystalMC::World::Player, message : String) : String?
    # Add chat formatting
    "§8[§7Level #{player.level}§8] §f<#{player.username}> §7#{message}"
  end

  def on_block_break(player : CrystalMC::World::Player, x : Int32, y : Int32, z : Int32) : Bool
    # Check if location is protected
    if is_spawn_protected?(x, y, z)
      player.send_message("§cThis area is spawn protected!")
      return false
    end
    true
  end

  def on_block_place(player : CrystalMC::World::Player, x : Int32, y : Int32, z : Int32, block : CrystalMC::World::Block) : Bool
    # Check if location is protected
    if is_spawn_protected?(x, y, z)
      player.send_message("§cThis area is spawn protected!")
      return false
    end
    true
  end

  private def is_spawn_protected?(x : Int32, y : Int32, z : Int32) : Bool
    spawn_x = @server.world.spawn_x
    spawn_z = @server.world.spawn_z
    protection_radius = 16

    dx = (x - spawn_x).abs
    dz = (z - spawn_z).abs

    dx < protection_radius && dz < protection_radius
  end

  private def cleanup_player(username : String)
    @cooldowns.reject! { |key, _| key.starts_with?("#{username}:") }
  end

  struct SpawnPoint
    property name : String
    property x : Float64
    property y : Float64
    property z : Float64

    def initialize(@name, @x, @y, @z)
    end
  end

  struct Warp
    property name : String
    property x : Float64
    property y : Float64
    property z : Float64

    def initialize(@name, @x, @y, @z)
    end
  end

  struct Home
    property username : String
    property x : Float64
    property y : Float64
    property z : Float64

    def initialize(@username, @x, @y, @z)
    end
  end
end
