module CrystalMC::Network
  class PacketHandler
    property connection : Connection

    def initialize(@connection : Connection)
    end

    def is_beta_1_7_3_legacy? : Bool
      # Beta 1.7.3 clients sometimes send legacy handshakes
      @protocol_version == 0 && !@username.empty? && @server_host == "localhost" && @server_port == 25565
    end

    def handle_handshake(packet : Protocol::HandshakePacket)
      puts "🖐 Received handshake: protocol=#{packet.protocol_version}, username='#{packet.username}', host='#{packet.server_host}', port=#{packet.server_port}"

      if packet.is_beta_1_7_3_legacy? || packet.valid_for_beta_1_7_3?
        puts "✅ Beta 1.7.3 handshake accepted for #{packet.username}"

        # Always use Beta 1.7.3 protocol (version 14)
        @connection.protocol_version = 14
        @connection.username = packet.username
        @connection.state = :login

        # Send Beta 1.7.3 login response
        send_beta_1_7_3_login_response(packet.username)
      else
        puts "❌ Unsupported protocol version: #{packet.protocol_version}"
        disconnect("Unsupported protocol version")
        return
      end
    end

    private def send_beta_1_7_3_login_response(username : String)
      entity_id = @connection.server.allocate_entity_id

      # Create player entity
      player = World::Player.new(@connection.server.world, entity_id, username, @connection)
      @connection.player = player
      @connection.server.add_player(player)
      # Spawn this player for all other players
      spawn_player_for_others(player)

      # Spawn all other players for this player
      spawn_other_players_for(player)

      puts "Player #{username} logged in (entity ID: #{entity_id})"

      # Use ServerLoginPacket instead of LoginPacket
      response = Protocol::ServerLoginPacket.new(
        entity_id: entity_id,
        username: username,
        level_type: "default",
        game_mode: 0,
        dimension: 0,
        difficulty: 0_u8,
        world_height: 128_u8,
        max_players: @connection.server.max_players.to_u8
      )
      @connection.send_packet(response)
      puts "📤 Sent Beta 1.7.3 LOGIN response to #{username}"

      # Mark as logged in
      @connection.logged_in = true

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

    private def despawn_player_for_others(player : World::Player)
      destroy_packet = Protocol::EntityDestroyPacket.new(player.entity_id)

      @connection.server.@connections.each do |conn|
        next unless conn.logged_in?
        next if conn.username == player.username

        conn.send_packet(destroy_packet)
      end
    end

    private def spawn_player_for_others(player : World::Player)
      x = (player.x * 32).to_i32
      y = (player.y * 32).to_i32
      z = (player.z * 32).to_i32
      yaw = ((player.yaw / 360.0) * 256).to_i8
      pitch = ((player.pitch / 360.0) * 256).to_i8

      spawn_packet = Protocol::NamedEntitySpawnPacket.new(
        entity_id: player.entity_id,
        player_name: player.username,
        x: x,
        y: y,
        z: z,
        rotation: yaw,
        pitch: pitch,
        current_item: 0
      )

      @connection.server.@connections.each do |conn|
        next unless conn.logged_in?
        next if conn.username == player.username

        conn.send_packet(spawn_packet)
      end
    end

    private def spawn_other_players_for(player : World::Player)
      @connection.server.players.each_value do |other_player|
        next if other_player.username == player.username

        x = (other_player.x * 32).to_i32
        y = (other_player.y * 32).to_i32
        z = (other_player.z * 32).to_i32
        yaw = ((other_player.yaw / 360.0) * 256).to_i8
        pitch = ((other_player.pitch / 360.0) * 256).to_i8

        spawn_packet = Protocol::NamedEntitySpawnPacket.new(
          entity_id: other_player.entity_id,
          player_name: other_player.username,
          x: x,
          y: y,
          z: z,
          rotation: yaw,
          pitch: pitch,
          current_item: 0
        )

        @connection.send_packet(spawn_packet)
      end
    end

    def handle_login(packet : Protocol::LoginPacket)
      username = packet.username

      # Validate username
      if username.size > MAX_PLAYER_NAME_LENGTH || username.empty?
        @connection.send_kick("Invalid username")
        return
      end

      # Check server capacity
      if @connection.server.player_count >= @connection.server.max_players
        @connection.send_kick("Server is full")
        return
      end

      # Check if player already logged in
      if @connection.server.get_player(username)
        @connection.send_kick("Player already logged in")
        return
      end

      # Store username and mark as logged in
      @connection.username = username
      @connection.logged_in = true

      # Create player entity
      entity_id = @connection.server.allocate_entity_id
      player = World::Player.new(@connection.server.world, entity_id, username, @connection)
      @connection.player = player
      @connection.server.add_player(player)

      puts "Player #{username} logged in (entity ID: #{entity_id})"

      # Send login response
      response = Protocol::LoginPacket.new(
        entity_id: entity_id,
        username: "",
        seed: @connection.server.world.seed,
        dimension: 0_i8
      )
      @connection.send_packet(response)

      # Send spawn position
      spawn_x = @connection.server.world.spawn_x
      spawn_y = @connection.server.world.spawn_y
      spawn_z = @connection.server.world.spawn_z

      send_spawn_position(spawn_x, spawn_y, spawn_z)

      # Send initial time
      send_time_update

      # Send chunks around spawn
      send_spawn_chunks(spawn_x, spawn_z)

      # Send player position
      player.set_position(spawn_x.to_f64 + 0.5, spawn_y.to_f64, spawn_z.to_f64 + 0.5)
      send_player_spawn(player.x, player.y, player.z)

      # Send health
      send_health_update(player)

      # Broadcast join message (except to the joining player)
      @connection.server.broadcast_except("§e#{username} joined the game", username)
    end

    def handle_chat(packet : Protocol::ChatPacket)
      username = @connection.username
      return unless username

      player = @connection.player
      return unless player

      message = packet.message

      # Check for commands
      if message.starts_with?("/")
        handle_command(message[1..], player)
      else
        # Call plugin chat event
        modified_message = @connection.server.plugin_manager.call_player_chat(player, message)

        if modified_message
          # Broadcast chat message
          formatted = "<#{username}> #{modified_message}"
          @connection.server.broadcast(formatted)
          puts formatted
        end
      end
    end

    def handle_keep_alive(packet : Protocol::KeepAlivePacket)
      @connection.last_keep_alive = Time.utc
    end

    def handle_player_position(packet : Protocol::PlayerPositionPacket)
      player = @connection.player
      return unless player

      player.x = packet.x
      player.y = packet.y
      player.z = packet.z
      player.on_ground = packet.on_ground

      broadcast_player_movement
    end

    def handle_player_look(packet : Protocol::PlayerLookPacket)
      player = @connection.player
      return unless player

      player.yaw = packet.yaw
      player.pitch = packet.pitch
      player.on_ground = packet.on_ground

      broadcast_player_movement
    end

    def handle_player_look_move(packet : Protocol::PlayerLookMovePacket)
      player = @connection.player
      return unless player

      player.x = packet.x
      player.y = packet.y
      player.z = packet.z
      player.yaw = packet.yaw
      player.pitch = packet.pitch
      player.on_ground = packet.on_ground

      broadcast_player_movement
    end

    def send_initial_chunks(player_chunk_x : Int32, player_chunk_z : Int32, view_distance : Int32)
      @connection.send_initial_chunks(player_chunk_x, player_chunk_z, view_distance)
    end

    def broadcast_player_movement
      player = @connection.player
      return unless player

      # Convert to absolute integer positions (scaled by 32 for precision)
      x = (player.x * 32).to_i32
      y = (player.y * 32).to_i32
      z = (player.z * 32).to_i32
      yaw = ((player.yaw / 360.0) * 256).to_i8
      pitch = ((player.pitch / 360.0) * 256).to_i8

      # Send entity teleport packet to all other players
      teleport_packet = Protocol::EntityTeleportPacket.new(
        entity_id: player.entity_id,
        x: x,
        y: y,
        z: z,
        yaw: yaw,
        pitch: pitch
      )

      @connection.server.@connections.each do |conn|
        next unless conn.logged_in?
        next if conn.username == player.username

        conn.send_packet(teleport_packet)
      end
    end

    def handle_block_dig(packet : Protocol::BlockDigPacket)
      player = @connection.player
      return unless player

      x = packet.x
      y = packet.y.to_i32
      z = packet.z

      # Call plugin event
      unless @connection.server.plugin_manager.call_block_break(player, x, y, z)
        # Plugin cancelled the event - send block back to client
        resend_block(x, y, z)
        return
      end

      # Handle based on status
      case packet.status
      when 0 # Started digging
        puts "#{player.username} started digging block at #{x}, #{y}, #{z}"
      when 2 # Finished digging
        puts "#{player.username} broke block at #{x}, #{y}, #{z}"

        # Remove the block
        @connection.server.world.set_block(x, y, z, World::Block.air)

        # Broadcast block change to all players
        broadcast_block_change(x, y, z, 0_u8, 0_u8)
      when 3 # Drop item
        puts "#{player.username} dropped item"
      end
    end

    def handle_block_place(packet : Protocol::BlockPlacePacket)
      player = @connection.player
      return unless player

      return if packet.item_id == -1 # No item in hand

      x = packet.x
      y = packet.y.to_i32
      z = packet.z
      direction = packet.direction

      # Calculate placement position based on direction
      case direction
      when 0 # Bottom
        y -= 1
      when 1 # Top
        y += 1
      when 2 # North (-Z)
        z -= 1
      when 3 # South (+Z)
        z += 1
      when 4 # West (-X)
        x -= 1
      when 5 # East (+X)
        x += 1
      end

      # For simplicity, assume item_id corresponds to block_id
      block = World::Block.new(packet.item_id.to_u8, 0_u8)

      # Call plugin event
      unless @connection.server.plugin_manager.call_block_place(player, x, y, z, block)
        # Plugin cancelled the event - resend original block
        resend_block(x, y, z)
        return
      end

      puts "#{player.username} placing block #{block.id} at #{x}, #{y}, #{z}"

      # Place the block
      @connection.server.world.set_block(x, y, z, block)

      # Broadcast block change to all players
      broadcast_block_change(x, y, z, block.id, block.metadata)
    end

    private def handle_command(command_str : String, player : World::Player)
      parts = command_str.split(' ')
      command = parts[0].downcase
      args = parts[1..]

      # Try plugin commands first
      if @connection.server.plugin_manager.handle_command(player, command, args)
        return
      end

      # Built-in commands
      case command
      when "help"
        player.send_message("§eAvailable commands:")
        player.send_message("§7/help - Show this message")
        player.send_message("§7/list - List online players")
        player.send_message("§7/tp <x> <y> <z> - Teleport")
        player.send_message("§7/time <set|add> <value> - Change time")
        player.send_message("§7/gamemode <mode> - Change game mode")
        player.send_message("§7/give <item> [amount] - Give items")
        player.send_message("§7/stop - Stop the server")
      when "list"
        player_list = @connection.server.players.keys.join(", ")
        count = @connection.server.player_count
        max = @connection.server.max_players
        player.send_message("§ePlayers online (#{count}/#{max}): #{player_list}")
      when "stop"
        player.send_message("§cStopping server...")
        spawn { @connection.server.stop }
      when "tp"
        if args.size >= 3
          begin
            x = args[0].to_f64
            y = args[1].to_f64
            z = args[2].to_f64
            player.teleport(x, y, z)
            player.send_message("§aTeleported to #{x}, #{y}, #{z}")
          rescue
            player.send_message("§cInvalid coordinates")
          end
        else
          player.send_message("§cUsage: /tp <x> <y> <z>")
        end
      when "time"
        if args.size >= 2
          case args[0].downcase
          when "set"
            begin
              time = args[1].to_i64
              @connection.server.world.time = time
              player.send_message("§aSet time to #{time}")
            rescue
              player.send_message("§cInvalid time value")
            end
          when "add"
            begin
              amount = args[1].to_i64
              @connection.server.world.time += amount
              player.send_message("§aAdded #{amount} to time")
            rescue
              player.send_message("§cInvalid time value")
            end
          else
            player.send_message("§cUsage: /time <set|add> <value>")
          end
        elsif args.size == 1
          case args[0].downcase
          when "day"
            @connection.server.world.time = 1000
            player.send_message("§aSet time to day")
          when "night"
            @connection.server.world.time = 13000
            player.send_message("§aSet time to night")
          else
            player.send_message("§cUsage: /time <set|add|day|night>")
          end
        else
          player.send_message("§cUsage: /time <set|add> <value>")
        end
      when "gamemode", "gm"
        if args.size >= 1
          begin
            mode = args[0].to_i
            if mode >= 0 && mode <= 1
              player.game_mode = mode
              mode_name = mode == 0 ? "Survival" : "Creative"
              player.send_message("§aSet game mode to #{mode_name}")
            else
              player.send_message("§cInvalid game mode (0 = Survival, 1 = Creative)")
            end
          rescue
            player.send_message("§cInvalid game mode")
          end
        else
          player.send_message("§cUsage: /gamemode <0|1>")
        end
      when "give"
        if args.size >= 1
          begin
            item_id = args[0].to_i16
            amount = args.size >= 2 ? args[1].to_i8 : 64_i8

            if player.inventory.add_item(item_id, amount)
              player.send_message("§aGave #{amount}x #{item_id}")
            else
              player.send_message("§cInventory full")
            end
          rescue
            player.send_message("§cInvalid item ID or amount")
          end
        else
          player.send_message("§cUsage: /give <item_id> [amount]")
        end
      when "kill"
        player.die
        player.send_message("§cYou have been killed")
      when "heal"
        player.heal(20.0_f32)
        player.send_message("§aYou have been healed")
      when "spawn"
        spawn_x = @connection.server.world.spawn_x.to_f64 + 0.5
        spawn_y = @connection.server.world.spawn_y.to_f64
        spawn_z = @connection.server.world.spawn_z.to_f64 + 0.5
        player.teleport(spawn_x, spawn_y, spawn_z)
        player.send_message("§aTeleported to spawn")
      else
        player.send_message("§cUnknown command: #{command}. Type /help for help.")
      end
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

      puts "Sent #{(radius * 2 + 1) ** 2} chunks to #{@connection.username}"
    end

    private def broadcast_block_change(x : Int32, y : Int32, z : Int32, block_id : UInt8, metadata : UInt8)
      # Send block change to all connected players
      @connection.server.@connections.each do |conn|
        next unless conn.logged_in?

        # Create block change packet
        io = IO::Memory.new
        Protocol::ProtocolHelper.write_ubyte(io, 0x35_u8) # Block change packet
        Protocol::ProtocolHelper.write_int(io, x)
        Protocol::ProtocolHelper.write_byte(io, y.to_i8)
        Protocol::ProtocolHelper.write_int(io, z)
        Protocol::ProtocolHelper.write_ubyte(io, block_id)
        Protocol::ProtocolHelper.write_ubyte(io, metadata)

        conn.socket.write(io.to_slice)
        conn.socket.flush rescue nil
      end
    end

    private def resend_block(x : Int32, y : Int32, z : Int32)
      block = @connection.server.world.get_block(x, y, z)

      io = IO::Memory.new
      Protocol::ProtocolHelper.write_ubyte(io, 0x35_u8) # Block change packet
      Protocol::ProtocolHelper.write_int(io, x)
      Protocol::ProtocolHelper.write_byte(io, y.to_i8)
      Protocol::ProtocolHelper.write_int(io, z)
      Protocol::ProtocolHelper.write_ubyte(io, block.id)
      Protocol::ProtocolHelper.write_ubyte(io, block.metadata)

      @connection.socket.write(io.to_slice)
      @connection.socket.flush rescue nil
    end
  end
end
