module CrystalMC::Network::Protocol
  class ServerLoginPacket < Packet
    property entity_id : Int32
    property username : String
    property level_type : String
    property game_mode : Int32
    property dimension : Int32
    property difficulty : UInt8
    property world_height : UInt8
    property max_players : UInt8

    def initialize(@entity_id : Int32 = 0, @username : String = "", @level_type : String = "default",
                   @game_mode : Int32 = 0, @dimension : Int32 = 0, @difficulty : UInt8 = 0,
                   @world_height : UInt8 = 0, @max_players : UInt8 = 0)
    end

    def packet_id : UInt8
      0x01_u8 # Same packet ID as client login, but different direction
    end

    def read(io : IO)
      # Server login packet is sent from server to client, so we don't read it on server side
      # But we implement it for completeness and potential future use
      @entity_id = read_int(io)
      @username = read_string(io)
      @level_type = read_string(io)
      @game_mode = read_int(io)
      @dimension = read_int(io)
      @difficulty = read_byte(io)
      @world_height = read_byte(io)
      @max_players = read_byte(io)

      puts "Server login packet read: user=#{@username}, entity=#{@entity_id}"
    end

    def write(io : IO)
      write_int(io, @entity_id)
      write_string(io, @username)
      write_string(io, @level_type)
      write_int(io, @game_mode)
      write_int(io, @dimension)
      write_byte(io, @difficulty)
      write_byte(io, @world_height)
      write_byte(io, @max_players)

      puts "Server login packet written: user=#{@username}, entity=#{@entity_id}"
    end

    def handle(handler : NetHandler)
      # Server login packet is sent TO client, not handled BY server
      # But we need to implement this method due to abstract base class
      puts "Server login packet handled (shouldn't happen on server)"
    end

    def clone : Packet
      ServerLoginPacket.new(@entity_id, @username, @level_type, @game_mode, @dimension,
        @difficulty, @world_height, @max_players)
    end
  end
end
