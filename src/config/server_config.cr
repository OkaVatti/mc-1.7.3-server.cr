require "yaml"
require "../crystal_mc/constants"

module CrystalMC::Config
  class ServerConfig
    include YAML::Serializable

    property server_name : String = "CrystalMC Server"
    property server_port : Int32 = 25565
    property server_ip : String = "0.0.0.0"
    property max_players : Int32 = 20
    property motd : String = "A Minecraft Beta 1.7.3 Server"
    property view_distance : Int32 = 10
    property online_mode : Bool = false
    property difficulty : Int32 = 1
    property gamemode : Int32 = 0
    property pvp : Bool = true
    property allow_flight : Bool = false
    property world_name : String = "world"
    property world_seed : Int64? = nil
    property spawn_protection : Int32 = 16
    property max_build_height : Int32 = 128
    property enable_command_blocks : Bool = false
    property auto_save_interval : Int32 = 6000 # In ticks (5 minutes)

    # Define a default constructor
    def initialize
      # All properties have default values, so no need to set them here
      # The YAML::Serializable macro will handle the defaults
    end

    def self.load(path : String = "server.yml") : ServerConfig
      if File.exists?(path)
        begin
          from_yaml(File.read(path))
        rescue ex
          puts "Error loading config file #{path}: #{ex.message}"
          puts "Using default configuration..."
          config = ServerConfig.new
          config.save(path)
          config
        end
      else
        puts "Config file #{path} not found, creating default configuration..."
        config = ServerConfig.new
        config.save(path)
        config
      end
    end

    def save(path : String = "server.yml")
      File.write(path, to_yaml)
      puts "Configuration saved to #{path}"
    end
  end
end
