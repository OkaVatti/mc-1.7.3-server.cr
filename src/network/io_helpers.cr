# src/network/io_helpers.cr
module CrystalMC
  module Network
    module IOHelpers
      # Read exactly n bytes into a Bytes buffer and return that buffer.
      # Raises IO::EOFError if fewer than n bytes are available.
      def read_exact(io : IO, n : Int) : Bytes
        buffer = Bytes.new(n)
        # IO#read accepts a Bytes and returns the number of bytes read or nil on EOF
        read_count = io.read(buffer) || 0

        if read_count < n
          raise IO::EOFError.new("Expected #{n} bytes, got #{read_count}")
        end

        buffer
      end

      # Unsigned 8-bit (read 1 byte)
      def read_u8(io : IO) : UInt8
        buf = read_exact(io, 1)
        buf[0]
      end

      # Unsigned 16-bit big-endian
      def read_u16_be(io : IO) : UInt16
        a = read_u8(io).to_u32
        b = read_u8(io).to_u32
        ((a << 8) | b).to_u16
      end

      # Signed/unsigned 32-bit big-endian
      def read_i32_be(io : IO) : Int32
        a = read_u8(io).to_i32
        b = read_u8(io).to_i32
        c = read_u8(io).to_i32
        d = read_u8(io).to_i32
        (a << 24) | (b << 16) | (c << 8) | d
      end

      # Compatibility alias used elsewhere in your codebase
      def read_int(io : IO) : Int32
        read_i32_be(io)
      end

      # Read a u16-prefixed UTF-8 string (legacy / beta style)
      def read_string(io : IO) : String
        length = read_u16_be(io).to_i
        bytes = read_exact(io, length)
        # Convert raw bytes to a Crystal String (assume valid UTF-8 coming from client)
        String.new(bytes)
      end

      # ----------------------
      # Write helpers (big-endian)
      # ----------------------
      def write_i32_be(io : IO, value : Int32)
        # Fixed: Use proper Bytes initialization
        buf = Bytes.new(4)
        buf[0] = ((value >> 24) & 0xFF).to_u8
        buf[1] = ((value >> 16) & 0xFF).to_u8
        buf[2] = ((value >> 8) & 0xFF).to_u8
        buf[3] = (value & 0xFF).to_u8
        io.write(buf)
      end

      def write_u16_be(io : IO, value : UInt16)
        # Fixed: Use proper Bytes initialization
        buf = Bytes.new(2)
        buf[0] = ((value >> 8) & 0xFF).to_u8
        buf[1] = (value & 0xFF).to_u8
        io.write(buf)
      end

      def write_string(io : IO, s : String)
        write_u16_be(io, s.bytesize.to_u16)
        # Write raw bytes of the string
        io.write(s.to_slice)
      end
    end
  end
end
