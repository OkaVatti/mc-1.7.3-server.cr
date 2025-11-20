require "./packet"
require "./protocol_helper"
require "compress/gzip"

module CrystalMC::Network::Protocol
  abstract class MapChunkPacket < Packet
    property x : Int32
    property y : Int16
    property z : Int32
    property size_x : Int8
    property size_y : Int8
    property size_z : Int8
    property compressed_data : Bytes

    def initialize(
      @x : Int32 = 0,
      @y : Int16 = 0_i16,
      @z : Int32 = 0,
      @size_x : Int8 = 15_i8,
      @size_y : Int8 = 127_i8,
      @size_z : Int8 = 15_i8,
      @compressed_data : Bytes = Bytes.empty
    )
    end

    def packet_id : UInt8
      0x33_u8
    end

    def read(io : IO)
      @x = ProtocolHelper.read_int(io)
      @y = ProtocolHelper.read_short(io)
      @z = ProtocolHelper.read_int(io)
      @size_x = ProtocolHelper.read_byte(io)
      @size_y = ProtocolHelper.read_byte(io)
      @size_z = ProtocolHelper.read_byte(io)

      compressed_size = ProtocolHelper.read_int(io)
      @compressed_data = Bytes.new(compressed_size)
      io.read_fully(@compressed_data)
    end

    def write(io : IO)
      ProtocolHelper.write_ubyte(io, packet_id)
      ProtocolHelper.write_int(io, @x)
      ProtocolHelper.write_short(io, @y)
      ProtocolHelper.write_int(io, @z)
      ProtocolHelper.write_byte(io, @size_x)
      ProtocolHelper.write_byte(io, @size_y)
      ProtocolHelper.write_byte(io, @size_z)
      ProtocolHelper.write_int(io, @compressed_data.size)
      io.write(@compressed_data)
    end

    def handle(handler : NetHandler)
      # Client doesn't send this packet
    end

    # Helper to create packet from chunk
    def self.from_chunk(chunk : CrystalMC::World::Chunk) : MapChunkPacket
      # Get uncompressed chunk data
      uncompressed = chunk.to_bytes

      # Compress with GZip
      compressed_io = IO::Memory.new
      Compress::Gzip::Writer.open(compressed_io) do |gzip|
        gzip.write(uncompressed)
      end
      compressed_data = compressed_io.to_slice

      new(
        x: chunk.x * 16,
        y: 0_i16,
        z: chunk.z * 16,
        size_x: 15_i8,
        size_y: 127_i8,
        size_z: 15_i8,
        compressed_data: compressed_data
      )
    end
  end
end
