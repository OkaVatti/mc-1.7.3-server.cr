# src/world/block.cr
module CrystalMC::World
  struct Block
    property id : UInt8
    property metadata : UInt8

    # Block IDs for Beta 1.7.3
    AIR              =  0_u8
    STONE            =  1_u8
    GRASS            =  2_u8
    DIRT             =  3_u8
    COBBLESTONE      =  4_u8
    WOOD_PLANKS      =  5_u8
    SAPLING          =  6_u8
    BEDROCK          =  7_u8
    WATER_FLOWING    =  8_u8
    WATER_STATIONARY =  9_u8
    LAVA_FLOWING     = 10_u8
    LAVA_STATIONARY  = 11_u8
    SAND             = 12_u8
    GRAVEL           = 13_u8
    GOLD_ORE         = 14_u8
    IRON_ORE         = 15_u8
    COAL_ORE         = 16_u8
    WOOD             = 17_u8
    LEAVES           = 18_u8
    SPONGE           = 19_u8
    GLASS            = 20_u8

    # Collections for block properties
    SOLID_BLOCKS = Set{
      STONE, GRASS, DIRT, COBBLESTONE, WOOD_PLANKS, BEDROCK,
      SAND, GRAVEL, GOLD_ORE, IRON_ORE, COAL_ORE, WOOD,
      LEAVES, SPONGE, GLASS,
    }

    TRANSPARENT_BLOCKS = Set{
      AIR, SAPLING, WATER_FLOWING, WATER_STATIONARY,
      LAVA_FLOWING, LAVA_STATIONARY, GLASS, LEAVES,
    }

    def initialize(@id : UInt8, @metadata : UInt8)
    end

    def self.air : Block
      new(AIR, 0_u8)
    end

    def self.stone : Block
      new(STONE, 0_u8)
    end

    def self.water_stationary : Block
      new(WATER_STATIONARY, 0_u8)
    end

    def self.grass : Block
      new(GRASS, 0_u8)
    end

    def self.dirt : Block
      new(DIRT, 0_u8)
    end

    def self.bedrock : Block
      new(BEDROCK, 0_u8)
    end

    def self.sand : Block
      new(SAND, 0_u8)
    end

    def self.gravel : Block
      new(GRAVEL, 0_u8)
    end

    def air? : Bool
      @id == AIR
    end

    def solid? : Bool
      !air? && SOLID_BLOCKS.includes?(@id)
    end

    def transparent? : Bool
      TRANSPARENT_BLOCKS.includes?(@id)
    end

    def liquid? : Bool
      @id == WATER_FLOWING || @id == WATER_STATIONARY ||
        @id == LAVA_FLOWING || @id == LAVA_STATIONARY
    end

    def ==(other : Block) : Bool
      @id == other.id && @metadata == other.metadata
    end

    def to_s(io : IO)
      io << "Block(#{@id}:#{@metadata})"
    end
  end
end
