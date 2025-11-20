require "./packet"

module CrystalMC::Network::Protocol
  class PreChunkPacket < Packet
    property x : Int32
    property z : Int32
    property mode : Bool # true = load, false = unload

    def initialize(@x : Int32 = 0, @z : Int32 = 0, @mode : Bool = true)
    end

    def packet_id : UInt8
      0x32_u8
    end

    def read(io : IO)
      @x = read_int(io)
      @z = read_int(io)
      @mode = read_bool(io)
    end

    def write(io : IO)
      write_int(io, @x)
      write_int(io, @z)
      write_bool(io, @mode)
    end

    def handle(handler : NetHandler)
      handler.handle_pre_chunk(self)
    end

    def clone : Packet
      PreChunkPacket.new(@x, @z, @mode)
    end
  end
end
