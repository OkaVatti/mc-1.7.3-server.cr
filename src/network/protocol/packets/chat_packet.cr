module CrystalMC::Network::Protocol
  class ChatPacket < Packet
    property message : String

    def initialize(@message : String = "")
    end

    def packet_id : UInt8
      0x03_u8 # Chat message packet ID for Beta 1.7.3
    end

    def read(io : IO)
      @message = read_string(io)
    end

    def write(io : IO)
      write_string(io, @message)
    end

    def handle(handler : NetHandler)
      handler.handle_chat(self)
    end

    def clone : Packet
      ChatPacket.new(@message)
    end
  end
end
