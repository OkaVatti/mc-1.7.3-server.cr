require "./crystal_mc/crystal_mc"
require "./crystal_mc/server"
require "./config/server_config"
require "./crystal_mc/constants"
require "./crystal_mc/version"

module CrystalMC
  PROTOCOL_VERSION = Constants::PROTOCOL_VERSION

  def self.start
    puts "╔══════════════════════════════════════════════════╗"
    puts "║     CrystalMC - Minecraft Beta 1.7.3 Server      ║"
    puts "║              Version #{VERSION.ljust(24)}  ║"
    puts "╚══════════════════════════════════════════════════╝"
    puts ""
    puts "Target Protocol: Minecraft Beta 1.7.3 (Protocol #{PROTOCOL_VERSION})"
    puts "=" * 52
    puts ""

    # Load configuration
    config = Config::ServerConfig.load

    puts "Loading configuration..."
    puts "  Server Name: #{config.server_name}"
    puts "  Max Players: #{config.max_players}"
    puts "  View Distance: #{config.view_distance}"
    puts "  Online Mode: #{config.online_mode}"
    puts ""

    host = ENV["HOST"]? || config.server_ip
    port = (ENV["PORT"]? || config.server_port.to_s).to_i
    max_players = (ENV["MAX_PLAYERS"]? || config.max_players.to_s).to_i
    motd = ENV["MOTD"]? || config.motd

    server = Server.new(host, port, max_players, motd)

    # Handle signals for graceful shutdown
    Signal::INT.trap do
      puts "\nReceived interrupt signal, shutting down..."
      server.stop
      exit 0
    end

    Signal::TERM.trap do
      puts "\nReceived termination signal, shutting down..."
      server.stop
      exit 0
    end

    server.start
  rescue ex
    puts "Fatal error: #{ex.message}"
    puts ex.backtrace.join("\n")
    exit 1
  end
end

CrystalMC.start
