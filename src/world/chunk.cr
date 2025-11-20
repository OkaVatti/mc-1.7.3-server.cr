require "./block"
require "../crystal_mc/constants"

module CrystalMC::World
  class Chunk
    property x : Int32
    property z : Int32
    property blocks : Array(Block)
    property biome : Array(UInt8)
    property sky_light : Array(UInt8)
    property block_light : Array(UInt8)
    property height_map : Array(Int32)

    # Chunk dimensions
    SECTION_SIZE   =  16
    SECTION_HEIGHT = 128
    SECTION_COUNT  = SECTION_HEIGHT // 16 # 8 sections for Beta 1.7.3
    TOTAL_BLOCKS   = SECTION_SIZE * SECTION_HEIGHT * SECTION_SIZE

    def initialize(@x : Int32, @z : Int32)
      @blocks = Array(Block).new(TOTAL_BLOCKS, Block.air)
      @biome = Array(UInt8).new(SECTION_SIZE * SECTION_SIZE, 1_u8) # Default to plains
      @sky_light = Array(UInt8).new(TOTAL_BLOCKS, 0_u8)
      @block_light = Array(UInt8).new(TOTAL_BLOCKS, 0_u8)
      @height_map = Array(Int32).new(SECTION_SIZE * SECTION_SIZE, 0)
    end

    def set_block(x : Int32, y : Int32, z : Int32, block : Block)
      return if x < 0 || x >= SECTION_SIZE || y < 0 || y >= SECTION_HEIGHT || z < 0 || z >= SECTION_SIZE

      index = get_index(x, y, z)
      @blocks[index] = block

      # Update height map if placing a solid block
      if !block.air? && y > @height_map[get_biome_index(x, z)]
        @height_map[get_biome_index(x, z)] = y
      end
    end

    def get_block(x : Int32, y : Int32, z : Int32) : Block
      return Block.air if x < 0 || x >= SECTION_SIZE || y < 0 || y >= SECTION_HEIGHT || z < 0 || z >= SECTION_SIZE

      @blocks[get_index(x, y, z)]
    end

    def set_biome(x : Int32, z : Int32, biome_id : UInt8)
      return if x < 0 || x >= SECTION_SIZE || z < 0 || z >= SECTION_SIZE

      @biome[get_biome_index(x, z)] = biome_id
    end

    def get_biome(x : Int32, z : Int32) : UInt8
      return 1_u8 if x < 0 || x >= SECTION_SIZE || z < 0 || z >= SECTION_SIZE

      @biome[get_biome_index(x, z)]
    end

    def set_sky_light(x : Int32, y : Int32, z : Int32, level : UInt8)
      return if x < 0 || x >= SECTION_SIZE || y < 0 || y >= SECTION_HEIGHT || z < 0 || z >= SECTION_SIZE

      @sky_light[get_index(x, y, z)] = level
    end

    def get_sky_light(x : Int32, y : Int32, z : Int32) : UInt8
      return 0_u8 if x < 0 || x >= SECTION_SIZE || y < 0 || y >= SECTION_HEIGHT || z < 0 || z >= SECTION_SIZE

      @sky_light[get_index(x, y, z)]
    end

    def set_block_light(x : Int32, y : Int32, z : Int32, level : UInt8)
      return if x < 0 || x >= SECTION_SIZE || y < 0 || y >= SECTION_HEIGHT || z < 0 || z >= SECTION_SIZE

      @block_light[get_index(x, y, z)] = level
    end

    def get_block_light(x : Int32, y : Int32, z : Int32) : UInt8
      return 0_u8 if x < 0 || x >= SECTION_SIZE || y < 0 || y >= SECTION_HEIGHT || z < 0 || z >= SECTION_SIZE

      @block_light[get_index(x, y, z)]
    end

    def get_height(x : Int32, z : Int32) : Int32
      return 0 if x < 0 || x >= SECTION_SIZE || z < 0 || z >= SECTION_SIZE

      @height_map[get_biome_index(x, z)]
    end

    # Convert chunk data to bytes for network transmission
    # In src/world/chunk.cr - add this method to the Chunk class
    # Add this to your Chunk class in src/world/chunk.cr
    def to_bytes : Bytes
      # Beta 1.7.3 chunk format - simplified to avoid arithmetic issues
      total_size = 81920 # Fixed size for Beta 1.7.3

      buffer = Bytes.new(total_size, 0_u8)
      offset = 0

      # Write block IDs (32768 bytes) - all air for now
      block_ids_size = 32768
      offset += block_ids_size

      # Write metadata (16384 bytes) - all 0
      metadata_size = 16384
      offset += metadata_size

      # Write block light (16384 bytes) - all 0
      block_light_size = 16384
      offset += block_light_size

      # Write sky light (16384 bytes) - all 15 (full light) for top, 0 for bottom
      (0...SECTION_HEIGHT).each do |y|
        (0...SECTION_SIZE).each do |z|
          (0...SECTION_SIZE).each do |x|
            # Each byte contains sky light for two blocks (4 bits each)
            light_value = y > 64 ? 15_u8 : 0_u8 # Simple lighting: above y=64 is full light

            if x % 2 == 0
              # Even x - lower 4 bits
              buffer[offset] = light_value & 0x0F
            else
              # Odd x - upper 4 bits
              buffer[offset] |= (light_value & 0x0F) << 4
              offset += 1
            end
          end
        end
      end

      # Write biome data (256 bytes) - all plains (1)
      biome_size = 256
      (0...biome_size).each do |i|
        buffer[offset + i] = 1_u8
      end

      buffer
    end

    def empty? : Bool
      @blocks.all?(&.air?)
    end

    private def get_index(x : Int32, y : Int32, z : Int32) : Int32
      (y * SECTION_SIZE + z) * SECTION_SIZE + x
    end

    private def get_biome_index(x : Int32, z : Int32) : Int32
      z * SECTION_SIZE + x
    end
  end
end
