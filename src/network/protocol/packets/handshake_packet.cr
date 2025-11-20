module CrystalMC::Network::Protocol
  class HandshakePacket < Packet
    property protocol_version : UInt8
    property username : String
    property server_host : String
    property server_port : Int32

    def initialize(@protocol_version : UInt8 = 0, @username : String = "", @server_host : String = "", @server_port : Int32 = 0)
    end

    def packet_id : UInt8
      0x02_u8
    end

    def read(io : IO)
      # Read protocol version (1 byte)
      @protocol_version = read_byte(io)
      puts "  → Read protocol version: #{@protocol_version}"

      # For Beta 1.7.3, we should get version 14
      # If we get 0, the client might be using a different protocol
      if @protocol_version == 0
        puts "  ⚠️  Client sent protocol version 0 - this might be a different Minecraft version"
        # Try to read the rest anyway in case the structure is similar
      end

      # Read username (string: short length + UTF-8 bytes)
      @username = read_string(io)
      puts "  → Read username: '#{@username}'"

      # Read server host (string: short length + UTF-8 bytes)
      @server_host = read_string(io)
      puts "  → Read server host: '#{@server_host}'"

      # Read server port (int: 4 bytes)
      @server_port = read_int(io)
      puts "  → Read server port: #{@server_port}"

      puts "✓ Handshake packet fully read: version=#{@protocol_version}, user='#{@username}', host='#{@server_host}', port=#{@server_port}"
    rescue ex : IO::EOFError
      puts "✗ Incomplete handshake packet (read so far: version=#{@protocol_version}, user='#{@username}', host='#{@server_host}')"
      # Store what we have and continue
    rescue ex : Exception
      puts "✗ Error reading handshake packet: #{ex.message}"
      puts ex.backtrace.join("\n") if ex.backtrace
      # Re-raise to let connection handle it
      raise ex
    end

    def write(io : IO)
      write_byte(io, @protocol_version)
      write_string(io, @username)
      write_string(io, @server_host)
      write_int(io, @server_port)
    end

    def handle(handler : NetHandler)
      handler.handle_handshake(self)
    end

    def clone : Packet
      HandshakePacket.new(@protocol_version, @username, @server_host, @server_port)
    end

    def complete? : Bool
      !@username.empty? && !@server_host.empty?
    end

    def valid_for_beta_1_7_3? : Bool
      @protocol_version == 14 && complete?
    end
  end
end
