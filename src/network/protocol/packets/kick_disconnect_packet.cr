module CrystalMC::Network::Protocol
  class KickDisconnectPacket < Packet
    property reason : String

    def initialize(reason : String = "Disconnected")
      @reason = reason
    end

    def packet_id : UInt8
      0xFF_u8 # Kick/disconnect packet ID for Beta 1.7.3
    end

    def read(io : IO)
      @reason = read_string(io)
    end

    def write(io : IO)
      write_string(io, @reason)
    end

    def handle(handler : NetHandler)
      handler.handle_kick_disconnect(self)
    end

    def clone : Packet
      KickDisconnectPacket.new(@reason)
    end
  end
end
