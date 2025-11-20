require "./chunk"
require "./block"
require "../crystal_mc/constants"

module CrystalMC::World
  class ChunkGenerator
    property seed : Int64

    def initialize(@seed : Int64)
    end

    # Generate a chunk at given coordinates
    def generate(chunk_x : Int32, chunk_z : Int32) : Chunk
      chunk = Chunk.new(chunk_x, chunk_z)

      # Generate terrain
      generate_terrain(chunk, chunk_x, chunk_z)

      # Calculate lighting
      calculate_lighting(chunk)

      chunk
    end

    private def generate_terrain(chunk : Chunk, chunk_x : Int32, chunk_z : Int32)
      # Simple terrain generation for now
      # We'll implement proper noise-based generation later

      (0...Chunk::SECTION_SIZE).each do |x|
        (0...Chunk::SECTION_SIZE).each do |z|
          world_x = chunk_x * Chunk::SECTION_SIZE + x
          world_z = chunk_z * Chunk::SECTION_SIZE + z

          # Simple height calculation using pseudo-random
          height = get_height(world_x, world_z)

          # Generate layers
          (0...height).each do |y|
            block = get_block_for_height(y, height)
            chunk.set_block(x, y, z, block)
          end

          # Set biome (1 = Plains)
          chunk.set_biome(x, z, 1_u8)
        end
      end
    end

    private def get_height(x : Int32, z : Int32) : Int32
      # Simple pseudo-random height generation
      # In a real implementation, use Perlin/Simplex noise
      hash = (x * 374761393 + z * 668265263 + @seed) ^ (@seed >> 13)
      hash = (hash ^ (hash >> 15)) * 1274126177

      base_height = 64
      variation = ((hash.abs % 16) - 8)

      (base_height + variation).clamp(5, 120)
    end

    private def get_block_for_height(y : Int32, terrain_height : Int32) : Block
      if y == 0
        # Bedrock at bottom
        Block.new(Block::BEDROCK, 0_u8)
      elsif y < terrain_height - 4
        # Stone underground
        Block.new(Block::STONE, 0_u8)
      elsif y < terrain_height - 1
        # Dirt layer
        Block.new(Block::DIRT, 0_u8)
      elsif y == terrain_height - 1
        # Grass on top
        if terrain_height < SEA_LEVEL
          Block.new(Block::SAND, 0_u8)
        else
          Block.new(Block::GRASS, 0_u8)
        end
      else
        # Air above
        Block.air
      end
    end

    private def calculate_lighting(chunk : Chunk)
      # Calculate skylight (simplified for now)
      (0...Chunk::SECTION_SIZE).each do |x|
        (0...Chunk::SECTION_SIZE).each do |z|
          # Find highest non-transparent block
          highest_y = Chunk::SECTION_HEIGHT - 1

          (0...Chunk::SECTION_HEIGHT).reverse_each do |y|
            block = chunk.get_block(x, y, z)

            if block.transparent?
              # Full skylight for transparent blocks above ground
              chunk.set_sky_light(x, y, z, 15_u8)
            else
              # Block found, stop here
              highest_y = y
              break
            end
          end

          # Darken blocks below highest solid block
          (0..highest_y).each do |y|
            chunk.set_sky_light(x, y, z, 0_u8)
          end
        end
      end
    end
  end
end
