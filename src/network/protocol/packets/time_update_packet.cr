module CrystalMC::Network::Protocol
  class TimeUpdatePacket < Packet
    property time : Int64

    def initialize(@time : Int64 = 0)
    end

    def packet_id : UInt8
      0x04_u8
    end

    def read(io : IO)
      @time = read_long(io)
    end

    def write(io : IO)
      write_long(io, @time)
    end

    def handle(handler : NetHandler)
      # Client handles this packet, not server
      # But we implement it for completeness
    end

    def clone : Packet
      TimeUpdatePacket.new(@time)
    end
  end
end
