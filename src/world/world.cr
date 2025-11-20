require "./chunk"
require "./chunk_generator"
require "./block"
require "../crystal_mc/constants"

module CrystalMC::World
  class World
    property name : String
    property seed : Int64
    property spawn_x : Int32
    property spawn_y : Int32
    property spawn_z : Int32
    property time : Int64

    @chunks : Hash(ChunkCoord, Chunk)
    @chunk_generator : ChunkGenerator
    @chunk_load_mutex : Mutex

    def initialize(@name : String, @seed : Int64 = Random.new.next_int.to_i64)
      @spawn_x = 0
      @spawn_y = 64
      @spawn_z = 0
      @time = 0_i64
      @chunks = {} of ChunkCoord => Chunk
      @chunk_generator = ChunkGenerator.new(@seed)
      @chunk_load_mutex = Mutex.new

      puts "Created world '#{@name}' with seed: #{@seed}"
    end

    # Get or load a chunk
    def get_chunk(chunk_x : Int32, chunk_z : Int32) : Chunk?
      coord = ChunkCoord.new(chunk_x, chunk_z)

      @chunk_load_mutex.synchronize do
        @chunks[coord]? || load_chunk(chunk_x, chunk_z)
      end
    end

    # Load a chunk (generate if doesn't exist)
    def load_chunk(chunk_x : Int32, chunk_z : Int32) : Chunk
      coord = ChunkCoord.new(chunk_x, chunk_z)

      # Try to load from disk (TODO: implement region file loading)
      # For now, just generate
      chunk = @chunk_generator.generate(chunk_x, chunk_z)
      @chunks[coord] = chunk

      puts "Generated chunk at #{chunk_x}, #{chunk_z}"
      chunk
    end

    # Unload a chunk
    def unload_chunk(chunk_x : Int32, chunk_z : Int32)
      coord = ChunkCoord.new(chunk_x, chunk_z)

      @chunk_load_mutex.synchronize do
        if chunk = @chunks.delete(coord)
          # TODO: Save chunk to disk
          puts "Unloaded chunk at #{chunk_x}, #{chunk_z}"
        end
      end
    end

    # Get block at world coordinates
    def get_block(x : Int32, y : Int32, z : Int32) : Block
      return Block.air if y < 0 || y >= WORLD_HEIGHT

      chunk_x, local_x = world_to_chunk_coord(x)
      chunk_z, local_z = world_to_chunk_coord(z)

      chunk = get_chunk(chunk_x, chunk_z)
      return Block.air unless chunk

      chunk.get_block(local_x, y, local_z)
    end

    # Set block at world coordinates
    def set_block(x : Int32, y : Int32, z : Int32, block : Block)
      return if y < 0 || y >= WORLD_HEIGHT

      chunk_x, local_x = world_to_chunk_coord(x)
      chunk_z, local_z = world_to_chunk_coord(z)

      chunk = get_chunk(chunk_x, chunk_z)
      return unless chunk

      chunk.set_block(local_x, y, local_z, block)
    end

    # Check if block is solid
    def is_solid(x : Int32, y : Int32, z : Int32) : Bool
      get_block(x, y, z).solid?
    end

    # Tick the world
    def tick
      @time += 1

      # TODO: Update entities, redstone, etc.
    end

    # Get loaded chunks
    def loaded_chunks : Array(Chunk)
      @chunks.values
    end

    # Get chunk count
    def chunk_count : Int32
      @chunks.size
    end

    # Convert world coordinate to chunk coordinate and local coordinate
    private def world_to_chunk_coord(coord : Int32) : Tuple(Int32, Int32)
      chunk_coord = coord.floor_div(CHUNK_SIZE)
      local_coord = coord.remainder(CHUNK_SIZE)
      local_coord += CHUNK_SIZE if local_coord < 0

      {chunk_coord, local_coord}
    end

    # Helper struct for chunk coordinates
    record ChunkCoord, x : Int32, z : Int32
  end
end
