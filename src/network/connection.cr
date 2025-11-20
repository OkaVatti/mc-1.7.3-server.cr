require "socket"
require "../crystal_mc/constants"

module CrystalMC::Network
  # Forward declarations
  class PacketHandler; end

  module Protocol
    class NetHandler; end

    abstract class Packet; end
  end

  class Connection
    property socket : TCPSocket
    property server : Server
    property username : String?
    property logged_in : Bool
    property last_keep_alive : Time

    # Use nilable types for handlers since they depend on types not fully defined yet
    getter net_handler : Protocol::NetHandler?
    getter packet_handler : PacketHandler?

    def initialize(@socket : TCPSocket, @server : Server)
      @username = nil
      @logged_in = false
      @last_keep_alive = Time.utc

      # Initialize handlers - these will be set after the requires
      @net_handler = nil
      @packet_handler = nil
    end

    # Add a setter for username
    def username=(value : String)
      @username = value
    end

    # Method to initialize handlers after all types are available
    def setup_handlers
      @net_handler = Protocol::NetHandler.new(self)
      @packet_handler = PacketHandler.new(self)
    end

    def handle
      # Check if handlers are initialized and get a non-nil reference
      net_handler = @net_handler
      if net_handler.nil?
        disconnect("Handlers not initialized")
        return
      end

      puts "Starting packet handling loop for #{@username || "unknown"} from #{@socket.remote_address}"

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
          end
        rescue ex : IO::EOFError
          puts "🔌 Client disconnected: #{@username || "unknown"}"
          break
        rescue ex : IO::Error
          puts "💥 IO Error handling packet: #{ex.message}"
          break
        rescue ex
          puts "💥 Error handling packet: #{ex.message}"
          puts ex.backtrace.join("\n") if ex.backtrace
        end
      end
    ensure
      disconnect("Connection closed")
    end

    def send_packet(packet : Protocol::Packet)
      return if @socket.closed?

      begin
        packet.write_with_id(@socket)
        @socket.flush
      rescue ex
        puts "Error sending packet: #{ex.message}"
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
      # Only send keep-alive to logged-in connections
      return unless @logged_in

      keep_alive = Protocol::KeepAlivePacket.new
      # Use a simple counter for keep-alive ID
      keep_alive.keep_alive_id = (Time.utc.to_unix % 1000).to_i32
      send_packet(keep_alive)
      @last_keep_alive = Time.utc
      puts "Sent keep-alive to #{@username}"
    end

    def disconnect(reason : String)
      return if @socket.closed?

      puts "Disconnecting #{@username || "unknown"}: #{reason}"
      @logged_in = false
      @socket.close rescue nil
    end

    def tick
      # Only check timeout for logged-in connections
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
  end
end

# Load protocol implementations after Connection class is defined
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
require "./protocol/protocol_versions" # Add this line
require "./protocol/net_handler"
require "./packet_handler"
