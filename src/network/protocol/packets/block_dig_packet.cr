# src/network/protocol/packets/block_dig_packet.cr
require "./packet"
require "./protocol_helper"

module CrystalMC::Network::Protocol
  class BlockDigPacket < Packet
    property status : Int8
    property x : Int32
    property y : Int8
    property z : Int32
    property face : Int8

    def initialize(
      @status : Int8 = 0_i8,
      @x : Int32 = 0,
      @y : Int8 = 0_i8,
      @z : Int32 = 0,
      @face : Int8 = 0_i8
    )
    end

    def packet_id : UInt8
      0x0E_u8
    end

    def read(io : IO)
      @status = ProtocolHelper.read_byte(io)
      @x = ProtocolHelper.read_int(io)
      @y = ProtocolHelper.read_byte(io)
      @z = ProtocolHelper.read_int(io)
      @face = ProtocolHelper.read_byte(io)
    end

    def write(io : IO)
      ProtocolHelper.write_byte(io, @status)
      ProtocolHelper.write_int(io, @x)
      ProtocolHelper.write_byte(io, @y)
      ProtocolHelper.write_int(io, @z)
      ProtocolHelper.write_byte(io, @face)
    end

    def handle(handler : NetHandler)
      handler.handle_block_dig(self)
    end

    def clone : Packet
      BlockDigPacket.new(@status, @x, @y, @z, @face)
    end
  end
end
