module CrystalMC::Network::Protocol
  # Minecraft protocol versions for reference
  PROTOCOL_VERSIONS = {
    14_u8 => "Beta 1.7.3",
    13_u8 => "Beta 1.7.2",
    12_u8 => "Beta 1.7",
    11_u8 => "Beta 1.6.6",
    10_u8 => "Beta 1.6.5",
     9_u8 => "Beta 1.6.4",
     8_u8 => "Beta 1.6.3",
     7_u8 => "Beta 1.6.2",
     6_u8 => "Beta 1.6.1",
     5_u8 => "Beta 1.6",
     4_u8 => "Beta 1.5",
     3_u8 => "Beta 1.4",
     2_u8 => "Beta 1.3",
     1_u8 => "Beta 1.2",
     0_u8 => "Pre-Beta or Invalid",
  }

  def self.get_version_name(version : UInt8) : String
    PROTOCOL_VERSIONS[version]? || "Unknown (#{version})"
  end

  def self.is_beta_1_7_3?(version : UInt8) : Bool
    version == 14_u8
  end
end
