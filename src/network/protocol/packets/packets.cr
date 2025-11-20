require "./packet"
require "./protocol_helper"
require "./keep_alive_packet"
require "./handshake_packet"
require "./client_login_packet" # Add this
require "./server_login_packet" # And this
require "./chat_packet"
require "./player_pos_packet"
require "./player_look_packet"
require "./player_look_move_packet"
require "./block_dig_packet"
require "./block_place_packet"
require "./kick_disconnect_packet"
require "./pre_chunk_packet"
require "./map_chunk_packet"

module CrystalMC::Network::Protocol::Packets
  # Single source of truth for packet registry
  PACKET_REGISTRY = {} of UInt8 => Packet.class

  def self.register_packet(id : UInt8, packet_class : Packet.class)
    PACKET_REGISTRY[id] = packet_class
  end

  def self.read_packet(packet_id : UInt8, io : IO) : Packet?
    packet_class = PACKET_REGISTRY[packet_id]?
    return nil unless packet_class

    begin
      packet = packet_class.new
      packet.read(io)
      packet
    rescue ex
      puts "Error reading packet 0x#{packet_id.to_s(16)}: #{ex.message}"
      puts ex.backtrace.join("\n") if ex.backtrace
      nil
    end
  end

  # Register all packets for Minecraft Beta 1.7.3
  register_packet(0x00_u8, KeepAlivePacket)
  register_packet(0x01_u8, ClientLoginPacket) # Client sends this after handshake
  register_packet(0x02_u8, HandshakePacket)
  register_packet(0x03_u8, ChatPacket)
  register_packet(0x0B_u8, PlayerPosPacket)
  register_packet(0x0C_u8, PlayerLookPacket)
  register_packet(0x0D_u8, PlayerLookMovePacket)
  register_packet(0x0E_u8, BlockDigPacket)
  register_packet(0x0F_u8, BlockPlacePacket)
  register_packet(0x32_u8, PreChunkPacket)
  register_packet(0x33_u8, MapChunkPacket)
  register_packet(0xFF_u8, KickDisconnectPacket)

  # Debug method to list all registered packets
  def self.list_packets
    PACKET_REGISTRY.each do |id, klass|
      puts "0x#{id.to_s(16).rjust(2, '0')} -> #{klass}"
    end
  end
end
