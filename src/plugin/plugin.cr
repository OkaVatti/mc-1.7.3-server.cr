module CrystalMC
  # Forward declare Server to avoid circular dependency
  class Server; end
end

module CrystalMC::Plugin
  abstract class Plugin
    property name : String
    property version : String
    property author : String
    property description : String
    getter server : CrystalMC::Server

    def initialize(@server : CrystalMC::Server)
      @name = "UnnamedPlugin"
      @version = "0.1.0"
      @author = "Unknown"
      @description = "No description provided"
    end

    # Lifecycle methods
    abstract def on_enable
    abstract def on_disable

    # Event handlers (optional)
    def on_player_join(player : World::Player)
    end

    def on_player_quit(player : World::Player)
    end

    def on_player_chat(player : World::Player, message : String) : String?
      message # Return modified message or nil to cancel
    end

    def on_block_break(player : World::Player, x : Int32, y : Int32, z : Int32) : Bool
      true # Return false to cancel
    end

    def on_block_place(player : World::Player, x : Int32, y : Int32, z : Int32, block : World::Block) : Bool
      true # Return false to cancel
    end

    def on_command(player : World::Player, command : String, args : Array(String)) : Bool
      false # Return true if command was handled
    end

    # Utility methods
    def log_info(message : String)
      puts "[#{@name}] #{message}"
    end

    def log_warning(message : String)
      puts "[#{@name}] WARNING: #{message}"
    end

    def log_error(message : String)
      puts "[#{@name}] ERROR: #{message}"
    end

    def register_command(name : String, &block : World::Player, Array(String) -> Nil)
      @server.plugin_manager.register_command(name, self, block)
    end

    def schedule_task(delay_ticks : Int32, &block)
      @server.plugin_manager.schedule_task(self, delay_ticks, block)
    end

    def schedule_repeating_task(delay_ticks : Int32, period_ticks : Int32, &block)
      @server.plugin_manager.schedule_repeating_task(self, delay_ticks, period_ticks, block)
    end
  end
end
