module CrystalMC::Network::Protocol
  module PacketFactory
    def self.create_packet(packet_class : Packet.class) : Packet
      case packet_class
      when KeepAlivePacket
        KeepAlivePacket.new(0)
      when SomeOtherPacket
        SomeOtherPacket.new(default_arg)
      else
        # Try zero-arg constructor for other packets
        packet_class.new
      end
    rescue
      raise "No default constructor defined for #{packet_class}"
    end
  end

  class Packets
    def self.read_packet(packet_id : UInt8, io : IO) : Packet?
      packet_class = PACKET_REGISTRY[packet_id]?
      return nil unless packet_class

      begin
        packet = PacketFactory.create_packet(packet_class)
        packet.read(io)
        packet
      rescue ex
        puts "Error reading packet 0x#{packet_id.to_s(16)}: #{ex.message}"
        puts ex.backtrace.join("\n") if ex.backtrace
        nil
      end
    end
  end
end