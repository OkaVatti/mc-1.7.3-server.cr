require "./crystal_mc/crystal_mc"
require "./crystal_mc/server"

module CrystalMC
  def self.start
    puts "Starting Crystal Minecraft Server v#{VERSION}"
    puts "Target Protocol: Minecraft Beta 1.7.3 (Protocol #{PROTOCOL_VERSION})"
    puts "=" * 50

    host = ENV["HOST"]? || "0.0.0.0"
    port = (ENV["PORT"]? || "25565").to_i
    max_players = (ENV["MAX_PLAYERS"]? || "20").to_i
    motd = ENV["MOTD"]? || "A Crystal Minecraft Server"

    server = Server.new(host, port, max_players, motd)
    server.start
  rescue ex
    puts "Fatal error: #{ex.message}"
    puts ex.backtrace.join("\n")
    exit 1
  end
end

CrystalMC.start
