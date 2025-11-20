require "./block"
require "../crystal_mc/constants"

module CrystalMC::World
  class Chunk
    SECTION_SIZE   =  16
    SECTION_HEIGHT = 128

    property x : Int32
    property z : Int32
    property blocks : Bytes
    property metadata : Bytes
    property light_block : Bytes
    property light_sky : Bytes
    property biome_data : Bytes

    def initialize(@x : Int32, @z : Int32)
      # Initialize arrays
      # 16x128x16 = 32,768 blocks
      @blocks = Bytes.new(SECTION_SIZE * SECTION_HEIGHT * SECTION_SIZE, 0_u8)

      # Metadata: 4 bits per block = half the size
      @metadata = Bytes.new((SECTION_SIZE * SECTION_HEIGHT * SECTION_SIZE) // 2, 0_u8)

      # Light data: 4 bits per block
      @light_block = Bytes.new((SECTION_SIZE * SECTION_HEIGHT * SECTION_SIZE) // 2, 0_u8)
      @light_sky = Bytes.new((SECTION_SIZE * SECTION_HEIGHT * SECTION_SIZE) // 2, 0xF_u8) # Full skylight by default

      # Biome data: 16x16 = 256 bytes
      @biome_data = Bytes.new(SECTION_SIZE * SECTION_SIZE, 1_u8) # Default to plains biome
    end

    # Get block at local coordinates (0-15, 0-127, 0-15)
    def get_block(x : Int32, y : Int32, z : Int32) : Block
      return Block.air if out_of_bounds?(x, y, z)

      index = get_block_index(x, y, z)
      Block.new(@blocks[index], get_metadata(x, y, z))
    end

    # Set block at local coordinates
    def set_block(x : Int32, y : Int32, z : Int32, block : Block)
      return if out_of_bounds?(x, y, z)

      index = get_block_index(x, y, z)
      @blocks[index] = block.id
      set_metadata(x, y, z, block.metadata)
    end

    # Get block metadata (4 bits per block)
    def get_metadata(x : Int32, y : Int32, z : Int32) : UInt8
      return 0_u8 if out_of_bounds?(x, y, z)

      index = get_block_index(x, y, z)
      byte_index = index // 2

      if index.odd?
        (@metadata[byte_index] >> 4) & 0x0F
      else
        @metadata[byte_index] & 0x0F
      end
    end

    # Set block metadata
    def set_metadata(x : Int32, y : Int32, z : Int32, value : UInt8)
      return if out_of_bounds?(x, y, z)

      index = get_block_index(x, y, z)
      byte_index = index // 2

      if index.odd?
        @metadata[byte_index] = (@metadata[byte_index] & 0x0F) | ((value & 0x0F) << 4)
      else
        @metadata[byte_index] = (@metadata[byte_index] & 0xF0) | (value & 0x0F)
      end
    end

    # Get block light level
    def get_block_light(x : Int32, y : Int32, z : Int32) : UInt8
      return 0_u8 if out_of_bounds?(x, y, z)

      index = get_block_index(x, y, z)
      byte_index = index // 2

      if index.odd?
        (@light_block[byte_index] >> 4) & 0x0F
      else
        @light_block[byte_index] & 0x0F
      end
    end

    # Set block light level
    def set_block_light(x : Int32, y : Int32, z : Int32, value : UInt8)
      return if out_of_bounds?(x, y, z)

      index = get_block_index(x, y, z)
      byte_index = index // 2

      if index.odd?
        @light_block[byte_index] = (@light_block[byte_index] & 0x0F) | ((value & 0x0F) << 4)
      else
        @light_block[byte_index] = (@light_block[byte_index] & 0xF0) | (value & 0x0F)
      end
    end

    # Get sky light level
    def get_sky_light(x : Int32, y : Int32, z : Int32) : UInt8
      return 0_u8 if out_of_bounds?(x, y, z)

      index = get_block_index(x, y, z)
      byte_index = index // 2

      if index.odd?
        (@light_sky[byte_index] >> 4) & 0x0F
      else
        @light_sky[byte_index] & 0x0F
      end
    end

    # Set sky light level
    def set_sky_light(x : Int32, y : Int32, z : Int32, value : UInt8)
      return if out_of_bounds?(x, y, z)

      index = get_block_index(x, y, z)
      byte_index = index // 2

      if index.odd?
        @light_sky[byte_index] = (@light_sky[byte_index] & 0x0F) | ((value & 0x0F) << 4)
      else
        @light_sky[byte_index] = (@light_sky[byte_index] & 0xF0) | (value & 0x0F)
      end
    end

    # Get biome at x, z coordinates
    def get_biome(x : Int32, z : Int32) : UInt8
      return 1_u8 if x < 0 || x >= SECTION_SIZE || z < 0 || z >= SECTION_SIZE
      @biome_data[z * SECTION_SIZE + x]
    end

    # Set biome
    def set_biome(x : Int32, z : Int32, biome : UInt8)
      return if x < 0 || x >= SECTION_SIZE || z < 0 || z >= SECTION_SIZE
      @biome_data[z * SECTION_SIZE + x] = biome
    end

    # Convert to compressed chunk data for network transmission
    def to_bytes : Bytes
      # Calculate size: blocks + metadata + light_block + light_sky + biome
      size = @blocks.size + @metadata.size + @light_block.size + @light_sky.size + @biome_data.size

      io = IO::Memory.new(size)
      io.write(@blocks)
      io.write(@metadata)
      io.write(@light_block)
      io.write(@light_sky)
      io.write(@biome_data)

      io.to_slice
    end

    private def get_block_index(x : Int32, y : Int32, z : Int32) : Int32
      (y * SECTION_SIZE * SECTION_SIZE) + (z * SECTION_SIZE) + x
    end

    private def out_of_bounds?(x : Int32, y : Int32, z : Int32) : Bool
      x < 0 || x >= SECTION_SIZE ||
        y < 0 || y >= SECTION_HEIGHT ||
        z < 0 || z >= SECTION_SIZE
    end
  end
end
