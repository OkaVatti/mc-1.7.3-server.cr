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
    @time_of_day : Int64

    def initialize(name : String? = nil, seed : Int64? = nil)
      # Initialize ALL instance variables FIRST
      @chunk_load_mutex = Mutex.new
      @chunks = {} of ChunkCoord => Chunk
      @spawn_x = 0
      @spawn_y = 64
      @spawn_z = 0
      @time = 0_i64
      @time_of_day = 6000_i64

      # Set name and seed
      @name = name || "New World"
      @seed = seed ? seed.to_i64 : Random::Secure.rand(Int32::MAX).to_i64

      # Initialize chunk generator with the actual seed
      @chunk_generator = ChunkGenerator.new(@seed.to_i32)

      puts "🌍 Creating world '#{@name}' with seed: #{@seed}"
    end

    def get_chunk(chunk_x : Int32, chunk_z : Int32) : Chunk?
      coord = ChunkCoord.new(chunk_x, chunk_z)

      @chunk_load_mutex.synchronize do
        @chunks[coord]? || load_chunk(chunk_x, chunk_z)
      end
    end

    def load_chunk(chunk_x : Int32, chunk_z : Int32) : Chunk
      coord = ChunkCoord.new(chunk_x, chunk_z)

      # Generate the chunk
      chunk = @chunk_generator.generate(chunk_x, chunk_z)
      @chunks[coord] = chunk

      puts "Generated chunk at #{chunk_x}, #{chunk_z}"
      chunk
    end

    def unload_chunk(chunk_x : Int32, chunk_z : Int32)
      coord = ChunkCoord.new(chunk_x, chunk_z)

      @chunk_load_mutex.synchronize do
        if chunk = @chunks.delete(coord)
          # TODO: Save chunk to disk
          puts "Unloaded chunk at #{chunk_x}, #{chunk_z}"
        end
      end
    end

    def get_block(x : Int32, y : Int32, z : Int32) : Block
      return Block.air if y < 0 || y >= Constants::WORLD_HEIGHT

      chunk_x, local_x = world_to_chunk_coord(x)
      chunk_z, local_z = world_to_chunk_coord(z)

      chunk = get_chunk(chunk_x, chunk_z)
      return Block.air unless chunk

      chunk.get_block(local_x, y, local_z)
    end

    def set_block(x : Int32, y : Int32, z : Int32, block : Block)
      return if y < 0 || y >= Constants::WORLD_HEIGHT

      chunk_x, local_x = world_to_chunk_coord(x)
      chunk_z, local_z = world_to_chunk_coord(z)

      chunk = get_chunk(chunk_x, chunk_z)
      return unless chunk

      chunk.set_block(local_x, y, local_z, block)
    end

    def is_solid(x : Int32, y : Int32, z : Int32) : Bool
      get_block(x, y, z).solid?
    end

    def tick
      @time += 1
      @time_of_day = (@time % 24000)

      # Update lighting for loaded chunks at dawn/dusk
      if @time % 100 == 0 # Update lighting every 5 seconds
        update_lighting_for_time_of_day
      end

      # Auto-save chunks periodically
      if @time % 6000 == 0 # Save every 5 minutes
        save_loaded_chunks
      end
    end

    # Get current sky light level based on time of day
    def get_sky_light_level : UInt8
      case @time_of_day
      when 0..12000 # Daytime
        15_u8
      when 12000..14000 # Sunset
        (15 - ((@time_of_day - 12000) // 200).to_u8).clamp(7_u8, 15_u8).to_u8
      when 14000..22000 # Nighttime
        7_u8
      else # Sunrise
        (7 + ((@time_of_day - 22000) // 200).to_u8).clamp(7_u8, 15_u8).to_u8
      end
    end

    # Get moon phase for night sky
    def get_moon_phase : Int32
      (time // 24000) % 8
    end

    # Check if it's currently raining (simplified)
    def is_raining? : Bool
      false # Would be based on biome and random factors in a real implementation
    end

    # Get current time of day in readable format
    def get_time_of_day_string : String
      case @time_of_day
      when 0..6000     ; "Morning"
      when 6000..12000 ; "Noon"
      when 12000..18000; "Evening"
      else               "Night"
      end
    end

    # Get loaded chunks
    def loaded_chunks : Array(Chunk)
      @chunks.values
    end

    # Get chunk count
    def chunk_count : Int32
      @chunks.size
    end

    # Get chunks in radius
    def get_chunks_in_radius(center_x : Int32, center_z : Int32, radius : Int32) : Array(Chunk)
      chunks = [] of Chunk

      (-radius..radius).each do |dx|
        (-radius..radius).each do |dz|
          chunk_x = center_x + dx
          chunk_z = center_z + dz

          if chunk = get_chunk(chunk_x, chunk_z)
            chunks << chunk
          end
        end
      end

      chunks
    end

    private def world_to_chunk_coord(coord : Int32) : Tuple(Int32, Int32)
      chunk_coord = coord // Constants::CHUNK_WIDTH
      local_coord = coord % Constants::CHUNK_WIDTH

      if local_coord < 0
        local_coord += Constants::CHUNK_WIDTH
      end

      {chunk_coord, local_coord}
    end

    private def update_lighting_for_time_of_day
      sky_light = get_sky_light_level
      # In a full implementation, we'd update sky light for all loaded chunks
      # This is simplified for now
    end

    private def save_loaded_chunks
      # In a full implementation, we'd save chunks to region files
    end

    # Helper struct for chunk coordinates
    record ChunkCoord, x : Int32, z : Int32
  end
end
