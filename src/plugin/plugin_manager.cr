require "./plugin"

module CrystalMC
  # Forward declare Server to avoid circular dependency
  class Server; end
end

module CrystalMC::Plugin
  class PluginManager
    property server : CrystalMC::Server
    property plugins : Array(Plugin)
    property commands : Hash(String, CommandHandler)
    property tasks : Array(ScheduledTask)

    def initialize(@server : CrystalMC::Server)
      @plugins = [] of Plugin
      @commands = {} of String => CommandHandler
      @tasks = [] of ScheduledTask
    end

    def call_player_command(player : World::Player, command : String, args : Array(String)) : Bool
      # Return true if plugin handled the command
      false
    end

    def loaded_plugins : Array(String)
      # Fix: Use explicit block with type annotation
      @plugins.map { |plugin| plugin.name.as(String) }
    end

    def load_plugin(plugin : Plugin)
      @plugins << plugin
      log_info "Loading plugin: #{plugin.name} v#{plugin.version} by #{plugin.author}"

      begin
        plugin.on_enable
        log_info "Enabled plugin: #{plugin.name}"
      rescue ex
        log_error "Failed to enable plugin #{plugin.name}: #{ex.message}"
        @plugins.delete(plugin)
      end
    end

    def unload_plugin(plugin : Plugin)
      log_info "Unloading plugin: #{plugin.name}"

      begin
        plugin.on_disable
      rescue ex
        log_error "Error disabling plugin #{plugin.name}: #{ex.message}"
      end

      @plugins.delete(plugin)

      # Remove plugin commands
      @commands.reject! { |_, handler| handler.plugin == plugin }

      # Remove plugin tasks
      @tasks.reject! { |task| task.plugin == plugin }
    end

    def unload_all
      log_info "Unloading all plugins..."

      # Call on_disable for all plugins in reverse order (dependency order)
      @plugins.reverse_each do |plugin|
        begin
          plugin.on_disable
          log_info "Disabled plugin: #{plugin.name}"
        rescue ex
          log_error "Error disabling plugin #{plugin.name}: #{ex.message}"
        end
      end

      # Clear all collections
      @plugins.clear
      @commands.clear
      @tasks.clear

      log_info "All plugins unloaded"
    end

    def register_command(name : String, plugin : Plugin, handler : Proc(World::Player, Array(String), Nil))
      @commands[name.downcase] = CommandHandler.new(plugin, handler)
      log_info "Registered command /#{name} from plugin #{plugin.name}"
    end

    def handle_command(player : World::Player, command : String, args : Array(String)) : Bool
      # Check plugin commands first
      if handler = @commands[command.downcase]?
        begin
          handler.handler.call(player, args)
          return true
        rescue ex
          player.send_message("§cError executing command: #{ex.message}")
          log_error "Error in command /#{command}: #{ex.message}"
          return true
        end
      end

      # Give plugins a chance to handle the command
      @plugins.each do |plugin|
        return true if plugin.on_command(player, command, args)
      end

      false
    end

    def schedule_task(plugin : Plugin, delay_ticks : Int32, handler : Proc(Nil))
      task = ScheduledTask.new(plugin, delay_ticks, -1, handler)
      @tasks << task
    end

    def schedule_repeating_task(plugin : Plugin, delay_ticks : Int32, period_ticks : Int32, handler : Proc(Nil))
      task = ScheduledTask.new(plugin, delay_ticks, period_ticks, handler)
      @tasks << task
    end

    def tick
      @tasks.reject! do |task|
        task.tick_counter += 1

        if task.tick_counter >= task.next_run
          begin
            task.handler.call
          rescue ex
            log_error "Error in scheduled task from #{task.plugin.name}: #{ex.message}"
          end

          if task.period > 0
            task.next_run = task.tick_counter + task.period
            false # Keep repeating tasks
          else
            true # Remove one-time tasks
          end
        else
          false # Keep waiting
        end
      end
    end

    # Event dispatchers
    def call_player_join(player : World::Player)
      @plugins.each { |plugin| plugin.on_player_join(player) }
    end

    def call_player_quit(player : World::Player)
      @plugins.each { |plugin| plugin.on_player_quit(player) }
    end

    def call_player_chat(player : World::Player, message : String) : String?
      result = message
      @plugins.each do |plugin|
        modified = plugin.on_player_chat(player, result)
        if modified.nil?
          return nil
        else
          result = modified
        end
      end
      result
    end

    def call_block_break(player : World::Player, x : Int32, y : Int32, z : Int32, face : Int8) : Bool
      @plugins.each do |plugin|
        return false unless plugin.on_block_break(player, x, y, z, face)
      end
      true
    end

    def call_block_place(player : World::Player, x : Int32, y : Int32, z : Int32, block_type : UInt8) : Bool
      @plugins.each do |plugin|
        return false unless plugin.on_block_place(player, x, y, z, block_type)
      end
      true
    end

    private def log_info(message : String)
      puts "[PluginManager] #{message}"
    end

    private def log_error(message : String)
      puts "[PluginManager] ERROR: #{message}"
    end

    record CommandHandler, plugin : Plugin, handler : Proc(World::Player, Array(String), Nil)

    class ScheduledTask
      property plugin : Plugin
      property delay : Int32
      property period : Int32
      property handler : Proc(Nil)
      property tick_counter : Int32
      property next_run : Int32

      def initialize(@plugin : Plugin, @delay : Int32, @period : Int32, @handler : Proc(Nil))
        @tick_counter = 0
        @next_run = @delay
      end
    end
  end
end
