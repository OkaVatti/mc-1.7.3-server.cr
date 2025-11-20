module CrystalMC::Network::Protocol
  abstract class Packet
    abstract def read(io : IO)
    abstract def write(io : IO)
    abstract def handle(handler : NetHandler)
    abstract def clone : Packet

    def packet_id : UInt8
      raise "packet_id not implemented for #{self.class}"
    end

    def write_with_id(io : IO)
      io.write_byte(packet_id)
      write(io)
    end

    protected def read_varint(io : IO) : Int32
      read_int(io) # Beta 1.7.3 doesn't use VarInt
    end

    protected def write_varint(io : IO, value : Int32)
      write_int(io, value) # Beta 1.7.3 doesn't use VarInt
    end

    protected def read_string(io : IO) : String
      length = read_short(io).to_i
      if length < 0
        raise "Invalid string length: #{length}"
      end

      if length == 0
        return ""
      end

      string_data = Bytes.new(length)
      bytes_read = io.read_fully?(string_data)

      if bytes_read != length
        # Partial read - return what we got
        String.new(string_data[0, bytes_read]) if bytes_read
        return ""
      end

      String.new(string_data)
    end

    protected def write_string(io : IO, value : String)
      data = value.to_slice
      write_short(io, data.size.to_i16)
      io.write(data)
    end

    protected def read_short(io : IO) : Int16
      io.read_bytes(Int16, IO::ByteFormat::BigEndian)
    end

    protected def write_short(io : IO, value : Int16)
      io.write_bytes(value, IO::ByteFormat::BigEndian)
    end

    protected def read_int(io : IO) : Int32
      io.read_bytes(Int32, IO::ByteFormat::BigEndian)
    end

    protected def write_int(io : IO, value : Int32)
      io.write_bytes(value, IO::ByteFormat::BigEndian)
    end

    protected def read_long(io : IO) : Int64
      io.read_bytes(Int64, IO::ByteFormat::BigEndian)
    end

    protected def write_long(io : IO, value : Int64)
      io.write_bytes(value, IO::ByteFormat::BigEndian)
    end

    protected def read_bool(io : IO) : Bool
      io.read_byte.not_nil! != 0
    end

    protected def write_bool(io : IO, value : Bool)
      io.write_byte(value ? 1_u8 : 0_u8)
    end

    protected def read_byte(io : IO) : UInt8
      byte = io.read_byte
      raise IO::EOFError.new if byte.nil?
      byte
    end

    protected def write_byte(io : IO, value : UInt8)
      io.write_byte(value)
    end

    protected def read_double(io : IO) : Float64
      io.read_bytes(Float64, IO::ByteFormat::BigEndian)
    end

    protected def write_double(io : IO, value : Float64)
      io.write_bytes(value, IO::ByteFormat::BigEndian)
    end

    protected def read_float(io : IO) : Float32
      io.read_bytes(Float32, IO::ByteFormat::BigEndian)
    end

    protected def write_float(io : IO, value : Float32)
      io.write_bytes(value, IO::ByteFormat::BigEndian)
    end

    def to_s(io : IO)
      io << "#{self.class.name}(id=0x#{packet_id.to_s(16).rjust(2, '0')})"
    end
  end
end
