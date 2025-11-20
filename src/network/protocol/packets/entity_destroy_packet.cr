# src/network/protocol/packets/entity_destroy_packet.cr
module CrystalMC::Network::Protocol
  class EntityDestroyPacket < Packet
    property entity_id : Int32

    def initialize(@entity_id : Int32 = 0)
    end

    def packet_id : UInt8
      0x1D_u8
    end

    def read(io : IO)
      @entity_id = read_int(io)
    end

    def write(io : IO)
      write_int(io, @entity_id)
    end

    def handle(handler : NetHandler)
      # Client handles this
    end

    def clone : Packet
      EntityDestroyPacket.new(@entity_id)
    end
  end
end