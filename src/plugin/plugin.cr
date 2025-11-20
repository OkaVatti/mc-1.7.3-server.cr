# src/plugin/plugin.cr
module CrystalMC::Plugin
  abstract class Plugin
    abstract def name : String
    abstract def version : String
    abstract def author : String

    # Lifecycle methods
    def on_enable
      # Override in subclasses
    end

    def on_disable
      # Override in subclasses
    end

    # Event handlers - return values control behavior
    def on_player_join(player : World::Player)
      # Override in subclasses
    end

    def on_player_quit(player : World::Player)
      # Override in subclasses
    end

    def on_player_chat(player : World::Player, message : String) : String?
      # Return modified message, or nil to cancel
      message
    end

    def on_command(player : World::Player, command : String, args : Array(String)) : Bool
      # Return true if handled
      false
    end

    def on_block_break(player : World::Player, x : Int32, y : Int32, z : Int32, face : Int8) : Bool
      # Return false to cancel the break
      true
    end

    def on_block_place(player : World::Player, x : Int32, y : Int32, z : Int32, block_type : UInt8) : Bool
      # Return false to cancel the placement
      true
    end

    # Helper methods for plugins
    def get_server : CrystalMC::Server
      # This would be set when the plugin is loaded
      # For now, plugins need to store a reference to the server
      raise "Server reference not available"
    end

    def get_world : World::World
      get_server.world
    end

    def broadcast_message(message : String)
      get_server.broadcast(message)
    end

    def schedule_task(delay_ticks : Int32, &block : ->)
      get_server.plugin_manager.try do |pm|
        pm.schedule_task(self, delay_ticks, block)
      end
    end

    def schedule_repeating_task(delay_ticks : Int32, period_ticks : Int32, &block : ->)
      get_server.plugin_manager.try do |pm|
        pm.schedule_repeating_task(self, delay_ticks, period_ticks, block)
      end
    end

    def register_command(name : String, &handler : World::Player, Array(String) ->)
      get_server.plugin_manager.try do |pm|
        pm.register_command(name, self, handler)
      end
    end

    def log_info(message : String)
      puts "[#{name}] #{message}"
    end

    def log_warning(message : String)
      puts "[#{name}] WARNING: #{message}"
    end

    def log_error(message : String)
      puts "[#{name}] ERROR: #{message}"
    end
  end
end
