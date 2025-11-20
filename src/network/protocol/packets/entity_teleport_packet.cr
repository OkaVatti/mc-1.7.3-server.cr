# src/network/protocol/packets/entity_teleport_packet.cr
module CrystalMC::Network::Protocol
  class EntityTeleportPacket < Packet
    property entity_id : Int32
    property x : Int32
    property y : Int32
    property z : Int32
    property yaw : Int8
    property pitch : Int8

    def initialize(
      @entity_id : Int32 = 0,
      @x : Int32 = 0,
      @y : Int32 = 0,
      @z : Int32 = 0,
      @yaw : Int8 = 0,
      @pitch : Int8 = 0
    )
    end

    def packet_id : UInt8
      0x22_u8
    end

    def read(io : IO)
      @entity_id = read_int(io)
      @x = read_int(io)
      @y = read_int(io)
      @z = read_int(io)
      @yaw = read_byte(io).to_i8
      @pitch = read_byte(io).to_i8
    end

    def write(io : IO)
      write_int(io, @entity_id)
      write_int(io, @x)
      write_int(io, @y)
      write_int(io, @z)
      write_byte(io, @yaw.to_u8)
      write_byte(io, @pitch.to_u8)
    end

    def handle(handler : NetHandler)
      # Client handles this
    end

    def clone : Packet
      EntityTeleportPacket.new(@entity_id, @x, @y, @z, @yaw, @pitch)
    end
  end
end
