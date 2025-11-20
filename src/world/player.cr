require "./entity"
require "../network/connection"

module CrystalMC::World
  class Player < Entity
    property username : String
    property connection : Network::Connection
    property health : Float32
    property food : Int32
    property game_mode : Int32
    property inventory : Inventory
    property experience : Int32
    property level : Int32

    def initialize(@world : World, @entity_id : Int32, @username : String, @connection : Network::Connection)
      super(@world, @entity_id, 0.0, 64.0, 0.0)
      @health = 20.0_f32
      @food = 20
      @game_mode = 0 # Survival
      @inventory = Inventory.new
      @experience = 0
      @level = 0
    end

    def tick
      # Handle player physics, health regeneration, etc.
      update_health
    end

    def entity_type : String
      "player"
    end

    def send_message(message : String)
      @connection.send_chat_message(message)
    end

    def teleport(x : Float64, y : Float64, z : Float64)
      set_position(x, y, z)
      send_position_update
    end

    def damage(amount : Float32)
      @health -= amount
      @health = 0.0_f32 if @health < 0

      send_health_update

      if @health <= 0
        die
      end
    end

    def heal(amount : Float32)
      @health += amount
      @health = 20.0_f32 if @health > 20.0_f32
      send_health_update
    end

    def die
      send_message("§cYou died!")
      # Respawn logic
      respawn
    end

    def respawn
      @health = 20.0_f32
      @food = 20
      set_position(@world.spawn_x.to_f64 + 0.5, @world.spawn_y.to_f64, @world.spawn_z.to_f64 + 0.5)
      send_position_update
      send_health_update
    end

    private def update_health
      # Health regeneration logic
      if @health < 20.0_f32 && @food > 18
        @health += 0.01_f32 # Slow regeneration
        @health = 20.0_f32 if @health > 20.0_f32
      end
    end

    private def send_position_update
      pos_packet = Network::Protocol::PlayerLookMovePacket.new(
        x: @x,
        y: @y,
        stance: @y + 1.62,
        z: @z,
        yaw: @yaw,
        pitch: @pitch,
        on_ground: @on_ground
      )
      @connection.send_packet(pos_packet)
    end

    private def send_health_update
      # TODO: Implement health update packet (0x08)
      # For Beta 1.7.3, we need to send health updates
    end
  end

  class Inventory
    INVENTORY_SIZE = 45 # 36 main inventory + 9 hotbar

    property slots : Array(ItemStack?)

    def initialize
      @slots = Array(ItemStack?).new(INVENTORY_SIZE, nil)
    end

    def get_slot(index : Int32) : ItemStack?
      return nil if index < 0 || index >= INVENTORY_SIZE
      @slots[index]
    end

    def set_slot(index : Int32, stack : ItemStack?)
      return if index < 0 || index >= INVENTORY_SIZE
      @slots[index] = stack
    end

    def add_item(item_id : Int16, amount : Int8 = 1, damage : Int16 = 0) : Bool
      # Try to stack with existing items first
      @slots.each_with_index do |slot, index|
        if slot && slot.item_id == item_id && slot.damage == damage && slot.amount < 64
          can_add = Math.min(amount, 64 - slot.amount)
          slot.amount += can_add
          amount -= can_add
          return true if amount <= 0
        end
      end

      # Find empty slot
      @slots.each_with_index do |slot, index|
        if slot.nil?
          @slots[index] = ItemStack.new(item_id, amount, damage)
          return true
        end
      end

      false # Inventory full
    end

    def remove_item(item_id : Int16, amount : Int8) : Bool
      remaining = amount

      @slots.each_with_index do |slot, index|
        next unless slot && slot.item_id == item_id

        if slot.amount >= remaining
          slot.amount -= remaining
          @slots[index] = nil if slot.amount <= 0
          return true
        else
          remaining -= slot.amount
          @slots[index] = nil
        end
      end

      remaining == 0
    end

    def has_item(item_id : Int16, amount : Int8 = 1) : Bool
      count = 0
      @slots.each do |slot|
        count += slot.amount if slot && slot.item_id == item_id
      end
      count >= amount
    end
  end

  struct ItemStack
    property item_id : Int16
    property amount : Int8
    property damage : Int16

    def initialize(@item_id : Int16, @amount : Int8, @damage : Int16 = 0)
    end
  end
end
