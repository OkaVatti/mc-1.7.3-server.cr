# src/network/protocol/packets/pre_chunk_packet.cr
module CrystalMC::Network::Protocol
  class PreChunkPacket < Packet
    property x : Int32
    property z : Int32
    property mode : Bool

    def initialize(@x : Int32 = 0, @z : Int32 = 0, @mode : Bool = false)
    end

    def packet_id : UInt8
      0x32_u8
    end

    def read(io : IO)
      @x = ProtocolHelper.read_int(io)
      @z = ProtocolHelper.read_int(io)
      @mode = ProtocolHelper.read_bool(io)
    end

    def write(io : IO)
      ProtocolHelper.write_int(io, @x)
      ProtocolHelper.write_int(io, @z)
      ProtocolHelper.write_bool(io, @mode)
    end

    def handle(handler : NetHandler)
      # Client doesn't send this packet
    end

    def clone : Packet
      PreChunkPacket.new(@x, @z, @mode)
    end
  end
end