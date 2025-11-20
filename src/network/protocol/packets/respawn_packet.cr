module CrystalMC::Network::Protocol
  class RespawnPacket < Packet
    property dimension : Int32

    def initialize(@dimension : Int32 = 0)
    end

    def packet_id : UInt8
      0x09_u8
    end

    def read(io : IO)
      @dimension = read_int(io)
    end

    def write(io : IO)
      write_int(io, @dimension)
    end

    def handle(handler : NetHandler)
      # Handle respawn
    end

    def clone : Packet
      RespawnPacket.new(@dimension)
    end
  end
end
