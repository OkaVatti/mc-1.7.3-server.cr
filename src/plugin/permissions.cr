module CrystalMC::Plugin
  class PermissionManager
    property groups : Hash(String, PermissionGroup)
    property player_groups : Hash(String, String) # username => group name

    def initialize
      @groups = {} of String => PermissionGroup
      @player_groups = {} of String => String

      # Create default groups
      create_default_groups
    end

    def create_default_groups
      # Default group for all players
      default = PermissionGroup.new("default")
      default.permissions << "minecraft.command.help"
      default.permissions << "minecraft.command.list"
      @groups["default"] = default

      # Moderator group
      moderator = PermissionGroup.new("moderator")
      moderator.permissions << "minecraft.command.*"
      moderator.permissions << "minecraft.kick"
      moderator.permissions << "minecraft.ban"
      moderator.parent = "default"
      @groups["moderator"] = moderator

      # Admin group
      admin = PermissionGroup.new("admin")
      admin.permissions << "*"
      admin.parent = "moderator"
      @groups["admin"] = admin
    end

    def add_group(group : PermissionGroup)
      @groups[group.name] = group
    end

    def get_group(name : String) : PermissionGroup?
      @groups[name]?
    end

    def set_player_group(username : String, group_name : String)
      @player_groups[username] = group_name
    end

    def get_player_group(username : String) : String
      @player_groups[username]? || "default"
    end

    def has_permission(username : String, permission : String) : Bool
      group_name = get_player_group(username)
      group = @groups[group_name]?
      return false unless group

      check_permission(group, permission)
    end

    private def check_permission(group : PermissionGroup, permission : String) : Bool
      # Check for wildcard
      return true if group.permissions.includes?("*")

      # Check exact permission
      return true if group.permissions.includes?(permission)

      # Check wildcard patterns
      group.permissions.each do |perm|
        if perm.ends_with?("*")
          prefix = perm[0...-1]
          return true if permission.starts_with?(prefix)
        end
      end

      # Check parent group
      if parent_name = group.parent
        if parent = @groups[parent_name]?
          return check_permission(parent, permission)
        end
      end

      false
    end
  end

  class PermissionGroup
    property name : String
    property permissions : Array(String)
    property parent : String?

    def initialize(@name : String)
      @permissions = [] of String
      @parent = nil
    end
  end
end
