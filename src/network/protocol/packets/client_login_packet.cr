module CrystalMC::Network::Protocol
  class ClientLoginPacket < Packet
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
      0x01_u8
    end

    def read(io : IO)
      @entity_id = read_int(io)
      @username = read_string(io)
      @level_type = read_string(io)
      @game_mode = read_int(io)
      @dimension = read_int(io)
      @difficulty = read_byte(io)
      @world_height = read_byte(io)
      @max_players = read_byte(io)

      puts "Client login packet: user=#{@username}, entity=#{@entity_id}, mode=#{@game_mode}"
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
    end

    def handle(handler : NetHandler)
      handler.handle_login_request(self)
    end

    def clone : Packet
      ClientLoginPacket.new(@entity_id, @username, @level_type, @game_mode, @dimension,
        @difficulty, @world_height, @max_players)
    end
  end
end
