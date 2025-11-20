# src/network/protocol/packets/keep_alive_packet.cr
module CrystalMC::Network::Protocol
  class KeepAlivePacket < Packet
    property keep_alive_id : Int32

    def initialize(@keep_alive_id : Int32 = 0)
    end

    def packet_id : UInt8
      0x00_u8
    end

    def read(io : IO)
      @keep_alive_id = ProtocolHelper.read_int(io)
    end

    def write(io : IO)
      ProtocolHelper.write_int(io, @keep_alive_id)
    end

    def handle(handler : NetHandler)
      handler.handle_keep_alive(self)
    end

    def clone : Packet
      KeepAlivePacket.new(@keep_alive_id)
    end
  end
end
