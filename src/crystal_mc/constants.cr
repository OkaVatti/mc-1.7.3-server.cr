# src/crystal_mc/constants.cr
module CrystalMC
  VERSION = "0.1.0"

  class Constants
    # Server timing
    TICK_DURATION       = 50.milliseconds
    KEEP_ALIVE_INTERVAL = 100 # ticks
    TIMEOUT_SECONDS     =  30

    # Player limits
    MAX_PLAYER_NAME_LENGTH = 16

    # World dimensions
    WORLD_HEIGHT = 128
    CHUNK_WIDTH  =  16
    CHUNK_HEIGHT = 128
    CHUNK_DEPTH  =  16
    CHUNK_SIZE   =  16

    # Protocol
    PROTOCOL_VERSION = 14 # Beta 1.7.3

    # Network
    MAX_PACKET_SIZE       = 32767
    COMPRESSION_THRESHOLD =   256

    # Game settings
    DEFAULT_GAMEMODE      =  0 # Survival
    DEFAULT_DIFFICULTY    =  1 # Normal
    DEFAULT_MAX_PLAYERS   = 20
    DEFAULT_VIEW_DISTANCE = 10

    # Entity limits
    MAX_ENTITY_ID = 2147483647

    # Physics
    PLAYER_EYE_HEIGHT = 1.62
    GRAVITY           = 0.08
    PLAYER_WIDTH      =  0.6
    PLAYER_HEIGHT     =  1.8
  end
end
