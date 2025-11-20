require "./protocol_versions"

module CrystalMC::Network::Protocol
  class NetHandler
    def initialize(@connection : Connection)
    end

    private def send_beta_1_7_3_login_response(username : String)
      entity_id = @connection.server.allocate_entity_id

      # Create player entity
      player = World::Player.new(@connection.server.world, entity_id, username, @connection)
      @connection.player = player
      @connection.server.add_player(player)

      puts "Player #{username} logged in (entity ID: #{entity_id})"

      # Send login response
      response = Protocol::LoginPacket.new(
        entity_id: entity_id,
        username: username,
        seed: @connection.server.world.seed,
        dimension: 0_i8
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

      puts "📤 Sent Beta 1.7.3 login response to #{username}"
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

    # Public entrypoint used by packets (e.g. HandshakePacket#handle)
    def handle_handshake(packet : Protocol::HandshakePacket)
      # Use the packet_handler which is now guaranteed to be initialized
      @connection.packet_handler.handle_handshake(packet)
    end

    # Existing public handlers (login, keep-alive, chat, etc.)
    def handle_login_request(packet : ClientLoginPacket)
      puts "🔐 Login request from: #{packet.username} (entity: #{packet.entity_id}, mode: #{packet.game_mode})"

      # Authenticate the user
      unless Auth::Authenticator.authenticate(packet.username)
        @connection.send_kick("Authentication failed.")
        return
      end

      # Set the connection as logged in
      @connection.logged_in = true
      @connection.username = packet.username

      puts "🎉 Player #{packet.username} logged in successfully (entity ID: #{packet.entity_id})"

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
      puts "💬 Chat received from #{@connection.username}: #{packet.message}"
      # Echo back or process chat message
      @connection.send_chat_message("Echo: #{packet.message}")
    end

    def handle_player_position(packet : PlayerPosPacket)
      puts "🚶 Player #{@connection.username} moved to #{packet.x}, #{packet.y}, #{packet.z}"
      # Update player position in the world
    end

    def handle_player_look(packet : PlayerLookPacket)
      puts "👀 Player #{@connection.username} looking: yaw=#{packet.yaw}, pitch=#{packet.pitch}"
      # Update player look direction
    end

    def handle_player_look_move(packet : PlayerLookMovePacket)
      puts "🎯 Player #{@connection.username} moved and looked"
      # Update both position and look direction
    end

    def handle_block_dig(packet : BlockDigPacket)
      puts "⛏️  Player #{@connection.username} digging at #{packet.x}, #{packet.y}, #{packet.z}"
      # Handle block digging
    end

    def handle_block_place(packet : BlockPlacePacket)
      puts "🧱 Player #{@connection.username} placing block at #{packet.x}, #{packet.y}, #{packet.z}"
      # Handle block placement
    end

    def handle_pre_chunk(packet : PreChunkPacket)
      puts "🗺️  Player #{@connection.username} pre-chunk: #{packet.x}, #{packet.z}, #{packet.mode}"
      # Handle pre-chunk (chunk loading/unloading)
    end

    def handle_map_chunk(packet : MapChunkPacket)
      puts "🗺️  Player #{@connection.username} map chunk: #{packet.x}, #{packet.z}"
      # Handle map chunk (chunk data)
    end

    private def handle_beta_1_0_1_1_handshake(packet : HandshakePacket)
      # Validate username
      unless Auth::Authenticator.validate_username(packet.username)
        @connection.send_kick("Invalid username: '#{packet.username}'")
        return
      end

      # Beta 1.0-1.1 handshake: store username and proceed with a compatible login response
      @connection.username = packet.username
      puts "✅ Beta 1.0-1.1 handshake accepted for #{@connection.username}"

      send_login_response(packet.username, packet.protocol_version)
    end

    private def handle_valid_beta_1_7_3_handshake(packet : HandshakePacket)
      # Validate username
      unless Auth::Authenticator.validate_username(packet.username)
        @connection.send_kick("Invalid username: '#{packet.username}'")
        return
      end

      # Store username for authentication
      @connection.username = packet.username

      puts "✅ Valid Beta 1.7.3 handshake from #{packet.username}, sending login response"

      # Send login response (pass protocol for any protocol-specific variance)
      send_login_response(packet.username, packet.protocol_version)
    end

    private def handle_invalid_handshake(packet : HandshakePacket, version_name : String)
      if packet.protocol_version == 0
        puts "❌ Client sent protocol version 0 - likely using wrong Minecraft version"
        @connection.send_kick("Invalid protocol version. Please use Minecraft Beta 1.7.3.")
      elsif packet.protocol_version != 14
        puts "❌ Wrong protocol version: #{packet.protocol_version} (#{version_name})"
        @connection.send_kick("Unsupported protocol version #{packet.protocol_version} (#{version_name}). This server is for Minecraft Beta 1.7.3 (protocol 14).")
      else
        puts "❌ Incomplete handshake - malformed packet"
        @connection.send_kick("Invalid handshake packet. Please use Minecraft Beta 1.7.3.")
      end
    end

    private def send_login_response(username : String, protocol_version : Int32 = 14)
      # Create and send a login response packet
      login_packet = ServerLoginPacket.new
      # Allocate an entity id for the player
      login_packet.entity_id = allocate_entity_id
      login_packet.username = username
      login_packet.level_type = "default"
      login_packet.game_mode = 0  # Survival
      login_packet.dimension = 0  # Overworld
      login_packet.difficulty = 0 # Peaceful
      login_packet.world_height = 128
      login_packet.max_players = 20

      # Adjust response behavior based on client protocol if required
      if protocol_version == 0
        puts "📤 Sending Beta 1.0-1.1 compatible login response to #{username}"
        # Keep any special compatibility tweaks here
      else
        puts "📤 Sending Beta 1.7.3 login response to #{username}"
      end

      @connection.send_packet(login_packet)
      puts "📤 Sent server login response to #{username}"
    end

    private def allocate_entity_id : Int32
      # Simple entity ID allocation
      # In a real server, you'd want to track used entity IDs
      Random.new.rand(1..1000000)
    end

    private def send_initial_world_data
      return unless @connection.logged_in?

      puts "🌍 Sending initial world data to #{@connection.username}"

      # Send spawn position
      send_spawn_position

      # Send initial player position
      send_initial_position

      # Send time update
      send_time_update

      # Send a welcome message
      @connection.send_chat_message("Welcome to CrystalMC Beta 1.7.3 Server!")
    end

    private def send_spawn_position
      # TODO: Implement proper spawn position packet (0x06)
      # For now, we'll use the default spawn position
      puts "📍 Setting spawn position for #{@connection.username}"
    end

    private def send_initial_position
      position_packet = PlayerPosPacket.new
      position_packet.x = 0.0
      position_packet.y = 64.0
      position_packet.z = 0.0
      position_packet.stance = 64.0
      position_packet.on_ground = true

      @connection.send_packet(position_packet)
      puts "📍 Sent initial position to #{@connection.username}"
    end

    private def send_time_update
      # TODO: Implement time update packet (0x04)
      # For Beta 1.7.3, we'd send the current world time
      puts "⏰ Sending time update to #{@connection.username}"
    end
  end
end
