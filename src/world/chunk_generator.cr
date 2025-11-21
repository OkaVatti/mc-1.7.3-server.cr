require "./chunk"
require "./block"
require "./perlin_noise"
require "../crystal_mc/constants"
require "random"

module CrystalMC::World
  class ChunkGenerator
    property seed : Int32
    @noise : PerlinNoise
    @random : Random

    # World generation constants
    SEA_LEVEL     = 62
    BEDROCK_LAYER =  0
    STONE_START   =  1
    STONE_END     =  5
    DIRT_DEPTH    =  3

    def initialize(seed : Int32)
      @seed = seed
      @noise = PerlinNoise.new(@seed)
      @random = Random.new(@seed.to_i64.abs.to_u64)
    end

    def generate(chunk_x : Int32, chunk_z : Int32) : Chunk
      chunk = Chunk.new(chunk_x, chunk_z)

      # Generate simple flat terrain for now
      16.times do |x|
        16.times do |z|
          # Simple flat terrain
          chunk.set_block(x, 0, z, Block.stone)
          (1..3).each { |y| chunk.set_block(x, y, z, Block.dirt) }
          chunk.set_block(x, 4, z, Block.grass)

          # Set basic lighting
          256.times do |y|
            if y > 4
              chunk.set_sky_light(x, y, z, 15_u8)
            else
              chunk.set_sky_light(x, y, z, 0_u8)
            end
            chunk.set_block_light(x, y, z, 0_u8)
          end
        end
      end

      chunk
    end

    def generate(chunk_x : Int32, chunk_z : Int32) : Chunk
      chunk = Chunk.new(chunk_x, chunk_z)

      # Use the enhanced terrain generation
      generate_terrain_with_noise(chunk, chunk_x, chunk_z)

      # Generate ores and other features
      generate_ores(chunk, chunk_x, chunk_z)

      # Calculate lighting
      calculate_improved_lighting(chunk)

      chunk
    end

    private def generate_terrain_with_noise(chunk : Chunk, chunk_x : Int32, chunk_z : Int32)
      16.times do |x|
        16.times do |z|
          # Calculate world coordinates for noise
          world_x = chunk_x * 16 + x
          world_z = chunk_z * 16 + z

          # Get terrain height using multiple octaves of noise
          height = get_terrain_height(world_x, world_z)

          # Generate underground layers
          generate_underground_layers(chunk, x, z, height)

          # Generate surface layer
          generate_surface_layer(chunk, x, z, height, world_x, world_z)

          # Set biome
          biome = determine_biome(world_x, world_z, height)
          chunk.set_biome(x, z, biome)
        end
      end
    end

    private def get_terrain_height(world_x : Int32, world_z : Int32) : Int32
      # Multiple octaves for varied terrain
      continent = @noise.octave_noise(world_x * 0.001, 0.0, world_z * 0.001, 2) * 30
      hills = @noise.octave_noise(world_x * 0.01, 0.0, world_z * 0.01, 4) * 20
      detail = @noise.octave_noise(world_x * 0.05, 0.0, world_z * 0.05, 3) * 8

      base_height = SEA_LEVEL
      height = base_height + continent + hills + detail

      height.to_i.clamp(5, 255) # Use actual world height limit
    end

    private def generate_underground_layers(chunk : Chunk, x : Int32, z : Int32, height : Int32)
      (0..height).each do |y|
        block = get_block_for_depth(y, height, x, z)
        chunk.set_block(x, y, z, block)
      end
    end

    private def get_block_for_depth(y : Int32, terrain_height : Int32, x : Int32, z : Int32) : Block
      case y
      when BEDROCK_LAYER
        Block.new(Block::BEDROCK, 0_u8)
      when STONE_START..STONE_END
        # Mixed stone/bedrock transition
        if (x + y + z) % 5 == 0
          Block.new(Block::BEDROCK, 0_u8)
        else
          Block.new(Block::STONE, 0_u8)
        end
      when (STONE_END + 1)..(terrain_height - DIRT_DEPTH - 1)
        Block.new(Block::STONE, 0_u8)
      when (terrain_height - DIRT_DEPTH)...(terrain_height - 1)
        Block.new(Block::DIRT, 0_u8)
      when terrain_height
        # Surface will be set separately
        Block.air
      else
        Block.air
      end
    end

    private def generate_surface_layer(chunk : Chunk, x : Int32, z : Int32, height : Int32, world_x : Int32, world_z : Int32)
      if height < SEA_LEVEL - 2
        # Beach or ocean floor
        chunk.set_block(x, height, z, Block.new(Block::SAND, 0_u8))
      elsif height > 85
        # Mountain top
        chunk.set_block(x, height, z, Block.new(Block::GRAVEL, 0_u8))
      else
        # Normal terrain
        chunk.set_block(x, height, z, Block.new(Block::GRASS, 0_u8))
      end
    end

    private def determine_biome(world_x : Int32, world_z : Int32, height : Int32) : UInt8
      temperature = @noise.noise(world_x * 0.005, 0.0, world_z * 0.005)
      humidity = @noise.noise(world_x * 0.005 + 1000, 0.0, world_z * 0.005 + 1000)

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

    private def generate_ores(chunk : Chunk, chunk_x : Int32, chunk_z : Int32)
      # Generate coal ore
      generate_ore_vein(chunk, Block::COAL_ORE, 20, 0, 128, 10)

      # Generate iron ore
      generate_ore_vein(chunk, Block::IRON_ORE, 8, 0, 64, 5)

      # Generate gold ore
      generate_ore_vein(chunk, Block::GOLD_ORE, 6, 0, 32, 2)
    end

    private def generate_ore_vein(chunk : Chunk, ore_type : UInt8, attempts : Int32, min_y : Int32, max_y : Int32, vein_size : Int32)
      attempts.times do
        x = @random.rand(16)
        y = @random.rand(min_y...max_y)
        z = @random.rand(16)

        # Only place ore in stone
        if chunk.get_block(x, y, z).id == Block::STONE
          # Generate small vein
          vein_size.times do
            dx = @random.rand(-1..1)
            dy = @random.rand(-1..1)
            dz = @random.rand(-1..1)

            nx = x + dx
            ny = y + dy
            nz = z + dz

            next if nx < 0 || nx >= 16
            next if ny < 0 || ny >= 256
            next if nz < 0 || nz >= 16

            if chunk.get_block(nx, ny, nz).id == Block::STONE
              chunk.set_block(nx, ny, nz, Block.new(ore_type, 0_u8))
            end
          end
        end
      end
    end

    private def calculate_improved_lighting(chunk : Chunk)
      16.times do |x|
        16.times do |z|
          # Find the highest solid block for this column
          highest_block = find_highest_block(chunk, x, z)

          256.times do |y|
            if y > highest_block
              # Above ground - full sunlight
              chunk.set_sky_light(x, y, z, 15_u8)
            elsif y == highest_block
              # At ground level - reduced light
              chunk.set_sky_light(x, y, z, 14_u8)
            else
              # Underground - no natural light
              chunk.set_sky_light(x, y, z, 0_u8)
            end

            # No block light for now (would be from torches, lava, etc.)
            chunk.set_block_light(x, y, z, 0_u8)
          end
        end
      end
    end

    private def find_highest_block(chunk : Chunk, x : Int32, z : Int32) : Int32
      255.downto(0) do |y|
        block = chunk.get_block(x, y, z)
        unless block.air? || block.transparent?
          return y
        end
      end
      0
    end
  end
end
