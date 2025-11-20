require "./packet"
require "./protocol_helper"

module CrystalMC::Network::Protocol
  # Remove 'abstract' to make this a concrete class
  class PlayerLookMovePacket < Packet
    property x : Float64
    property y : Float64
    property stance : Float64
    property z : Float64
    property yaw : Float32
    property pitch : Float32
    property on_ground : Bool

    def initialize(
      @x : Float64 = 0.0,
      @y : Float64 = 0.0,
      @stance : Float64 = 0.0,
      @z : Float64 = 0.0,
      @yaw : Float32 = 0.0_f32,
      @pitch : Float32 = 0.0_f32,
      @on_ground : Bool = false
    )
    end

    def packet_id : UInt8
      0x0D_u8
    end

    def read(io : IO)
      @x = ProtocolHelper.read_double(io)
      @y = ProtocolHelper.read_double(io)
      @stance = ProtocolHelper.read_double(io)
      @z = ProtocolHelper.read_double(io)
      @yaw = ProtocolHelper.read_float(io)
      @pitch = ProtocolHelper.read_float(io)
      @on_ground = ProtocolHelper.read_bool(io)
    end

    def write(io : IO)
      ProtocolHelper.write_ubyte(io, packet_id)
      ProtocolHelper.write_double(io, @x)
      ProtocolHelper.write_double(io, @y)
      ProtocolHelper.write_double(io, @stance)
      ProtocolHelper.write_double(io, @z)
      ProtocolHelper.write_float(io, @yaw)
      ProtocolHelper.write_float(io, @pitch)
      ProtocolHelper.write_bool(io, @on_ground)
    end

    def handle(handler : NetHandler)
      handler.handle_player_look_move(self)
    end

    # Add the required clone method
    def clone : Packet
      PlayerLookMovePacket.new(@x, @y, @stance, @z, @yaw, @pitch, @on_ground)
    end
  end
end
