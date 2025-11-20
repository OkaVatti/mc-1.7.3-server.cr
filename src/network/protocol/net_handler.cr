require "./protocol_versions"

module CrystalMC::Network::Protocol
  class NetHandler
    def initialize(@connection : Connection)
    end

    def handle_handshake(packet : HandshakePacket)
      puts "🤝 Handling handshake: protocol=#{packet.protocol_version}, username='#{packet.username}'"

      @connection.username = packet.username
      @connection.state = :login

      # Send Beta 1.7.3 login response
      send_beta_1_7_3_login_response(packet.username)
    end

    def handle_login_request(packet : ClientLoginPacket)
      puts "🔐 Login request from: #{packet.username}"

      # Authenticate the user
      unless Auth::Authenticator.authenticate(packet.username)
        @connection.send_kick("Authentication failed.")
        return
      end

      @connection.logged_in = true
      @connection.username = packet.username

      puts "✅ Player #{packet.username} logged in successfully"

      # Send initial world data
      send_initial_world_data
    end

    def handle_keep_alive(packet : KeepAlivePacket)
      # Echo back the keep alive ID to prevent timeout
      response = KeepAlivePacket.new(packet.keep_alive_id)
      @connection.send_packet(response)
      puts "💓 Keep-alive response sent to #{@connection.username}"
    end

    def handle_kick_disconnect(packet : KickDisconnectPacket)
      @connection.disconnect(packet.reason)
    end

    def handle_chat(packet : ChatPacket)
      username = @connection.username
      return unless username

      player = @connection.player
      return unless player

      message = packet.message.strip

      # Check for commands
      if message.starts_with?("/")
        handle_command(message[1..], player)
      else
        # Call plugin chat event
        pm = @connection.server.plugin_manager
        modified_message = pm ? pm.call_player_chat(player, message) : message

        if modified_message
          # Broadcast chat message
          formatted = "<#{username}> #{modified_message}"
          @connection.server.broadcast(formatted)
          puts "💬 #{formatted}"
        end
      end
    end

    def handle_player_position(packet : PlayerPosPacket)
      player = @connection.player
      return unless player

      player.set_position(packet.x, packet.y, packet.z)
      player.on_ground = packet.on_ground

      # Broadcast position to other players in range
      broadcast_player_position(player)

      puts "🚶 Player #{@connection.username} moved to #{packet.x.round(2)}, #{packet.y.round(2)}, #{packet.z.round(2)}"
    end

    def handle_player_look(packet : PlayerLookPacket)
      player = @connection.player
      return unless player

      player.yaw = packet.yaw
      player.pitch = packet.pitch
      player.on_ground = packet.on_ground

      puts "👀 Player #{@connection.username} looking: yaw=#{packet.yaw.round(2)}, pitch=#{packet.pitch.round(2)}"
    end

    def handle_player_look_move(packet : PlayerLookMovePacket)
      player = @connection.player
      return unless player

      player.set_position(packet.x, packet.y, packet.z)
      player.yaw = packet.yaw
      player.pitch = packet.pitch
      player.on_ground = packet.on_ground

      # Broadcast position and look to other players
      broadcast_player_position(player)

      puts "🎯 Player #{@connection.username} moved and looked: #{packet.x.round(2)}, #{packet.y.round(2)}, #{packet.z.round(2)}"
    end

    def handle_block_dig(packet : BlockDigPacket)
      player = @connection.player
      return unless player

      world_x = packet.x
      world_y = packet.y.to_i32
      world_z = packet.z

      # Call plugin event
      cancelled = false
      @connection.server.plugin_manager.try do |pm|
        cancelled = !pm.call_block_break(player, world_x, world_y, world_z, packet.face)
      end

      unless cancelled
        # Handle block breaking - set to air
        air_block = World::Block.air
        @connection.server.world.set_block(world_x, world_y, world_z, air_block)

        # Broadcast block change
        block_change = BlockChangePacket.new(world_x, world_y.to_i8, world_z, 0, 0)
        @connection.server.broadcast_packet(block_change, @connection.username)

        puts "⛏️  Block broken at #{world_x}, #{world_y}, #{world_z}"
      end
    end

    def handle_block_place(packet : BlockPlacePacket)
      player = @connection.player
      return unless player

      world_x = packet.x
      world_y = packet.y.to_i32
      world_z = packet.z

      # Only place block if holding an item
      if packet.item_id > 0
        block_type = packet.item_id.to_u8

        # Calculate placement position based on face
        case packet.direction
        when 0 then world_y -= 1 # Bottom
        when 1 then world_y += 1 # Top
        when 2 then world_z -= 1 # North
        when 3 then world_z += 1 # South
        when 4 then world_x -= 1 # West
        when 5 then world_x += 1 # East
        end

        # Call plugin event
        cancelled = false
        @connection.server.plugin_manager.try do |pm|
          cancelled = !pm.call_block_place(player, world_x, world_y, world_z, block_type)
        end

        unless cancelled
          # Create proper Block object and place it
          block = World::Block.new(block_type, 0_u8)
          @connection.server.world.set_block(world_x, world_y, world_z, block)

          # Broadcast block change
          block_change = BlockChangePacket.new(world_x, world_y.to_i8, world_z, block_type, 0)
          @connection.server.broadcast_packet(block_change, @connection.username)

          puts "🧱 Block placed at #{world_x}, #{world_y}, #{world_z} (type: #{block_type})"
        end
      end
    end

    def handle_pre_chunk(packet : PreChunkPacket)
      puts "🗺️  Player #{@connection.username} pre-chunk: #{packet.x}, #{packet.z}, #{packet.mode}"
      # Client is requesting chunk load/unload - we handle chunk sending server-side
    end

    def handle_map_chunk(packet : MapChunkPacket)
      puts "🗺️  Player #{@connection.username} map chunk: #{packet.x}, #{packet.z}"
      # Client sent chunk data - we don't handle client-sent chunks in Beta 1.7.3
    end

    # Complete command handling system
    private def handle_command(command : String, player : World::Player)
      parts = command.split(' ')
      cmd = parts[0].downcase
      args = parts[1..]

      puts "🛠️  Command executed by #{player.username}: /#{command}"

      # Call plugin command event first
      handled = false
      @connection.server.plugin_manager.try do |pm|
        handled = pm.handle_command(player, cmd, args)
      end

      return if handled # Plugin handled the command

      # Built-in commands
      case cmd
      when "help", "?"
        send_help(player)
      when "list"
        list_players(player)
      when "stop", "shutdown"
        stop_server(player)
      when "tp", "teleport"
        teleport_player(player, args)
      when "gamemode", "mode"
        change_gamemode(player, args)
      when "time"
        handle_time_command(player, args)
      when "give"
        give_item(player, args)
      when "kill"
        kill_player(player)
      when "me"
        emote_action(player, args)
      when "say"
        broadcast_message(player, args)
      when "spawn"
        teleport_to_spawn(player)
      when "tps"
        show_tps(player)
      when "plugins", "pl"
        list_plugins(player)
      when "version", "about"
        show_version(player)
      else
        player.connection.send_chat_message("§cUnknown command: /#{cmd}")
        player.connection.send_chat_message("§cType /help for available commands.")
      end
    end

    private def send_help(player : World::Player)
      player.connection.send_chat_message("§6=== CrystalMC Commands ===")
      player.connection.send_chat_message("§a/help §7- Show this help message")
      player.connection.send_chat_message("§a/list §7- List online players")
      player.connection.send_chat_message("§a/tp <x> <y> <z> §7- Teleport to coordinates")
      player.connection.send_chat_message("§a/spawn §7- Teleport to spawn")
      player.connection.send_chat_message("§a/gamemode <0|1> §7- Change game mode")
      player.connection.send_chat_message("§a/time set <value> §7- Set world time")
      player.connection.send_chat_message("§a/give <item> [amount] §7- Give items")
      player.connection.send_chat_message("§a/me <action> §7- Perform an action")
      player.connection.send_chat_message("§a/say <message> §7- Broadcast message")
      player.connection.send_chat_message("§a/plugins §7- List loaded plugins")
      player.connection.send_chat_message("§a/version §7- Show server version")

      if player.op?
        player.connection.send_chat_message("§4/stop §7- Stop the server")
        player.connection.send_chat_message("§4/kill §7- Kill yourself")
      end
    end

    private def list_players(player : World::Player)
      players = @connection.server.players.values.map(&.username)
      if players.empty?
        player.connection.send_chat_message("§eNo players online.")
      else
        player.connection.send_chat_message("§ePlayers online (#{players.size}): §a#{players.join(", ")}")
      end
    end

    private def stop_server(player : World::Player)
      unless player.op?
        player.connection.send_chat_message("§cYou don't have permission to use this command.")
        return
      end

      player.connection.send_chat_message("§cStopping server...")
      @connection.server.broadcast("§cServer is shutting down...")
      spawn do
        sleep 1.second
        @connection.server.stop
      end
    end

    private def teleport_player(player : World::Player, args : Array(String))
      if args.size == 1
        # Teleport to another player
        target_name = args[0]
        target = @connection.server.get_player(target_name)
        if target
          player.set_position(target.x, target.y, target.z)
          send_player_spawn(player.x, player.y, player.z)
          player.connection.send_chat_message("§aTeleported to #{target_name}")
        else
          player.connection.send_chat_message("§cPlayer #{target_name} not found")
        end
      elsif args.size >= 3
        # Teleport to coordinates
        begin
          x = args[0].to_f64
          y = args[1].to_f64
          z = args[2].to_f64
          player.set_position(x, y, z)
          send_player_spawn(x, y, z)
          player.connection.send_chat_message("§aTeleported to #{x.round(1)}, #{y.round(1)}, #{z.round(1)}")
        rescue
          player.connection.send_chat_message("§cInvalid coordinates")
        end
      else
        player.connection.send_chat_message("§cUsage: /tp <player> OR /tp <x> <y> <z>")
      end
    end

    private def change_gamemode(player : World::Player, args : Array(String))
      unless player.op?
        player.connection.send_chat_message("§cYou don't have permission to use this command.")
        return
      end

      if args.empty?
        player.connection.send_chat_message("§cUsage: /gamemode <0|1>")
        return
      end

      mode = args[0].to_i?
      case mode
      when 0
        player.gamemode = :survival
        player.connection.send_chat_message("§aGame mode set to Survival")
      when 1
        player.gamemode = :creative
        player.connection.send_chat_message("§aGame mode set to Creative")
      else
        player.connection.send_chat_message("§cInvalid game mode. Use 0 for Survival or 1 for Creative")
      end
    end

    private def handle_time_command(player : World::Player, args : Array(String))
      unless player.op?
        player.connection.send_chat_message("§cYou don't have permission to use this command.")
        return
      end

      if args.size < 2
        player.connection.send_chat_message("§cUsage: /time set <value>")
        return
      end

      if args[0] == "set"
        time_value = args[1].to_i64?
        if time_value
          @connection.server.world.time = time_value
          player.connection.send_chat_message("§aTime set to #{time_value}")
        else
          player.connection.send_chat_message("§cInvalid time value")
        end
      else
        player.connection.send_chat_message("§cUnknown time subcommand")
      end
    end

    private def give_item(player : World::Player, args : Array(String))
      unless player.op?
        player.connection.send_chat_message("§cYou don't have permission to use this command.")
        return
      end

      if args.empty?
        player.connection.send_chat_message("§cUsage: /give <item_id> [amount]")
        return
      end

      item_id = args[0].to_i16?
      amount = (args[1]? || "1").to_i8?

      if item_id && amount && item_id > 0 && amount > 0
        player.give_item(item_id, amount)
        player.connection.send_chat_message("§aGave #{amount} of item #{item_id}")
      else
        player.connection.send_chat_message("§cInvalid item ID or amount")
      end
    end

    private def kill_player(player : World::Player)
      # In survival mode, kill the player
      if player.gamemode == :survival
        player.health = 0
        player.connection.send_chat_message("§cYou died!")
        # TODO: Handle player death and respawn
      else
        player.connection.send_chat_message("§cYou can't kill yourself in creative mode!")
      end
    end

    private def emote_action(player : World::Player, args : Array(String))
      if args.empty?
        player.connection.send_chat_message("§cUsage: /me <action>")
        return
      end

      action = args.join(" ")
      @connection.server.broadcast("§7* #{player.username} #{action}")
    end

    private def broadcast_message(player : World::Player, args : Array(String))
      unless player.op?
        player.connection.send_chat_message("§cYou don't have permission to use this command.")
        return
      end

      if args.empty?
        player.connection.send_chat_message("§cUsage: /say <message>")
        return
      end

      message = args.join(" ")
      @connection.server.broadcast("§5[Server] #{message}")
    end

    private def teleport_to_spawn(player : World::Player)
      spawn_x = @connection.server.world.spawn_x.to_f64 + 0.5
      spawn_y = @connection.server.world.spawn_y.to_f64
      spawn_z = @connection.server.world.spawn_z.to_f64 + 0.5

      player.set_position(spawn_x, spawn_y, spawn_z)
      send_player_spawn(spawn_x, spawn_y, spawn_z)
      player.connection.send_chat_message("§aTeleported to spawn")
    end

    private def show_tps(player : World::Player)
      # Simple TPS calculation (placeholder)
      tps = 20.0 # Would be calculated from actual tick timing

      # Format memory usage properly
      memory_mb = GC.stats.heap_size / 1024 / 1024

      player.connection.send_chat_message("§eTPS: §a#{tps.round(1)}")
      player.connection.send_chat_message("§eMemory: §a#{memory_mb} MB")
    end

    private def list_plugins(player : World::Player)
      pm = @connection.server.plugin_manager
      if pm
        plugins = pm.loaded_plugins
        if plugins.empty?
          player.connection.send_chat_message("§eNo plugins loaded")
        else
          player.connection.send_chat_message("§ePlugins (#{plugins.size}): §a#{plugins.join(", ")}")
        end
      else
        player.connection.send_chat_message("§ePlugin system not available")
      end
    end

    private def show_version(player : World::Player)
      player.connection.send_chat_message("§6CrystalMC §f- §aMinecraft Beta 1.7.3 Server")
      player.connection.send_chat_message("§fVersion: §a#{CrystalMC::VERSION}")
      player.connection.send_chat_message("§fWritten in Crystal #{Crystal::VERSION}")
      player.connection.send_chat_message("§fProtocol: §aBeta 1.7.3 (v14)")
    end

    private def broadcast_player_position(player : World::Player)
      # Broadcast player position to nearby players
      # This would send entity movement packets to other players in range
      # Implementation depends on your entity tracking system
    end

    # Beta 1.7.3 login response methods
    private def send_beta_1_7_3_login_response(username : String)
      entity_id = @connection.server.allocate_entity_id

      # Create player entity
      player = World::Player.new(@connection.server.world, entity_id, username, @connection)
      @connection.player = player
      @connection.server.add_player(player)

      puts "🎮 Player #{username} logged in (entity ID: #{entity_id})"

      # Send login response
      response = Protocol::ServerLoginPacket.new(
        entity_id: entity_id,
        username: username,
        seed: @connection.server.world.seed,
        level_type: "default",
        game_mode: 0,
        dimension: 0,
        difficulty: 0_u8,
        world_height: 128_u8,
        max_players: @connection.server.max_players.to_u8
      )
      @connection.send_packet(response)

      # Send all the necessary Beta 1.7.3 packets
      send_spawn_position(@connection.server.world.spawn_x, @connection.server.world.spawn_y, @connection.server.world.spawn_z)
      send_time_update
      send_spawn_chunks(@connection.server.world.spawn_x, @connection.server.world.spawn_z)

      # Send player position
      player.set_position(@connection.server.world.spawn_x.to_f64 + 0.5, @connection.server.world.spawn_y.to_f64, @connection.server.world.spawn_z.to_f64 + 0.5)
      send_player_spawn(player.x, player.y, player.z)

      # Send health
      send_health_update(player)

      # Broadcast join message (except to the joining player)
      @connection.server.broadcast_except("§e#{username} joined the game", username)

      puts "✅ Completed Beta 1.7.3 login sequence for #{username}"
    end

    private def send_spawn_position(x : Int32, y : Int32, z : Int32)
      spawn_packet = Protocol::SpawnPositionPacket.new(x, y, z)
      @connection.send_packet(spawn_packet)
    end

    private def send_time_update
      time_packet = Protocol::TimeUpdatePacket.new(@connection.server.world.time)
      @connection.send_packet(time_packet)
    end

    private def send_player_spawn(x : Float64, y : Float64, z : Float64)
      pos_packet = Protocol::PlayerLookMovePacket.new(
        x: x,
        y: y,
        stance: y + 1.62,
        z: z,
        yaw: 0.0_f32,
        pitch: 0.0_f32,
        on_ground: true
      )
      @connection.send_packet(pos_packet)
    end

    private def send_health_update(player : World::Player)
      health_packet = Protocol::HealthUpdatePacket.new(player.health.to_i16)
      @connection.send_packet(health_packet)
    end

    private def send_spawn_chunks(spawn_x : Int32, spawn_z : Int32)
      chunk_x = spawn_x // 16
      chunk_z = spawn_z // 16

      radius = 5 # Send 11x11 chunks around spawn

      (-radius..radius).each do |dx|
        (-radius..radius).each do |dz|
          cx = chunk_x + dx
          cz = chunk_z + dz

          # Send pre-chunk packet (prepare client for chunk data)
          pre_chunk = Protocol::PreChunkPacket.new(cx, cz, true)
          @connection.send_packet(pre_chunk)

          # Get or generate chunk
          chunk = @connection.server.world.get_chunk(cx, cz)
          next unless chunk

          # Send chunk data
          chunk_packet = Protocol::MapChunkPacket.from_chunk(chunk)
          @connection.send_packet(chunk_packet)
        end
      end

      puts "🗺️  Sent #{(radius * 2 + 1) ** 2} chunks to #{@connection.username}"
    end

    private def send_initial_world_data
      return unless @connection.logged_in?

      puts "🌍 Sending initial world data to #{@connection.username}"

      # Send spawn position
      send_spawn_position(@connection.server.world.spawn_x, @connection.server.world.spawn_y, @connection.server.world.spawn_z)

      # Send time update
      send_time_update

      # Send a welcome message
      @connection.send_chat_message("§6Welcome to CrystalMC Beta 1.7.3 Server!")
      @connection.send_chat_message("§7Type /help for available commands.")
    end
  end
end
