require "./chunk"
require "./block"
require "./perlin_noise"
require "../crystal_mc/constants"

module CrystalMC::World
  class ChunkGenerator
    property seed : Int64
    property noise : PerlinNoise
    property cave_noise : PerlinNoise

    # World generation constants
    SEA_LEVEL     = 62
    BEDROCK_LAYER =  0
    STONE_START   =  1
    STONE_END     =  5
    DIRT_DEPTH    =  3

    def initialize(@seed : Int64)
      @noise = PerlinNoise.new(@seed)
      @cave_noise = PerlinNoise.new(@seed + 1)
    end

    # Generate a chunk at given coordinates
    # In src/world/chunk_generator.cr - update the generate method
    def generate(chunk_x : Int32, chunk_z : Int32) : Chunk
      chunk = Chunk.new(chunk_x, chunk_z)

      # Generate simple terrain to avoid overflow
      generate_simple_terrain(chunk, chunk_x, chunk_z)

      # Skip caves and ores for now to reduce complexity
      # generate_caves(chunk, chunk_x, chunk_z)
      # generate_ores(chunk)

      # Simple lighting
      calculate_simple_lighting(chunk)

      chunk
    end

    private def generate_simple_terrain(chunk : Chunk, chunk_x : Int32, chunk_z : Int32)
      (0...Chunk::SECTION_SIZE).each do |x|
        (0...Chunk::SECTION_SIZE).each do |z|
          world_x = chunk_x * Chunk::SECTION_SIZE + x
          world_z = chunk_z * Chunk::SECTION_SIZE + z

          # Simple flat terrain at y=64
          height = 64

          # Generate layers
          (0..height).each do |y|
            block = if y == 0
                      Block.new(Block::BEDROCK, 0_u8)
                    elsif y < height - 4
                      Block.new(Block::STONE, 0_u8)
                    elsif y < height - 1
                      Block.new(Block::DIRT, 0_u8)
                    else
                      Block.new(Block::GRASS, 0_u8)
                    end
            chunk.set_block(x, y, z, block)
          end

          # Set biome to plains
          chunk.set_biome(x, z, 1_u8)
        end
      end
    end

    private def calculate_simple_lighting(chunk : Chunk)
      # Very simple lighting: everything above y=64 gets full sunlight
      (0...Chunk::SECTION_SIZE).each do |x|
        (0...Chunk::SECTION_SIZE).each do |z|
          (0...Chunk::SECTION_HEIGHT).each do |y|
            if y > 64
              chunk.set_sky_light(x, y, z, 15_u8)
            else
              chunk.set_sky_light(x, y, z, 0_u8)
            end
            chunk.set_block_light(x, y, z, 0_u8)
          end
        end
      end
    end

    private def get_block_for_height(y : Int32, terrain_height : Int32, x : Int32, z : Int32) : Block
      case y
      when BEDROCK_LAYER
        # Bedrock layer
        Block.new(Block::BEDROCK, 0_u8)
      when STONE_START..STONE_END
        # Mixed stone/bedrock
        if (x + y + z) % 5 == 0
          Block.new(Block::BEDROCK, 0_u8)
        else
          Block.new(Block::STONE, 0_u8)
        end
      when (STONE_END + 1)..(terrain_height - DIRT_DEPTH - 1)
        # Stone layer
        Block.new(Block::STONE, 0_u8)
      when (terrain_height - DIRT_DEPTH)...(terrain_height - 1)
        # Dirt layer
        Block.new(Block::DIRT, 0_u8)
      when terrain_height
        # Surface layer
        if terrain_height < SEA_LEVEL - 2
          Block.new(Block::SAND, 0_u8)
        elsif terrain_height > 85
          Block.new(Block::GRAVEL, 0_u8)
        else
          Block.new(Block::GRASS, 0_u8)
        end
      else
        Block.air
      end
    end

    private def get_height(x : Int32, z : Int32) : Int32
      # Multiple octaves for varied terrain
      continent = @noise.octave_noise(x * 0.001, 0.0, z * 0.001, 2) * 30
      hills = @noise.octave_noise(x * 0.01, 0.0, z * 0.01, 4) * 20
      detail = @noise.octave_noise(x * 0.05, 0.0, z * 0.05, 3) * 8

      base_height = 64
      height = base_height + continent + hills + detail

      height.to_i.clamp(5, Chunk::SECTION_HEIGHT - 1)
    end

    private def determine_biome(x : Int32, z : Int32) : UInt8
      temperature = @noise.noise(x * 0.005, 0.0, z * 0.005)
      humidity = @noise.noise(x * 0.005 + 1000, 0.0, z * 0.005 + 1000)

      # Use only Beta 1.7.3 biome IDs
      if temperature < -0.3
        12_u8 # Ice Plains
      elsif temperature > 0.3 && humidity < -0.3
        2_u8 # Desert
      elsif humidity > 0.3
        4_u8 # Forest
      else
        1_u8 # Plains
      end
    end

    private def generate_caves(chunk : Chunk, chunk_x : Int32, chunk_z : Int32)
      (0...Chunk::SECTION_SIZE).each do |x|
        (0...Chunk::SECTION_SIZE).each do |z|
          world_x = chunk_x * Chunk::SECTION_SIZE + x
          world_z = chunk_z * Chunk::SECTION_SIZE + z

          (5...Chunk::SECTION_HEIGHT - 5).each do |y|
            # Use 3D noise for caves
            cave_value = @cave_noise.octave_noise(
              world_x * 0.05,
              y * 0.05,
              world_z * 0.05,
              3
            )

            if cave_value > 0.6
              block = chunk.get_block(x, y, z)
              unless block.id == Block::BEDROCK
                chunk.set_block(x, y, z, Block.air)
              end
            end
          end
        end
      end
    end

    private def generate_ores(chunk : Chunk)
      random = Random.new(@seed + chunk.x * 31 + chunk.z * 17)

      # Coal ore
      generate_ore_vein(chunk, Block::COAL_ORE, 10, 20, 0, 128, random)

      # Iron ore
      generate_ore_vein(chunk, Block::IRON_ORE, 8, 10, 0, 64, random)

      # Gold ore
      generate_ore_vein(chunk, Block::GOLD_ORE, 6, 2, 0, 32, random)

      # Gravel patches
      generate_ore_vein(chunk, Block::GRAVEL, 16, 8, 0, 128, random)

      # Dirt patches
      generate_ore_vein(chunk, Block::DIRT, 16, 10, 0, 128, random)
    end

    private def generate_ore_vein(chunk : Chunk, ore_type : UInt8, vein_size : Int32,
                                  attempts : Int32, min_height : Int32, max_height : Int32,
                                  random : Random)
      attempts.times do
        x = random.rand(Chunk::SECTION_SIZE)
        y = random.rand(min_height...max_height)
        z = random.rand(Chunk::SECTION_SIZE)

        # Generate vein
        vein_size.times do
          dx = random.rand(-2..2)
          dy = random.rand(-2..2)
          dz = random.rand(-2..2)

          nx = x + dx
          ny = y + dy
          nz = z + dz

          next if nx < 0 || nx >= Chunk::SECTION_SIZE
          next if ny < 0 || ny >= Chunk::SECTION_HEIGHT
          next if nz < 0 || nz >= Chunk::SECTION_SIZE

          block = chunk.get_block(nx, ny, nz)
          if block.id == Block::STONE
            chunk.set_block(nx, ny, nz, Block.new(ore_type, 0_u8))
          end
        end
      end
    end

    private def calculate_lighting(chunk : Chunk)
      # Simple lighting: full sunlight above ground, no light below
      (0...Chunk::SECTION_SIZE).each do |x|
        (0...Chunk::SECTION_SIZE).each do |z|
          # Find the highest solid block
          highest_block = 0
          (0...Chunk::SECTION_HEIGHT).reverse_each do |y|
            block = chunk.get_block(x, y, z)
            unless block.air?
              highest_block = y
              break
            end
          end

          # Set lighting
          (0...Chunk::SECTION_HEIGHT).each do |y|
            if y > highest_block
              chunk.set_sky_light(x, y, z, 15_u8) # Full sunlight
            else
              chunk.set_sky_light(x, y, z, 0_u8) # No sunlight
            end
            chunk.set_block_light(x, y, z, 0_u8) # No block light for now
          end
        end
      end
    end
  end
end
