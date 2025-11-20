module CrystalMC::Network
  class PacketHandler
    property connection : Connection

    def initialize(@connection : Connection)
    end

    def handle_handshake(packet : Protocol::HandshakePacket)
      # Respond with handshake
      response = Protocol::HandshakePacket.new("-") # "-" means no authentication
      @connection.send_packet(response)
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

      # Store username and mark as logged in
      @connection.username = username
      @connection.logged_in = true

      puts "Player #{username} logged in"

      # Send login response
      response = Protocol::LoginPacket.new(
        entity_id: 1, # TODO: Generate proper entity ID
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

      # Send chunks around spawn
      send_spawn_chunks(spawn_x, spawn_z)

      # Send player position
      send_player_spawn(spawn_x.to_f64 + 0.5, spawn_y.to_f64, spawn_z.to_f64 + 0.5)

      # Broadcast join message
      @connection.server.broadcast("§e#{username} joined the game")
    end

    def handle_chat(packet : Protocol::ChatPacket)
      username = @connection.username
      return unless username

      message = packet.message

      # Check for commands
      if message.starts_with?("/")
        handle_command(message[1..])
      else
        # Broadcast chat message
        formatted = "<#{username}> #{message}"
        @connection.server.broadcast(formatted)
        puts formatted
      end
    end

    def handle_keep_alive(packet : Protocol::KeepAlivePacket)
      @connection.last_keep_alive = Time.monotonic
    end

    def handle_player_position(packet : Protocol::PlayerPositionPacket)
      # TODO: Update player position in world
      # puts "#{@connection.username} moved to #{packet.x}, #{packet.y}, #{packet.z}"
    end

    def handle_player_look(packet : Protocol::PlayerLookPacket)
      # TODO: Update player rotation
    end

    def handle_player_look_move(packet : Protocol::PlayerLookMovePacket)
      # TODO: Update player position and rotation
    end

    def handle_block_dig(packet : Protocol::BlockDigPacket)
      # TODO: Handle block breaking
      puts "#{@connection.username} digging block at #{packet.x}, #{packet.y}, #{packet.z}"
    end

    def handle_block_place(packet : Protocol::BlockPlacePacket)
      # TODO: Handle block placement
      puts "#{@connection.username} placing block at #{packet.x}, #{packet.y}, #{packet.z}"
    end

    private def send_spawn_position(x : Int32, y : Int32, z : Int32)
      io = IO::Memory.new
      Protocol::ProtocolHelper.write_ubyte(io, 0x06_u8) # Spawn position packet
      Protocol::ProtocolHelper.write_int(io, x)
      Protocol::ProtocolHelper.write_int(io, y)
      Protocol::ProtocolHelper.write_int(io, z)

      @connection.socket.write(io.to_slice)
      @connection.socket.flush
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

    private def handle_command(command : String)
      parts = command.split(' ')
      cmd = parts[0]
      args = parts[1..]

      case cmd
      when "help"
        @connection.send_chat_message("§eAvailable commands: /help, /list, /stop, /tp")
      when "list"
        player_list = @connection.server.@connections
          .select(&.logged_in?)
          .map(&.username)
          .join(", ")
        @connection.send_chat_message("§ePlayers online: #{player_list}")
      when "stop"
        @connection.send_chat_message("§cStopping server...")
        spawn { @connection.server.stop }
      when "tp"
        if args.size >= 3
          begin
            x = args[0].to_f64
            y = args[1].to_f64
            z = args[2].to_f64
            send_player_spawn(x, y, z)
            @connection.send_chat_message("§aTeleported to #{x}, #{y}, #{z}")
          rescue
            @connection.send_chat_message("§cInvalid coordinates")
          end
        else
          @connection.send_chat_message("§cUsage: /tp <x> <y> <z>")
        end
      else
        @connection.send_chat_message("§cUnknown command: #{cmd}")
      end
    end
  end
end
