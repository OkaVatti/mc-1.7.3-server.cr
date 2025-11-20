module CrystalMC::Network::Protocol
  module ProtocolHelper
    PROTOCOL_VERSION = 14_u8 # Beta 1.7.3

    # Read a Minecraft string (UTF-16BE with length prefix)
    def self.read_string(io : IO) : String
      length = read_short(io)
      bytes = Bytes.new(length * 2)
      io.read_fully(bytes)

      # Convert UTF-16BE to UTF-8
      String.new(bytes, "UTF-16BE")
    end

    # Write a Minecraft string
    def self.write_string(io : IO, str : String)
      utf16 = str.encode("UTF-16BE")
      length = utf16.size // 2
      write_short(io, length.to_i16)
      io.write(utf16)
    end

    # Read signed byte
    def self.read_byte(io : IO) : Int8
      byte = io.read_byte
      raise IO::EOFError.new if byte.nil?
      byte.to_i8!
    end

    # Write signed byte
    def self.write_byte(io : IO, value : Int8)
      io.write_byte(value.to_u8!)
    end

    # Read unsigned byte
    def self.read_ubyte(io : IO) : UInt8
      byte = io.read_byte
      raise IO::EOFError.new if byte.nil?
      byte
    end

    # Write unsigned byte
    def self.write_ubyte(io : IO, value : UInt8)
      io.write_byte(value)
    end

    # Read short (16-bit big-endian)
    def self.read_short(io : IO) : Int16
      bytes = Bytes.new(2)
      io.read_fully(bytes)
      IO::ByteFormat::BigEndian.decode(Int16, bytes)
    end

    # Write short
    def self.write_short(io : IO, value : Int16)
      bytes = Bytes.new(2)
      IO::ByteFormat::BigEndian.encode(value, bytes)
      io.write(bytes)
    end

    # Read int (32-bit big-endian)
    def self.read_int(io : IO) : Int32
      bytes = Bytes.new(4)
      io.read_fully(bytes)
      IO::ByteFormat::BigEndian.decode(Int32, bytes)
    end

    # Write int
    def self.write_int(io : IO, value : Int32)
      bytes = Bytes.new(4)
      IO::ByteFormat::BigEndian.encode(value, bytes)
      io.write(bytes)
    end

    # Read long (64-bit big-endian)
    def self.read_long(io : IO) : Int64
      bytes = Bytes.new(8)
      io.read_fully(bytes)
      IO::ByteFormat::BigEndian.decode(Int64, bytes)
    end

    # Write long
    def self.write_long(io : IO, value : Int64)
      bytes = Bytes.new(8)
      IO::ByteFormat::BigEndian.encode(value, bytes)
      io.write(bytes)
    end

    # Read float (32-bit big-endian)
    def self.read_float(io : IO) : Float32
      bytes = Bytes.new(4)
      io.read_fully(bytes)
      IO::ByteFormat::BigEndian.decode(Float32, bytes)
    end

    # Write float
    def self.write_float(io : IO, value : Float32)
      bytes = Bytes.new(4)
      IO::ByteFormat::BigEndian.encode(value, bytes)
      io.write(bytes)
    end

    # Read double (64-bit big-endian)
    def self.read_double(io : IO) : Float64
      bytes = Bytes.new(8)
      io.read_fully(bytes)
      IO::ByteFormat::BigEndian.decode(Float64, bytes)
    end

    # Write double
    def self.write_double(io : IO, value : Float64)
      bytes = Bytes.new(8)
      IO::ByteFormat::BigEndian.encode(value, bytes)
      io.write(bytes)
    end

    # Read boolean
    def self.read_bool(io : IO) : Bool
      read_ubyte(io) != 0
    end

    # Write boolean
    def self.write_bool(io : IO, value : Bool)
      write_ubyte(io, value ? 1_u8 : 0_u8)
    end
  end
end
