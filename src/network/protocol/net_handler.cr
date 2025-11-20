require "./protocol_versions" # Add this require

module CrystalMC::Network::Protocol
  class NetHandler
    def initialize(@connection : Connection)
    end

    def handle_handshake(packet : HandshakePacket)
      version_name = Protocol.get_version_name(packet.protocol_version)
      puts "🤝 Handshake received: #{version_name}, user='#{packet.username}', host='#{packet.server_host}', port=#{packet.server_port}"

      # Check if this is a valid Beta 1.7.3 handshake
      if packet.valid_for_beta_1_7_3?
        handle_valid_beta_1_7_3_handshake(packet)
      else
        handle_invalid_handshake(packet, version_name)
      end
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

      # Send login response
      send_login_response(packet.username)
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

    private def send_login_response(username : String)
      # Create and send a login response packet
      login_packet = ServerLoginPacket.new
      login_packet.entity_id = allocate_entity_id
      login_packet.username = username
      login_packet.level_type = "default"
      login_packet.game_mode = 0  # Survival
      login_packet.dimension = 0  # Overworld
      login_packet.difficulty = 0 # Peaceful
      login_packet.world_height = 128
      login_packet.max_players = 20

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
