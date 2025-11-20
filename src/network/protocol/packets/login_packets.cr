# src/network/protocol/packets/login_packets.cr
module CrystalMC::Network::Protocol
  class LoginPacket < Packet
    property entity_id : Int32
    property username : String
    property seed : Int64
    property dimension : Int8

    def initialize(@entity_id : Int32 = 0, @username : String = "", @seed : Int64 = 0_i64, @dimension : Int8 = 0_i8)
    end

    def packet_id : UInt8
      0x01_u8
    end

    def read(io : IO)
      @entity_id = read_int(io)
      @username = read_string(io)
      @seed = read_long(io)
      @dimension = read_byte(io).to_i8
    end

    def write(io : IO)
      write_int(io, @entity_id)
      write_string(io, @username)
      write_long(io, @seed)
      write_byte(io, @dimension.to_u8)
    end

    def handle(handler : NetHandler)
      # This packet is sent by server, so no handling needed on server side
    end

    def clone : Packet
      LoginPacket.new(@entity_id, @username, @seed, @dimension)
    end
  end
end