# src/network/protocol/packets/block_place_packet.cr
require "./packet"
require "./protocol_helper"

module CrystalMC::Network::Protocol
  class BlockPlacePacket < Packet
    property x : Int32
    property y : Int8
    property z : Int32
    property direction : Int8
    property item_id : Int16
    property amount : Int8?
    property damage : Int16?

    def initialize(
      @x : Int32 = 0,
      @y : Int8 = 0_i8,
      @z : Int32 = 0,
      @direction : Int8 = 0_i8,
      @item_id : Int16 = -1_i16,
      @amount : Int8? = nil,
      @damage : Int16? = nil
    )
    end

    def packet_id : UInt8
      0x0F_u8
    end

    def read(io : IO)
      @x = ProtocolHelper.read_int(io)
      @y = ProtocolHelper.read_byte(io)
      @z = ProtocolHelper.read_int(io)
      @direction = ProtocolHelper.read_byte(io)
      @item_id = ProtocolHelper.read_short(io)

      if @item_id != -1
        @amount = ProtocolHelper.read_byte(io)
        @damage = ProtocolHelper.read_short(io)
      end
    end

    def write(io : IO)
      ProtocolHelper.write_int(io, @x)
      ProtocolHelper.write_byte(io, @y)
      ProtocolHelper.write_int(io, @z)
      ProtocolHelper.write_byte(io, @direction)
      ProtocolHelper.write_short(io, @item_id)

      if @item_id != -1 && (amt = @amount) && (dmg = @damage)
        ProtocolHelper.write_byte(io, amt)
        ProtocolHelper.write_short(io, dmg)
      end
    end

    def handle(handler : NetHandler)
      handler.handle_block_place(self)
    end

    def clone : Packet
      BlockPlacePacket.new(@x, @y, @z, @direction, @item_id, @amount, @damage)
    end
  end
end
