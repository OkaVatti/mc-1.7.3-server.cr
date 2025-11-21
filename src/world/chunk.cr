require "./block"
require "../crystal_mc/constants"
require "compress/deflate"

module CrystalMC::World
  class Chunk
    property x : Int32
    property z : Int32
    property blocks : Array(Block)
    property biome : Array(UInt8)
    property sky_light : Array(UInt8)
    property block_light : Array(UInt8)
    property height_map : Array(Int32)
    property last_accessed : Time
    property dirty : Bool

    # Chunk dimensions for Beta 1.7.3
    SECTION_SIZE   =  16
    SECTION_HEIGHT = 128
    SECTION_COUNT  = SECTION_HEIGHT // 16
    TOTAL_BLOCKS   = SECTION_SIZE * SECTION_HEIGHT * SECTION_SIZE

    def initialize(@x : Int32, @z : Int32)
      @blocks = Array(Block).new(TOTAL_BLOCKS, Block.air)
      @biome = Array(UInt8).new(SECTION_SIZE * SECTION_SIZE, 1_u8) # Default to plains
      @sky_light = Array(UInt8).new(TOTAL_BLOCKS, 0_u8)
      @block_light = Array(UInt8).new(TOTAL_BLOCKS, 0_u8)
      @height_map = Array(Int32).new(SECTION_SIZE * SECTION_SIZE, 0)
      @last_accessed = Time.utc
      @dirty = false
    end

    def set_block(x : Int32, y : Int32, z : Int32, block : Block)
      return if x < 0 || x >= SECTION_SIZE || y < 0 || y >= SECTION_HEIGHT || z < 0 || z >= SECTION_SIZE

      index = get_index(x, y, z)
      @blocks[index] = block

      # Update height map if placing a solid block
      if !block.air? && y > @height_map[get_biome_index(x, z)]
        @height_map[get_biome_index(x, z)] = y
      end

      mark_dirty
    end

    def get_block(x : Int32, y : Int32, z : Int32) : Block
      return Block.air if x < 0 || x >= SECTION_SIZE || y < 0 || y >= SECTION_HEIGHT || z < 0 || z >= SECTION_SIZE

      @blocks[get_index(x, y, z)]
    end

    def set_biome(x : Int32, z : Int32, biome_id : UInt8)
      return if x < 0 || x >= SECTION_SIZE || z < 0 || z >= SECTION_SIZE

      @biome[get_biome_index(x, z)] = biome_id
      mark_dirty
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

    # Mark chunk as accessed (for cache management)
    def mark_accessed
      @last_accessed = Time.utc
    end

    # Mark chunk as modified (needs saving)
    def mark_dirty
      @dirty = true
      mark_accessed
    end

    # Check if chunk hasn't been accessed in a while
    def is_stale?(timeout : Time::Span = 5.minutes) : Bool
      Time.utc - @last_accessed > timeout
    end

    # Get chunk data as compressed bytes for network transmission
    def to_compressed_bytes : Bytes
      mark_accessed

      uncompressed_data = to_bytes

      # Compress the data
      compressed_io = IO::Memory.new
      Compress::Deflate::Writer.open(compressed_io, level: 1) do |deflate|
        deflate.write(uncompressed_data)
      end

      compressed_io.to_slice
    end

    # Convert chunk data to bytes for Beta 1.7.3 protocol
    def to_bytes : Bytes
      # Beta 1.7.3 chunk format: 81920 bytes uncompressed
      total_size = 81920
      buffer = Bytes.new(total_size, 0_u8)
      offset = 0

      # Write block IDs (32768 bytes)
      (0...SECTION_HEIGHT).each do |y|
        (0...SECTION_SIZE).each do |z|
          (0...SECTION_SIZE).each do |x|
            block = get_block(x, y, z)
            buffer[offset] = block.id
            offset += 1
          end
        end
      end

      # Write metadata (16384 bytes) - all 0 for now
      metadata_size = 16384
      offset += metadata_size

      # Write block light (16384 bytes) - all 0 for now
      block_light_size = 16384
      offset += block_light_size

      # Write sky light (16384 bytes)
      (0...SECTION_HEIGHT).each do |y|
        (0...SECTION_SIZE).each do |z|
          (0...SECTION_SIZE).each do |x|
            # Each byte contains sky light for two blocks (4 bits each)
            light_value = get_sky_light(x, y, z)

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

      # Write biome data (256 bytes)
      (0...SECTION_SIZE).each do |x|
        (0...SECTION_SIZE).each do |z|
          buffer[offset] = get_biome(x, z)
          offset += 1
        end
      end

      buffer
    end

    # Check if chunk is empty (all air)
    def empty? : Bool
      @blocks.all?(&.air?)
    end

    # Get memory usage estimate
    def memory_usage : Int64
      (@blocks.size + @biome.size + @sky_light.size + @block_light.size + @height_map.size).to_i64 * 4
    end

    def to_s(io : IO)
      io << "Chunk(#{@x}, #{@z}, blocks: #{@blocks.count { |b| !b.air? }}/#{TOTAL_BLOCKS})"
    end

    private def get_index(x : Int32, y : Int32, z : Int32) : Int32
      (y * SECTION_SIZE + z) * SECTION_SIZE + x
    end

    private def get_biome_index(x : Int32, z : Int32) : Int32
      z * SECTION_SIZE + x
    end
  end
end
