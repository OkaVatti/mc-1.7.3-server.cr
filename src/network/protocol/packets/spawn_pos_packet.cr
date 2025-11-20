module CrystalMC::Network::Protocol
  class SpawnPositionPacket < Packet
    property x : Int32
    property y : Int32
    property z : Int32

    def initialize(@x : Int32 = 0, @y : Int32 = 0, @z : Int32 = 0)
    end

    def packet_id : UInt8
      0x06_u8
    end

    def read(io : IO)
      @x = read_int(io)
      @y = read_int(io)
      @z = read_int(io)
    end

    def write(io : IO)
      write_int(io, @x)
      write_int(io, @y)
      write_int(io, @z)
    end

    def handle(handler : NetHandler)
      # Client handles this, not server
    end

    def clone : Packet
      SpawnPositionPacket.new(@x, @y, @z)
    end
  end
end
