module CrystalMC::Auth
  class Authenticator
    @@online_mode = false

    def self.online_mode=(value : Bool)
      @@online_mode = value
    end

    def self.online_mode?
      @@online_mode
    end

    # Basic username validation for Beta 1.7.3
    def self.validate_username(username : String) : Bool
      return false if username.empty?
      return false if username.size > 16
      return false unless username =~ /^[a-zA-Z0-9_]+$/
      true
    end

    # In offline mode, we just validate the username format
    # In online mode, we would verify with Minecraft's session server
    def self.authenticate(username : String, server_id : String = "") : Bool
      if online_mode?
        # Online mode authentication (not implemented yet)
        puts "Online mode authentication for #{username} (not implemented)"
        return false
      else
        # Offline mode - just validate username
        puts "Offline mode authentication for #{username}"
        return validate_username(username)
      end
    end

    # Generate a random server ID for session
    def self.generate_server_id : String
      Random::Secure.hex(16)
    end
  end
end
