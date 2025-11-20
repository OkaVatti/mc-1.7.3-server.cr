require "socket"
require "./constants"
require "../network/connection"
require "../network/packet_handler"
require "../world/world" # This loads CrystalMC::World::World
require "./auth/authenticator"

module CrystalMC
  class Server
    property host : String
    property port : Int32
    property max_players : Int32
    property motd : String
    property running : Bool
    property world : World::World # Use the class from World module

    @server : TCPServer?
    @connections : Array(Network::Connection)
    @tick_fiber : Fiber?

    def initialize(@host : String, @port : Int32, @max_players : Int32, @motd : String)
      @running = false
      @connections = [] of Network::Connection
      @world = World::World.new("world") # Create World instance

      # Set offline mode for now
      Auth::Authenticator.online_mode = false
    end

    def start
      @server = TCPServer.new(@host, @port)
      @running = true

      puts "Server started on #{@host}:#{@port}"
      puts "MOTD: #{@motd}"
      puts "Max players: #{@max_players}"
      puts "World: #{@world.name} (seed: #{@world.seed})"
      puts "Authentication: #{Auth::Authenticator.online_mode? ? "Online" : "Offline"} mode"
      puts ""

      # Start the main game tick loop
      start_tick_loop

      # Accept incoming connections
      accept_connections
    end

    def stop
      @running = false
      @server.try &.close
      @connections.each &.disconnect("Server shutting down")
      puts "Server stopped"
    end

    private def accept_connections
      server = @server
      return unless server

      while @running
        begin
          socket = server.accept
          spawn handle_client(socket)
        rescue ex
          puts "Error accepting connection: #{ex.message}"
        end
      end
    end

    private def handle_client(socket : TCPSocket)
      connection = Network::Connection.new(socket, self)
      connection.setup_handlers
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

          # Perform server tick
          tick(tick_counter)
          tick_counter += 1

          # Calculate sleep time to maintain 20 TPS
          elapsed = (Time.monotonic - start_time).total_milliseconds
          sleep_time = TICK_DURATION - elapsed

          if sleep_time > 0
            sleep sleep_time.milliseconds
          else
            # Server is running behind
            if tick_counter % 100 == 0
              puts "Warning: Server running behind! Tick took #{elapsed.round(2)}ms"
            end
          end
        end
      end
    end

    private def tick(tick_counter : UInt64)
      # Update world
      @world.tick

      # Send keep-alive packets every second (20 ticks) to logged-in connections only
      if tick_counter % KEEP_ALIVE_INTERVAL == 0
        @connections.each do |conn|
          conn.send_keep_alive if conn.logged_in?
        end
      end

      # Update all connections
      @connections.each do |conn|
        conn.tick
      end

      # Print server status every 10 seconds (200 ticks)
      if tick_counter % 200 == 0
        puts "Server status: #{player_count}/#{@max_players} players, Time: #{@world.time}"
      end
    end

    def broadcast(message : String)
      @connections.each do |conn|
        conn.send_chat_message(message) if conn.logged_in?
      end
    end

    def player_count : Int32
      @connections.count(&.logged_in?)
    end

    def get_world : World::World
      @world
    end
  end
end
