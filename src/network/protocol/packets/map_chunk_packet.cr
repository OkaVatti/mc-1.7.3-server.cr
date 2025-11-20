# src/network/protocol/packets/map_chunk_packet.cr
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
      @primary_bit_map : Int16 = -1_i16,
      @add_bit_map : Int16 = 0_i16,
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

    def self.from_chunk(chunk : CrystalMC::World::Chunk) : MapChunkPacket
      uncompressed = chunk.to_bytes

      compressed_io = IO::Memory.new
      Compress::Zlib::Writer.open(compressed_io) do |writer|
        writer.write(uncompressed)
      end

      compressed_data = compressed_io.to_slice

      new(
        x: chunk.x * 16,
        z: chunk.z * 16,
        ground_up_continuous: true,
        primary_bit_map: 0xFFFF.to_i16,
        add_bit_map: 0_i16,
        compressed_size: compressed_data.size,
        compressed_data: compressed_data
      )
    end
  end
end
