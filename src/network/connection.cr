require "socket"
require "../crystal_mc/constants"

module CrystalMC::Network
  class Connection
    # Instance variables with explicit initialization
    @socket : TCPSocket
    @server : CrystalMC::Server
    @username : String
    @player : World::Player?
    @logged_in : Bool
    @state : Symbol
    @protocol_version : Int32
    @last_keep_alive : Time
    @compression_threshold : Int32
    @encryption_enabled : Bool

    # Use nilable types for handlers and lazy initialization
    @net_handler : Protocol::NetHandler?
    @packet_handler : PacketHandler?

    def initialize(socket : TCPSocket, server : CrystalMC::Server)
      @socket = socket
      @server = server
      @state = :handshake
      @protocol_version = 0
      @username = ""
      @logged_in = false
      @last_keep_alive = Time.utc
      @compression_threshold = -1
      @encryption_enabled = false
      @pending_chunks = [] of Tuple(Int32, Int32)
      @chunk_send_timer = Time.utc
    end

    def send_chunk_batch
      return if @pending_chunks.empty?

      # Send only 4 chunks per batch to avoid overwhelming the client
      chunks_to_send = @pending_chunks.shift(4)

      chunks_to_send.each do |chunk_x, chunk_z|
        send_single_chunk(chunk_x, chunk_z)
      end

      @chunk_send_timer = Time.utc
    end

    def send_initial_chunks(player_chunk_x : Int32, player_chunk_z : Int32, view_distance : Int32)
      chunk_coords = [] of Tuple(Int32, Int32)

      (-view_distance..view_distance).each do |dx|
        (-view_distance..view_distance).each do |dz|
          chunk_x = player_chunk_x + dx
          chunk_z = player_chunk_z + dz
          chunk_coords << {chunk_x, chunk_z}
        end
      end

      queue_chunks_for_sending(chunk_coords)
    end

    def send_single_chunk(chunk_x : Int32, chunk_z : Int32)
      # Send PreChunk packet first
      pre_chunk = Protocol::PreChunkPacket.new(chunk_x, chunk_z, true)
      send_packet(pre_chunk)

      # Generate and send the chunk
      chunk = @server.world.get_chunk(chunk_x, chunk_z)
      map_chunk = Protocol::MapChunkPacket.from_chunk(chunk)
      send_packet(map_chunk)
    end

    def queue_chunks_for_sending(chunk_coords : Array(Tuple(Int32, Int32)))
      @pending_chunks.concat(chunk_coords)
    end

    # Add this method to maintain compatibility with server code
    def setup_handlers
      # This method is now a no-op since handlers are lazy-initialized
      # But we keep it for API compatibility with the server code
      ensure_handlers_initialized
    end

    def queue_chunks_for_sending(chunk_coords : Array(Tuple(Int32, Int32)))
      @pending_chunks.concat(chunk_coords)
    end

    # Add this method to maintain compatibility with server code
    def setup_handlers
      # This method is now a no-op since handlers are lazy-initialized
      # But we keep it for API compatibility with the server code
      ensure_handlers_initialized
    end

    # Lazy initialization for handlers
    private def ensure_handlers_initialized
      if @net_handler.nil?
        @net_handler = Protocol::NetHandler.new(self)
        @packet_handler = PacketHandler.new(self)
      end
    end

    # Accessors that ensure handlers are initialized
    def net_handler : Protocol::NetHandler
      ensure_handlers_initialized
      @net_handler.not_nil!
    end

    def packet_handler : PacketHandler
      ensure_handlers_initialized
      @packet_handler.not_nil!
    end

    # Manual getters and setters for other properties
    def socket : TCPSocket
      @socket
    end

    def server : CrystalMC::Server
      @server
    end

    def username : String
      @username
    end

    def username=(value : String)
      @username = value
    end

    def player : World::Player?
      @player
    end

    def player=(value : World::Player?)
      @player = value
    end

    def logged_in : Bool
      @logged_in
    end

    def logged_in=(value : Bool)
      @logged_in = value
    end

    def state : Symbol
      @state
    end

    def state=(value : Symbol)
      @state = value
    end

    def protocol_version : Int32
      @protocol_version
    end

    def protocol_version=(value : Int32)
      @protocol_version = value
    end

    def last_keep_alive : Time
      @last_keep_alive
    end

    def last_keep_alive=(value : Time)
      @last_keep_alive = value
    end

    def compression_threshold : Int32
      @compression_threshold
    end

    def compression_threshold=(value : Int32)
      @compression_threshold = value
    end

    def encryption_enabled : Bool
      @encryption_enabled
    end

    def encryption_enabled=(value : Bool)
      @encryption_enabled = value
    end

    def handle
      puts "Starting packet handling loop for #{@username || "unknown"} from #{@socket.remote_address}"

      # Ensure handlers are initialized before starting the loop
      ensure_handlers_initialized

      while !@socket.closed?
        begin
          # Read packet ID
          packet_id = read_byte
          puts "📦 Received packet ID: 0x#{packet_id.to_s(16).upcase.rjust(2, '0')}"

          # Read and handle packet
          packet = Protocol::Packets.read_packet(packet_id, @socket)

          if packet
            puts "🔄 Handling packet: 0x#{packet_id.to_s(16).upcase.rjust(2, '0')} - #{packet.class}"

            # Special logging for handshake packets
            if packet.is_a?(Protocol::HandshakePacket)
              handshake = packet.as(Protocol::HandshakePacket)
              puts "  🤝 Handshake details: version=#{handshake.protocol_version}, user='#{handshake.username}', host='#{handshake.server_host}'"
            end

            packet.handle(net_handler)
          else
            puts "❓ Unknown packet ID: 0x#{packet_id.to_s(16).upcase.rjust(2, '0')}"
            puts "  ⚠️  Unknown packet, but continuing to next packet..."
          end
        rescue ex : IO::EOFError
          puts "🔌 Client disconnected: #{@username || "unknown"}"
          break
        rescue ex : IO::Error
          puts "💥 IO Error handling packet: #{ex.message}"
          break
        rescue ex
          puts "💥 Error handling packet: #{ex.message}"
          puts "  ⚠️  Continuing to next packet despite error..."
        end
      end
    ensure
      disconnect("Connection closed")
    end

    def send_packet(packet : Protocol::Packet)
      puts "📤 Sending packet: #{packet.class} (ID: 0x#{packet.packet_id.to_s(16)})"
      return if @socket.closed?

      begin
        packet.write_with_id(@socket)
        @socket.flush
      rescue ex : IO::Error
        puts "Error sending packet: #{ex.message}"
        disconnect("Send error: #{ex.message}")
      rescue ex
        puts "Unexpected error sending packet: #{ex.message}"
        disconnect("Send error")
      end
    end

    def send_kick(reason : String)
      kick_packet = Protocol::KickDisconnectPacket.new(reason)
      send_packet(kick_packet)
      disconnect(reason)
    end

    def send_chat_message(message : String)
      chat_packet = Protocol::ChatPacket.new(message)
      send_packet(chat_packet)
    end

    def send_keep_alive
      return unless @logged_in

      keep_alive = Protocol::KeepAlivePacket.new
      keep_alive.keep_alive_id = (Time.utc.to_unix % 1000).to_i32
      send_packet(keep_alive)
      @last_keep_alive = Time.utc
      puts "Sent keep-alive to #{@username}"
    end

    def disconnect(reason : String)
      return if @socket.closed?

      puts "Disconnecting #{@username || "unknown"}: #{reason}"

      if username = @username
        @server.remove_player(username)
      end

      @logged_in = false
      @socket.close rescue nil
    end

    def tick
      if !@pending_chunks.empty? && (Time.utc - @chunk_send_timer).total_milliseconds > 50
        send_chunk_batch
      end
      if @logged_in && (Time.utc - @last_keep_alive).total_seconds > TIMEOUT_SECONDS
        disconnect("Timed out")
      end
    end

    def logged_in? : Bool
      @logged_in
    end

    private def read_byte : UInt8
      byte = @socket.read_byte
      raise IO::EOFError.new if byte.nil?
      byte
    end

    # Lazy initialization for handlers
    private def ensure_handlers_initialized
      if @net_handler.nil?
        @net_handler = Protocol::NetHandler.new(self)
        @packet_handler = PacketHandler.new(self)
      end
    end
  end
end

# Load dependent files after Connection class is defined
require "./protocol/packets/packet"
require "./protocol/packets/keep_alive_packet"
require "./protocol/packets/handshake_packet"
require "./protocol/packets/client_login_packet"
require "./protocol/packets/server_login_packet"
require "./protocol/packets/chat_packet"
require "./protocol/packets/player_pos_packet"
require "./protocol/packets/player_look_packet"
require "./protocol/packets/player_look_move_packet"
require "./protocol/packets/block_dig_packet"
require "./protocol/packets/block_place_packet"
require "./protocol/packets/pre_chunk_packet"
require "./protocol/packets/map_chunk_packet"
require "./protocol/packets/kick_disconnect_packet"
require "./protocol/packets/packets"
require "./protocol/protocol_versions"
require "./protocol/net_handler"
require "./packet_handler"
