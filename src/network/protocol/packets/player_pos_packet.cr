module CrystalMC::Network::Protocol
  class PlayerPosPacket < Packet # Changed from PlayerPositionPacket
    property x : Float64
    property y : Float64
    property stance : Float64
    property z : Float64
    property on_ground : Bool

    def initialize(@x : Float64 = 0.0, @y : Float64 = 0.0, @stance : Float64 = 0.0, @z : Float64 = 0.0, @on_ground : Bool = true)
    end

    def packet_id : UInt8
      0x0B_u8
    end

    def read(io : IO)
      @x = read_double(io)
      @y = read_double(io)
      @stance = read_double(io)
      @z = read_double(io)
      @on_ground = read_bool(io)
    end

    def write(io : IO)
      write_double(io, @x)
      write_double(io, @y)
      write_double(io, @stance)
      write_double(io, @z)
      write_bool(io, @on_ground)
    end

    def handle(handler : NetHandler)
      handler.handle_player_position(self)
    end

    def clone : Packet
      PlayerPosPacket.new(@x, @y, @stance, @z, @on_ground)
    end

    private def read_double(io : IO) : Float64
      io.read_bytes(Float64, IO::ByteFormat::BigEndian)
    end

    private def write_double(io : IO, value : Float64)
      io.write_bytes(value, IO::ByteFormat::BigEndian)
    end
  end
end
