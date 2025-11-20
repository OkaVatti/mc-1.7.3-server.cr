require "../../io_helpers"

module CrystalMC::Network::Protocol
  class HandshakePacket < Packet
    include CrystalMC::Network::IOHelpers

    property protocol_version : Int32
    property username : String
    property server_host : String
    property server_port : Int32

    def initialize(@protocol_version : Int32 = 0, @username : String = "", @server_host : String = "", @server_port : Int32 = 0)
    end

    def packet_id : UInt8
      0x02_u8
    end

    def is_beta_1_7_3_legacy? : Bool
      # Beta 1.7.3 clients often send legacy handshakes
      @protocol_version == 0 && !@username.empty? && @server_host == "localhost" && @server_port == 25565
    end

    # Override the old method to also include Beta 1.7.3 legacy detection
    def is_beta_1_0_1_1? : Bool
      false # Always return false since we want to handle these as Beta 1.7.3
    end

    # Convert a Bytes buffer containing UTF-16BE code units into a Crystal String
    private def utf16be_bytes_to_string(bytes : Bytes) : String
      return "" if bytes.empty?

      # Compute number of UTF-16 code units
      length = (bytes.size + 1) // 2
      arr = Array(UInt16).new(length)

      i = 0
      while i + 1 < bytes.size
        hi = bytes[i].to_u32
        lo = bytes[i + 1].to_u32
        arr << ((hi << 8) | lo).to_u16
        i += 2
      end

      # Handle leftover single byte (pad with 0)
      if i < bytes.size
        arr << (bytes[i].to_u32 << 8).to_u16
      end

      # Fix: String.from_utf16 expects only one argument - a Slice(UInt16)
      String.from_utf16(Slice(UInt16).new(arr.to_unsafe, arr.size))
    rescue ex
      puts "  ⚠️  Error converting UTF-16BE bytes: #{ex.message}"
      # Fallback: try to interpret as ASCII/latin1
      String.new(bytes)
    end

    def read(io : IO)
      # Read first 4 bytes so we can inspect without committing to one interpretation
      head = read_exact(io, 4)

      # Interpret head as a big-endian Int32
      maybe_protocol = ((head[0].to_i32 << 24) | (head[1].to_i32 << 16) | (head[2].to_i32 << 8) | head[3].to_i32)

      # If it's exactly 14, treat as normal Beta 1.7.3 format
      if maybe_protocol == 14
        @protocol_version = maybe_protocol

        @username = read_string(io)
        puts "  → Read username: '#{@username}'"

        @server_host = read_string(io)
        puts "  → Read server host: '#{@server_host}'"

        @server_port = read_int(io)
        puts "  → Read server port: #{@server_port}"

        puts "✓ Handshake packet fully read: version=#{@protocol_version}, user='#{@username}', host='#{@server_host}', port=#{@server_port}"
        return
      end

      # Legacy writeChars-style: head[0..1] = u16 name length, head[2..3] = first character bytes
      if head[0] == 0x00_u8
        name_len = (head[0].to_u32 << 8) | head[1].to_u32
        puts "  → Detected legacy handshake with username length: #{name_len}"

        bytes_needed = (name_len * 2) - 2

        remaining_bytes = if bytes_needed > 0
                            read_exact(io, bytes_needed)
                          else
                            Bytes.new(0)
                          end

        # Build username bytes: first two from head[2..3], then remaining_bytes
        # Build username bytes: first two from head[2..3], then remaining_bytes
        total_bytes = 2 + remaining_bytes.size
        username_bytes = Bytes.new(total_bytes)
        username_bytes[0] = head[2]
        username_bytes[1] = head[3]

        # Fix: Use the correct copy_to overload that takes a Slice
        if remaining_bytes.size > 0
          remaining_bytes.copy_to(username_bytes[2, remaining_bytes.size])
        end

        @username = utf16be_bytes_to_string(username_bytes)
        @protocol_version = 0
        @server_host = "localhost"
        @server_port = 25565

        puts "  ⚠️  Detected legacy writeChars-style handshake"
        puts "  → Read username (UTF-16BE): '#{@username}'"
        return
      end

      # Fallback: treat head as protocol int (even if odd)
      @protocol_version = maybe_protocol
      puts "  → Read protocol version: #{@protocol_version}"

      begin
        @username = read_string(io)
        puts "  → Read username: '#{@username}'"

        @server_host = read_string(io)
        puts "  → Read server host: '#{@server_host}'"

        @server_port = read_int(io)
        puts "  → Read server port: #{@server_port}"

        puts "✓ Handshake packet parsed (fallback): version=#{@protocol_version}, user='#{@username}', host='#{@server_host}', port=#{@server_port}"
      rescue ex : IO::EOFError
        puts "✗ Incomplete handshake packet (read so far: version=#{@protocol_version}, user='#{@username}', host='#{@server_host}')"
      rescue ex : Exception
        puts "✗ Error reading handshake packet: #{ex.message}"
      end
    end

    def write(io : IO)
      write_i32_be(io, @protocol_version)
      write_string(io, @username)
      write_string(io, @server_host)
      write_i32_be(io, @server_port)
    end

    def handle(handler : NetHandler)
      handler.handle_handshake(self)
    end

    def clone : Packet
      HandshakePacket.new(@protocol_version, @username, @server_host, @server_port)
    end

    def complete? : Bool
      if @protocol_version == 0
        !@username.empty?
      else
        !@username.empty? && !@server_host.empty?
      end
    end

    def valid_for_beta_1_7_3? : Bool
      @protocol_version == 14 && complete?
    end

    def is_beta_1_0_1_1? : Bool
      @protocol_version == 0 && !@username.empty?
    end
  end
end
