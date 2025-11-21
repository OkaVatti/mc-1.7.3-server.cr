module CrystalMC::World
  struct Block
    property id : UInt8
    property metadata : UInt8

    # Block IDs for Beta 1.7.3
    AIR                =   0_u8
    STONE              =   1_u8
    GRASS              =   2_u8
    DIRT               =   3_u8
    COBBLESTONE        =   4_u8
    WOOD_PLANKS        =   5_u8
    SAPLING            =   6_u8
    BEDROCK            =   7_u8
    WATER_FLOWING      =   8_u8
    WATER_STATIONARY   =   9_u8
    LAVA_FLOWING       =  10_u8
    LAVA_STATIONARY    =  11_u8
    SAND               =  12_u8
    GRAVEL             =  13_u8
    GOLD_ORE           =  14_u8
    IRON_ORE           =  15_u8
    COAL_ORE           =  16_u8
    WOOD               =  17_u8
    LEAVES             =  18_u8
    SPONGE             =  19_u8
    GLASS              =  20_u8
    LAPIS_LAZULI_ORE   =  21_u8
    LAPIS_LAZULI_BLOCK =  22_u8
    SANDSTONE          =  24_u8
    BED                =  26_u8
    COBWEB             =  30_u8
    TALL_GRASS         =  31_u8
    WOOL               =  35_u8
    YELLOW_FLOWER      =  37_u8
    RED_FLOWER         =  38_u8
    BROWN_MUSHROOM     =  39_u8
    RED_MUSHROOM       =  40_u8
    GOLD_BLOCK         =  41_u8
    IRON_BLOCK         =  42_u8
    DOUBLE_SLAB        =  43_u8
    SLAB               =  44_u8
    BRICK_BLOCK        =  45_u8
    TNT                =  46_u8
    BOOKSHELF          =  47_u8
    MOSS_STONE         =  48_u8
    OBSIDIAN           =  49_u8

    # Block property collections
    SOLID_BLOCKS = Set{
      STONE, GRASS, DIRT, COBBLESTONE, WOOD_PLANKS, BEDROCK,
      SAND, GRAVEL, GOLD_ORE, IRON_ORE, COAL_ORE, WOOD,
      LEAVES, SPONGE, GLASS, LAPIS_LAZULI_ORE, LAPIS_LAZULI_BLOCK,
      SANDSTONE, BED, COBWEB, WOOL, GOLD_BLOCK, IRON_BLOCK,
      DOUBLE_SLAB, SLAB, BRICK_BLOCK, TNT, BOOKSHELF, MOSS_STONE,
      OBSIDIAN
    }

    TRANSPARENT_BLOCKS = Set{
      AIR, SAPLING, WATER_FLOWING, WATER_STATIONARY,
      LAVA_FLOWING, LAVA_STATIONARY, GLASS, LEAVES,
      YELLOW_FLOWER, RED_FLOWER, BROWN_MUSHROOM, RED_MUSHROOM,
      TALL_GRASS, COBWEB
    }

    LIQUID_BLOCKS = Set{
      WATER_FLOWING, WATER_STATIONARY, LAVA_FLOWING, LAVA_STATIONARY
    }

    PLANT_BLOCKS = Set{
      SAPLING, TALL_GRASS, YELLOW_FLOWER, RED_FLOWER, 
      BROWN_MUSHROOM, RED_MUSHROOM
    }

    ORE_BLOCKS = Set{
      COAL_ORE, IRON_ORE, GOLD_ORE, LAPIS_LAZULI_ORE
    }

    def initialize(@id : UInt8, @metadata : UInt8)
    end

    # Factory methods for common blocks
    def self.air : Block
      new(AIR, 0_u8)
    end

    def self.stone : Block
      new(STONE, 0_u8)
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

    def self.water : Block
      new(WATER_STATIONARY, 0_u8)
    end

    def self.wood : Block
      new(WOOD, 0_u8)
    end

    def self.leaves : Block
      new(LEAVES, 0_u8)
    end

    def self.coal_ore : Block
      new(COAL_ORE, 0_u8)
    end

    def self.iron_ore : Block
      new(IRON_ORE, 0_u8)
    end

    def self.gold_ore : Block
      new(GOLD_ORE, 0_u8)
    end

    def self.rose : Block
      new(RED_FLOWER, 0_u8)
    end

    def self.yellow_flower : Block
      new(YELLOW_FLOWER, 0_u8)
    end

    # Block property methods
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
      LIQUID_BLOCKS.includes?(@id)
    end

    def plant? : Bool
      PLANT_BLOCKS.includes?(@id)
    end

    def ore? : Bool
      ORE_BLOCKS.includes?(@id)
    end

    def flammable? : Bool
      @id == WOOD || @id == LEAVES || @id == WOOL || @id == TNT
    end

    def can_be_broken_by_hand? : Bool
      !ore? && @id != OBSIDIAN && @id != BEDROCK
    end

    def get_hardness : Float64
      case @id
      when BEDROCK, OBSIDIAN
        50.0
      when STONE, COBBLESTONE, IRON_ORE, GOLD_ORE, COAL_ORE, LAPIS_LAZULI_ORE
        3.0
      when DIRT, GRASS, WOOD_PLANKS
        2.0
      when SAND, GRAVEL
        0.5
      else
        1.0
      end
    end

    def get_blast_resistance : Float64
      case @id
      when BEDROCK
        18000000.0
      when OBSIDIAN
        6000.0
      when STONE, COBBLESTONE, BRICK_BLOCK
        30.0
      when DIRT, WOOD_PLANKS
        15.0
      else
        0.0
      end
    end

    def ==(other : Block) : Bool
      @id == other.id && @metadata == other.metadata
    end

    def to_s(io : IO)
      io << "Block(#{@id}:#{@metadata})"
    end
  end
end