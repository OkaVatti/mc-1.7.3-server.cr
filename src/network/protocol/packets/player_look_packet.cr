# src/network/protocol/packets/player_look_packet.cr
require "./packet"
require "./protocol_helper"

module CrystalMC::Network::Protocol
  class PlayerLookPacket < Packet
    property yaw : Float32
    property pitch : Float32
    property on_ground : Bool

    def initialize(
      @yaw : Float32 = 0.0_f32,
      @pitch : Float32 = 0.0_f32,
      @on_ground : Bool = false
    )
    end

    def packet_id : UInt8
      0x0C_u8
    end

    def read(io : IO)
      @yaw = ProtocolHelper.read_float(io)
      @pitch = ProtocolHelper.read_float(io)
      @on_ground = ProtocolHelper.read_bool(io)
    end

    def write(io : IO)
      ProtocolHelper.write_float(io, @yaw)
      ProtocolHelper.write_float(io, @pitch)
      ProtocolHelper.write_bool(io, @on_ground)
    end

    def handle(handler : NetHandler)
      handler.handle_player_look(self)
    end

    def clone : Packet
      PlayerLookPacket.new(@yaw, @pitch, @on_ground)
    end
  end
end