module CrystalMC::Network::Protocol
  class BlockChangePacket < Packet
    property x : Int32
    property y : Int8
    property z : Int32
    property block_type : UInt8
    property block_metadata : UInt8

    def initialize(@x : Int32 = 0, @y : Int8 = 0, @z : Int32 = 0, @block_type : UInt8 = 0, @block_metadata : UInt8 = 0)
    end

    def packet_id : UInt8
      0x35_u8
    end

    def read(io : IO)
      @x = read_int(io)
      @y = read_byte(io).to_i8
      @z = read_int(io)
      @block_type = read_byte(io)
      @block_metadata = read_byte(io)
    end

    def write(io : IO)
      write_int(io, @x)
      write_byte(io, @y.to_u8)
      write_int(io, @z)
      write_byte(io, @block_type)
      write_byte(io, @block_metadata)
    end

    def handle(handler : NetHandler)
      # Client handles this, not server
    end

    def clone : Packet
      BlockChangePacket.new(@x, @y, @z, @block_type, @block_metadata)
    end
  end
end
