module CrystalMC::World
  abstract class Entity
    property entity_id : Int32
    property x : Float64
    property y : Float64
    property z : Float64
    property yaw : Float32
    property pitch : Float32
    property velocity_x : Float64
    property velocity_y : Float64
    property velocity_z : Float64
    property on_ground : Bool
    property world : World

    def initialize(@world : World, @entity_id : Int32, @x : Float64, @y : Float64, @z : Float64)
      @yaw = 0.0_f32
      @pitch = 0.0_f32
      @velocity_x = 0.0
      @velocity_y = 0.0
      @velocity_z = 0.0
      @on_ground = false
    end

    abstract def tick
    abstract def entity_type : String

    def move(dx : Float64, dy : Float64, dz : Float64)
      @x += dx
      @y += dy
      @z += dz
    end

    def set_position(x : Float64, y : Float64, z : Float64)
      @x = x
      @y = y
      @z = z
    end

    def set_rotation(yaw : Float32, pitch : Float32)
      @yaw = yaw
      @pitch = pitch
    end

    def distance_to(other : Entity) : Float64
      dx = @x - other.x
      dy = @y - other.y
      dz = @z - other.z
      Math.sqrt(dx * dx + dy * dy + dz * dz)
    end

    def distance_to(x : Float64, y : Float64, z : Float64) : Float64
      dx = @x - x
      dy = @y - y
      dz = @z - z
      Math.sqrt(dx * dx + dy * dy + dz * dz)
    end
  end
end
