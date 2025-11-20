module CrystalMC::World
  class Chunk
    SECTION_SIZE   =  16
    SECTION_HEIGHT = 128
    SECTION_COUNT  =   8 # 128 / 16 = 8 sections

    property x : Int32
    property z : Int32
    @blocks : Array(Array(Array(Block)))      # [x][z][y]
    @biomes : Array(Array(UInt8))             # [x][z]
    @sky_light : Array(Array(Array(UInt8)))   # [x][z][y]
    @block_light : Array(Array(Array(UInt8))) # [x][z][y]

    def initialize(@x : Int32, @z : Int32)
      @blocks = Array.new(SECTION_SIZE) do
        Array.new(SECTION_SIZE) do
          Array.new(SECTION_HEIGHT) { Block.air }
        end
      end
      @biomes = Array.new(SECTION_SIZE) { Array.new(SECTION_SIZE) { 1_u8 } } # Default to plains
      @sky_light = Array.new(SECTION_SIZE) do
        Array.new(SECTION_SIZE) do
          Array.new(SECTION_HEIGHT) { 0_u8 }
        end
      end
      @block_light = Array.new(SECTION_SIZE) do
        Array.new(SECTION_SIZE) do
          Array.new(SECTION_HEIGHT) { 0_u8 }
        end
      end
    end

    def set_block(x : Int32, y : Int32, z : Int32, block : Block)
      return if x < 0 || x >= SECTION_SIZE
      return if y < 0 || y >= SECTION_HEIGHT
      return if z < 0 || z >= SECTION_SIZE
      @blocks[x][z][y] = block
    end

    def get_block(x : Int32, y : Int32, z : Int32) : Block
      return Block.air if x < 0 || x >= SECTION_SIZE
      return Block.air if y < 0 || y >= SECTION_HEIGHT
      return Block.air if z < 0 || z >= SECTION_SIZE
      @blocks[x][z][y]
    end

    def set_biome(x : Int32, z : Int32, biome : UInt8)
      return if x < 0 || x >= SECTION_SIZE
      return if z < 0 || z >= SECTION_SIZE
      @biomes[x][z] = biome
    end

    def set_sky_light(x : Int32, y : Int32, z : Int32, light : UInt8)
      return if x < 0 || x >= SECTION_SIZE
      return if y < 0 || y >= SECTION_HEIGHT
      return if z < 0 || z >= SECTION_SIZE
      @sky_light[x][z][y] = light
    end

    def set_block_light(x : Int32, y : Int32, z : Int32, light : UInt8)
      return if x < 0 || x >= SECTION_SIZE
      return if y < 0 || y >= SECTION_HEIGHT
      return if z < 0 || z >= SECTION_SIZE
      @block_light[x][z][y] = light
    end

    # Convert chunk to byte array for network transmission
    def to_bytes : Bytes
      # In Beta 1.7.3, chunk data consists of:
      # - Block IDs (32768 bytes)
      # - Metadata (16384 bytes - 4 bits per block)
      # - Block light (16384 bytes - 4 bits per block)
      # - Sky light (16384 bytes - 4 bits per block)
      # - Biome data (256 bytes)
      # Total: 81920 bytes

      data = Bytes.new(81920)
      offset = 0

      # 1. Block IDs (32768 bytes)
      (0...SECTION_HEIGHT).each do |y|
        (0...SECTION_SIZE).each do |z|
          (0...SECTION_SIZE).each do |x|
            block = get_block(x, y, z)
            data[offset] = block.id
            offset += 1
          end
        end
      end

      # 2. Metadata (16384 bytes - packed as 4 bits per block)
      (0...SECTION_HEIGHT).each do |y|
        (0...SECTION_SIZE).each do |z|
          (0...SECTION_SIZE).each do |x|
            block_index = y * 256 + z * 16 + x
            byte_index = 32768 + block_index // 2
            block = get_block(x, y, z)

            if block_index.even?
              # Even index: metadata in lower 4 bits
              data[byte_index] = (data[byte_index] & 0xF0) | (block.metadata & 0x0F)
            else
              # Odd index: metadata in upper 4 bits
              data[byte_index] = (data[byte_index] & 0x0F) | ((block.metadata & 0x0F) << 4)
            end
          end
        end
      end

      # 3. Block light (same structure as metadata)
      offset = 32768 + 16384 # Start of block light
      (0...SECTION_HEIGHT).each do |y|
        (0...SECTION_SIZE).each do |z|
          (0...SECTION_SIZE).each do |x|
            block_index = y * 256 + z * 16 + x
            byte_index = offset + block_index // 2
            light = @block_light[x][z][y]

            if block_index.even?
              data[byte_index] = (data[byte_index] & 0xF0) | (light & 0x0F)
            else
              data[byte_index] = (data[byte_index] & 0x0F) | ((light & 0x0F) << 4)
            end
          end
        end
      end

      # 4. Sky light (same structure as metadata)
      offset = 32768 + 16384 + 16384 # Start of sky light
      (0...SECTION_HEIGHT).each do |y|
        (0...SECTION_SIZE).each do |z|
          (0...SECTION_SIZE).each do |x|
            block_index = y * 256 + z * 16 + x
            byte_index = offset + block_index // 2
            light = @sky_light[x][z][y]

            if block_index.even?
              data[byte_index] = (data[byte_index] & 0xF0) | (light & 0x0F)
            else
              data[byte_index] = (data[byte_index] & 0x0F) | ((light & 0x0F) << 4)
            end
          end
        end
      end

      # 5. Biome data (256 bytes)
      offset = 32768 + 16384 + 16384 + 16384 # Start of biome data
      (0...SECTION_SIZE).each do |z|
        (0...SECTION_SIZE).each do |x|
          data[offset] = @biomes[x][z]
          offset += 1
        end
      end

      data
    end
  end
end
