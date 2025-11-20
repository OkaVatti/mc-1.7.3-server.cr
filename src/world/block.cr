module CrystalMC::World
  class Block
    property id : UInt8
    property metadata : UInt8

    def initialize(@id : UInt8 = 0_u8, @metadata : UInt8 = 0_u8)
    end

    def air? : Bool
      @id == 0
    end

    def solid? : Bool
      !air? && SOLID_BLOCKS.includes?(@id)
    end

    def transparent? : Bool
      TRANSPARENT_BLOCKS.includes?(@id)
    end

    def self.air
      new(0_u8, 0_u8)
    end

    # Block type constants (Beta 1.7.3)
    AIR              =  0_u8
    STONE            =  1_u8
    GRASS            =  2_u8
    DIRT             =  3_u8
    COBBLESTONE      =  4_u8
    PLANKS           =  5_u8
    SAPLING          =  6_u8
    BEDROCK          =  7_u8
    WATER            =  8_u8
    WATER_STATIONARY =  9_u8
    LAVA             = 10_u8
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
      STONE, GRASS, DIRT, COBBLESTONE, PLANKS, BEDROCK,
      SAND, GRAVEL, GOLD_ORE, IRON_ORE, COAL_ORE, WOOD,
      LEAVES, SPONGE, GLASS,
    }

    TRANSPARENT_BLOCKS = Set{
      AIR, SAPLING, WATER, WATER_STATIONARY, LAVA, LAVA_STATIONARY,
      GLASS, LEAVES,
    }
  end
end
