require "./entity"
require "../network/connection"
require "../network/protocol/packets"

module CrystalMC::World
  class Player < Entity
    property username : String
    property connection : Network::Connection
    property health : Int32 = 20
    property food : Int32 = 20
    property gamemode : Symbol = :survival
    property on_ground : Bool = true
    property op : Bool = false
    property inventory : Inventory
    property selected_slot : Int32 = 0
    property experience : Int32 = 0
    property level : Int32 = 0

    @regeneration_timer : Int32 = 0
    @hunger_timer : Int32 = 0

    def initialize(@world : World, @entity_id : Int32, @username : String, @connection : Network::Connection)
      @inventory = Inventory.new
      @x = @world.spawn_x.to_f64 + 0.5
      @y = @world.spawn_y.to_f64
      @z = @world.spawn_z.to_f64 + 0.5
      @yaw = 0.0_f32
      @pitch = 0.0_f32
      @on_ground = true

      # Give starter items in survival mode
      give_starter_items if @gamemode == :survival
    end

    def tick
      update_health_and_hunger
      update_chunk_visibility
    end

    def op? : Bool
      @op
    end

    def set_position(x : Float64, y : Float64, z : Float64)
      @x = x
      @y = y
      @z = z
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

    def damage(amount : Int32)
      @health -= amount
      @health = 0 if @health < 0

      send_health_update

      if @health <= 0
        die
      end
    end

    def heal(amount : Int32)
      @health += amount
      @health = 20 if @health > 20
      send_health_update
    end

    def die
      send_message("§cYou died!")
      respawn
    end

    def respawn
      @health = 20
      @food = 20
      set_position(@world.spawn_x.to_f64 + 0.5, @world.spawn_y.to_f64, @world.spawn_z.to_f64 + 0.5)
      send_position_update
      send_health_update
    end

    def give_item(item_id : Int16, amount : Int8 = 1, damage : Int16 = 0)
      @inventory.add_item(item_id, amount, damage)
    end

    # Check if player has item
    def has_item?(item_id : Int16, amount : Int8 = 1) : Bool
      @inventory.has_item(item_id, amount)
    end

    # Get player's current chunk coordinates
    def chunk_x : Int32
      (@x / 16).to_i32
    end

    def chunk_z : Int32
      (@z / 16).to_i32
    end

    # Get block player is standing on
    def standing_block_x : Int32
      @x.floor.to_i32
    end

    def standing_block_y : Int32
      (@y - 1).floor.to_i32
    end

    def standing_block_z : Int32
      @z.floor.to_i32
    end

    # Get block player is looking at (simplified)
    def targeted_block(distance : Float64 = 5.0) : Tuple(Int32, Int32, Int32)?
      # Simple raycast - in reality this would be more complex
      look_x = @x + Math.cos(@yaw) * distance
      look_z = @z + Math.sin(@yaw) * distance
      look_y = @y + Math.sin(@pitch) * distance

      {look_x.floor.to_i32, look_y.floor.to_i32, look_z.floor.to_i32}
    end

    def to_s(io : IO)
      io << "Player(#{@username}, #{@entity_id}, #{@x.round(2)}, #{@y.round(2)}, #{@z.round(2)})"
    end

    private def give_starter_items
      @inventory.set_slot(0, ItemStack.new(Block::WOOD.to_i16, 16_i8))
      @inventory.set_slot(1, ItemStack.new(Block::STONE.to_i16, 32_i8))
      @inventory.set_slot(2, ItemStack.new(Block::DIRT.to_i16, 64_i8))
      send_inventory_update
    end

    def send_inventory_update
      # Send inventory packet to client
      puts "🎒 Sent inventory update to #{@username}"
    end

    def get_selected_item : ItemStack?
      @inventory.get_slot(@selected_slot)
    end

    def can_harvest_block(block_id : UInt8) : Bool
      # Simple harvesting logic - in survival, need correct tool
      @gamemode == :creative
    end

    private def update_chunk_visibility
      # In a full implementation, we'd manage which chunks are visible
      # based on player position and view distance
      current_chunk_x = chunk_x
      current_chunk_z = chunk_z

      # For simplicity, assume a view distance of 4 chunks
      view_distance = 4
      (-view_distance..view_distance).each do |dx|
        (-view_distance..view_distance).each do |dz|
          chunk = @world.get_chunk(current_chunk_x + dx, current_chunk_z + dz)
          if chunk
            # In a real implementation, we'd send chunk data to player
            # For now, just log it
            puts "🌍 Player #{@username} can see chunk (#{chunk.x}, #{chunk.z})"
          end
        end
      end
    end

    private def update_health_and_hunger
      @regeneration_timer += 1
      @hunger_timer += 1

      # Health regeneration (every 4 seconds when food is high)
      if @regeneration_timer >= 80 && @health < 20 && @food > 17
        @health += 1
        @regeneration_timer = 0
        send_health_update
      end

      # Hunger depletion (every 4 seconds)
      if @hunger_timer >= 80
        if @food > 0
          @food -= 1
          @hunger_timer = 0
        elsif @health > 1
          # Take damage when starving
          damage(1)
          @hunger_timer = 0
        end
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
      health_packet = Network::Protocol::HealthUpdatePacket.new(@health.to_i16)
      @connection.send_packet(health_packet)
    end
  end

  class Inventory
    INVENTORY_SIZE = 36 # 27 main inventory + 9 hotbar

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
      remaining = amount

      @slots.each_with_index do |slot, index|
        if slot && slot.item_id == item_id && slot.damage == damage && slot.amount < 64
          can_add = (Math.min(remaining, 64 - slot.amount)).to_i8
          slot.amount += can_add
          remaining = (remaining - can_add).to_i8
          return true if remaining <= 0
        end
      end

      # Find empty slot for remaining items
      @slots.each_with_index do |slot, index|
        if slot.nil? && remaining > 0
          stack_amount = (Math.min(remaining, 64)).to_i8
          @slots[index] = ItemStack.new(item_id, stack_amount, damage)
          remaining = (remaining - stack_amount).to_i8
          return true if remaining <= 0
        end
      end

      remaining == 0
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
          remaining = (remaining - slot.amount).to_i8
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

    def clear
      @slots = Array(ItemStack?).new(INVENTORY_SIZE, nil)
    end

    def empty? : Bool
      @slots.all?(&.nil?)
    end

    def item_count(item_id : Int16) : Int32
      count = 0
      @slots.each do |slot|
        count += slot.amount if slot && slot.item_id == item_id
      end
      count
    end

    def to_s(io : IO)
      items = @slots.compact.map(&.to_s)
      io << "Inventory[#{items.join(", ")}]"
    end
  end

  struct ItemStack
    property item_id : Int16
    property amount : Int8
    property damage : Int16

    def initialize(@item_id : Int16, @amount : Int8, @damage : Int16 = 0)
    end

    def to_s(io : IO)
      io << "ItemStack(#{@item_id} x#{@amount})"
    end

    def empty? : Bool
      @amount <= 0
    end
  end
end
