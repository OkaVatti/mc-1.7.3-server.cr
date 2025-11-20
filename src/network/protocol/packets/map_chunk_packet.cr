require "./packet"
require "./protocol_helper"
require "compress/zlib"

module CrystalMC::Network::Protocol
  class MapChunkPacket < Packet
    property x : Int32
    property z : Int32
    property ground_up_continuous : Bool
    property primary_bit_map : Int16
    property add_bit_map : Int16
    property compressed_size : Int32
    property compressed_data : Bytes

    def initialize(
      @x : Int32 = 0,
      @z : Int32 = 0,
      @ground_up_continuous : Bool = true,
      @primary_bit_map : Int16 = -1_i16, # All sections present
      @add_bit_map : Int16 = 0_i16,      # No additional data in Beta 1.7.3
      @compressed_size : Int32 = 0,
      @compressed_data : Bytes = Bytes.empty
    )
    end

    def packet_id : UInt8
      0x33_u8
    end

    def read(io : IO)
      @x = ProtocolHelper.read_int(io)
      @z = ProtocolHelper.read_int(io)
      @ground_up_continuous = ProtocolHelper.read_bool(io)
      @primary_bit_map = ProtocolHelper.read_short(io)
      @add_bit_map = ProtocolHelper.read_short(io)
      @compressed_size = ProtocolHelper.read_int(io)
      @compressed_data = Bytes.new(@compressed_size)
      io.read_fully(@compressed_data)
    end

    def write(io : IO)
      ProtocolHelper.write_ubyte(io, packet_id)
      ProtocolHelper.write_int(io, @x)
      ProtocolHelper.write_int(io, @z)
      ProtocolHelper.write_bool(io, @ground_up_continuous)
      ProtocolHelper.write_short(io, @primary_bit_map)
      ProtocolHelper.write_short(io, @add_bit_map)
      ProtocolHelper.write_int(io, @compressed_size)
      io.write(@compressed_data)
    end

    def handle(handler : NetHandler)
      # Client doesn't send this packet
    end

    def clone : Packet
      MapChunkPacket.new(@x, @z, @ground_up_continuous, @primary_bit_map, @add_bit_map, @compressed_size, @compressed_data)
    end

    # Helper to create packet from chunk
    def self.from_chunk(chunk : CrystalMC::World::Chunk) : MapChunkPacket
      # Create a simple fallback chunk packet
      create_fallback_chunk(chunk)
    rescue ex : Exception
      puts "💥 Error creating chunk packet: #{ex.message}"
      create_empty_chunk(chunk)
    end

    private def self.create_fallback_chunk(chunk : CrystalMC::World::Chunk) : MapChunkPacket
      # Create a simple chunk with just air blocks
      uncompressed_size = 81920 # Standard Beta 1.7.3 chunk size
      uncompressed = Bytes.new(uncompressed_size, 0_u8)

      # Set biome data (last 256 bytes) to plains (1)
      biome_start = uncompressed_size - 256
      (biome_start...uncompressed_size).each do |i|
        uncompressed[i] = 1_u8 # Plains biome
      end

      # Try to compress with size limits
      compressed_io = IO::Memory.new
      begin
        # Use integer compression level instead of symbol
        # BEST_SPEED = 1, DEFAULT_COMPRESSION = -1, BEST_COMPRESSION = 9
        Compress::Deflate::Writer.open(compressed_io, level: 1) do |deflate| # Changed :best_speed to 1
        # Write in smaller chunks to avoid overflow
          chunk_size = 4096
          offset = 0
          while offset < uncompressed_size
            bytes_to_write = Math.min(chunk_size, uncompressed_size - offset)
            deflate.write(uncompressed[offset, bytes_to_write])
            offset += bytes_to_write
          end
        end
      rescue ex
        puts "⚠️  Compression failed, using uncompressed data: #{ex.message}"
        # If compression fails, use uncompressed data
        compressed_io = IO::Memory.new(uncompressed)
      end

      compressed_data = compressed_io.to_slice
      compressed_size = Math.min(compressed_data.size, Int32::MAX).to_i32

      new(
        x: chunk.x * 16,
        z: chunk.z * 16,
        ground_up_continuous: true,
        primary_bit_map: 0xFFFF.to_i16,
        add_bit_map: 0_i16,
        compressed_size: compressed_size,
        compressed_data: compressed_data
      )
    end

    private def self.create_empty_chunk(chunk : CrystalMC::World::Chunk) : MapChunkPacket
      # Create absolutely minimal chunk data (just biome)
      minimal_data = Bytes.new(256, 1_u8) # All plains biome

      compressed_io = IO::Memory.new
      Compress::Deflate::Writer.open(compressed_io, level: 1) do |deflate| # Changed :best_speed to 1
        deflate.write(minimal_data)
      end

      compressed_data = compressed_io.to_slice

      new(
        x: chunk.x * 16,
        z: chunk.z * 16,
        ground_up_continuous: true,
        primary_bit_map: 0xFFFF.to_i16,
        add_bit_map: 0_i16,
        compressed_size: compressed_data.size.to_i32,
        compressed_data: compressed_data
      )
    end
  end
end
