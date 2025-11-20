module CrystalMC::World
  abstract class Entity
    property world : World
    property entity_id : Int32
    property x : Float64
    property y : Float64
    property z : Float64
    property dead : Bool = false

    def initialize(@world : World, @entity_id : Int32, @x : Float64, @y : Float64, @z : Float64)
    end

    abstract def entity_type : String
    abstract def tick

    def set_position(x : Float64, y : Float64, z : Float64)
      @x = x
      @y = y
      @z = z
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

    def kill
      @dead = true
    end

    def dead? : Bool
      @dead
    end
  end
end
