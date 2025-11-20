module CrystalMC::Network::Protocol
  class HealthUpdatePacket < Packet
    property health : Int16

    def initialize(@health : Int16 = 20)
    end

    def packet_id : UInt8
      0x08_u8
    end

    def read(io : IO)
      @health = read_short(io)
    end

    def write(io : IO)
      write_short(io, @health)
    end

    def handle(handler : NetHandler)
      # Client handles this, not server
    end

    def clone : Packet
      HealthUpdatePacket.new(@health)
    end
  end
end
