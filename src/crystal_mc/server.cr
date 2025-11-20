require "socket"
require "./constants"
require "../network/connection"
require "../network/packet_handler"
require "../world/world"
require "../world/player"
require "./auth/authenticator"
require "../plugin/plugin_manager"

module CrystalMC
  class Server
    property host : String
    property port : Int32
    property max_players : Int32
    property motd : String
    property running : Bool
    property world : World::World
    property players : Hash(String, World::Player)
    property next_entity_id : Int32

    @server : TCPServer?
    @connections : Array(Network::Connection)
    @tick_fiber : Fiber?

    # Plugin manager may be nil; we guard calls to it.
    @plugin_manager : Plugin::PluginManager?

    def initialize(@host : String, @port : Int32, @max_players : Int32, @motd : String)
      @running = false
      @connections = [] of Network::Connection
      @players = {} of String => World::Player
      @next_entity_id = 1

      # Initialize world first (doesn't depend on server)
      @world = World::World.new("world")

      # Set offline mode for now (static/class method, doesn't need server instance)
      Auth::Authenticator.online_mode = false

      # Initialize plugin_manager LAST. If construction fails, leave nil.
      begin
        @plugin_manager = Plugin::PluginManager.new(self)
      rescue
        @plugin_manager = nil
      end
    end

    def plugin_manager : Plugin::PluginManager?
      @plugin_manager
    end

    def start
      @server = TCPServer.new(@host, @port)
      @running = true

      puts "🚀 Starting CrystalMC server..."
      puts "📍 Host: #{@host}:#{@port}"
      puts "📝 MOTD: #{@motd}"
      puts "👥 Max players: #{@max_players}"
      puts "🌍 World: #{@world.name} (seed: #{@world.seed})"
      puts "🔐 Authentication: #{Auth::Authenticator.online_mode? ? "Online" : "Offline"} mode"
      puts ""

      load_plugins
      start_tick_loop
      accept_connections
    end

    def stop
      @running = false

      @plugin_manager.try do |pm|
        pm.unload_all
      end

      @server.try &.close

      @connections.each do |c|
        begin
          c.disconnect("Server shutting down")
        rescue
          # ignore
        end
      end

      puts "Server stopped"
    end

    def allocate_entity_id : Int32
      id = @next_entity_id
      @next_entity_id += 1
      id
    end

    def add_player(player : World::Player)
      @players[player.username] = player
      @plugin_manager.try do |pm|
        pm.call_player_join(player)
      end
    end

    def remove_player(username : String)
      if player = @players.delete(username)
        # Despawn player for all others
        destroy_packet = Network::Protocol::EntityDestroyPacket.new(player.entity_id)
        @connections.each do |conn|
          next unless conn.logged_in?
          next if conn.username == username
          conn.send_packet(destroy_packet)
        end

        @plugin_manager.try do |pm|
          pm.call_player_quit(player)
        end
      end
    end

    def get_player(username : String) : World::Player?
      @players[username]?
    end

    private def load_plugins
      puts "Loading plugins..."
      # Example: @plugin_manager.try { |pm| pm.load_plugin(ExamplePlugin.new(self)) }
      puts "Plugin loading complete"
    end

    private def accept_connections
      server = @server
      return unless server

      while @running
        begin
          socket = server.accept
          # spawn a fiber that calls handle_client with the socket
          spawn do
            handle_client(socket)
          end
        rescue ex
          puts "Error accepting connection: #{ex.message}"
        end
      end
    end

    private def handle_client(socket : TCPSocket)
      connection = Network::Connection.new(socket, self)
      @connections << connection

      puts "New connection from #{socket.remote_address}"

      connection.handle
    rescue ex
      puts "Error handling client: #{ex.message}"
      puts ex.backtrace.join("\n")
    ensure
      @connections.delete(connection) if connection
    end

    private def start_tick_loop
      @tick_fiber = spawn do
        tick_counter = 0_u64

        while @running
          start_time = Time.monotonic

          tick(tick_counter)
          tick_counter += 1

          elapsed_time = Time.monotonic - start_time
          sleep_time = Constants::TICK_DURATION - elapsed_time

          if sleep_time > Time::Span.zero
            sleep sleep_time
          else
            if tick_counter % 100 == 0
              puts "Warning: Server running behind! Tick took #{elapsed_time.total_milliseconds.round(2)}ms"
            end
          end
        end
      end
    end

    private def tick(tick_counter : UInt64)
      @world.tick

      @players.each_value do |player|
        player.tick
      end

      @plugin_manager.try do |pm|
        pm.tick
      end

      if tick_counter % Constants::KEEP_ALIVE_INTERVAL == 0
        @connections.each do |conn|
          conn.send_keep_alive if conn.logged_in?
        end
      end

      if tick_counter % 20 == 0
        send_time_updates
      end

      @connections.each do |conn|
        conn.tick
      end

      if tick_counter % 200 == 0
        puts "Server status: #{player_count}/#{@max_players} players, Time: #{@world.time}, Chunks: #{@world.chunk_count}"
      end
    end

    private def send_time_updates
      time_packet = Network::Protocol::TimeUpdatePacket.new(@world.time)
      @connections.each do |conn|
        conn.send_packet(time_packet) if conn.logged_in?
      end
    end

    def broadcast(message : String)
      @connections.each do |conn|
        conn.send_chat_message(message) if conn.logged_in?
      end
    end

    def broadcast_packet(packet : Network::Protocol::Packet, except_username : String? = nil)
      @connections.each do |conn|
        if conn.logged_in? && conn.username != except_username
          conn.send_packet(packet)
        end
      end
    end

    def broadcast_except(message : String, except_username : String)
      @connections.each do |conn|
        if conn.logged_in? && conn.username != except_username
          conn.send_chat_message(message)
        end
      end
    end

    def player_count : Int32
      @connections.count { |c| c.logged_in? }
    end

    def get_world : World::World
      @world
    end
  end
end
