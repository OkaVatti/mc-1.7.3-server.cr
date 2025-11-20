# src/network/protocol/packets/named_entity_spawn_packet.cr
module CrystalMC::Network::Protocol
  class NamedEntitySpawnPacket < Packet
    property entity_id : Int32
    property player_name : String
    property x : Int32
    property y : Int32
    property z : Int32
    property rotation : Int8
    property pitch : Int8
    property current_item : Int16

    def initialize(
      @entity_id : Int32 = 0,
      @player_name : String = "",
      @x : Int32 = 0,
      @y : Int32 = 0,
      @z : Int32 = 0,
      @rotation : Int8 = 0,
      @pitch : Int8 = 0,
      @current_item : Int16 = 0
    )
    end

    def packet_id : UInt8
      0x14_u8
    end

    def read(io : IO)
      @entity_id = read_int(io)
      @player_name = read_string(io)
      @x = read_int(io)
      @y = read_int(io)
      @z = read_int(io)
      @rotation = read_byte(io).to_i8
      @pitch = read_byte(io).to_i8
      @current_item = read_short(io)
    end

    def write(io : IO)
      write_int(io, @entity_id)
      write_string(io, @player_name)
      write_int(io, @x)
      write_int(io, @y)
      write_int(io, @z)
      write_byte(io, @rotation.to_u8)
      write_byte(io, @pitch.to_u8)
      write_short(io, @current_item)
    end

    def handle(handler : NetHandler)
      # Client handles this
    end

    def clone : Packet
      NamedEntitySpawnPacket.new(@entity_id, @player_name, @x, @y, @z, @rotation, @pitch, @current_item)
    end
  end
end