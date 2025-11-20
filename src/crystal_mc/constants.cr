module CrystalMC
  # Server constants
  DEFAULT_PORT    = 25565
  MAX_PACKET_SIZE = 32767

  # World constants

  # Tick constants
  TICKS_PER_SECOND    =   20
  TICK_DURATION       = 50.0 # 50ms per tick (20 TPS)
  KEEP_ALIVE_INTERVAL =   20 # Send keep-alive every second (20 ticks)
  TIMEOUT_SECONDS     = 30.0 # Disconnect after 30 seconds of inactivity

  # Protocol constants
  PROTOCOL_VERSION = 14_u8 # Minecraft Beta 1.7.3

  # World constants
  WORLD_HEIGHT = 128
  SEA_LEVEL    =  62
  MAX_PLAYERS  = 100
  CHUNK_SIZE   =  16
  CHUNK_HEIGHT = 128

  # Player constants
  MAX_PLAYER_NAME_LENGTH = 16
  DEFAULT_GAMEMODE       =  0 # Survival
  DEFAULT_DIMENSION      =  0 # Overworld
end
