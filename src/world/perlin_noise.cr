module CrystalMC::World
  class PerlinNoise
    @permutation : Array(Int32)

    def initialize(seed : Int64 = 0)
      random = Random.new(seed)
      @permutation = (0..255).to_a.shuffle(random) * 2
    end

    def noise(x : Float64, y : Float64, z : Float64) : Float64
      # Find unit cube that contains point
      xi = x.floor.to_i & 255
      yi = y.floor.to_i & 255
      zi = z.floor.to_i & 255

      # Find relative x, y, z of point in cube
      x -= x.floor
      y -= y.floor
      z -= z.floor

      # Compute fade curves for each of x, y, z
      u = fade(x)
      v = fade(y)
      w = fade(z)

      # Hash coordinates of the 8 cube corners
      a = @permutation[xi] + yi
      aa = @permutation[a] + zi
      ab = @permutation[a + 1] + zi
      b = @permutation[xi + 1] + yi
      ba = @permutation[b] + zi
      bb = @permutation[b + 1] + zi

      # Blend results from 8 corners
      lerp(w,
        lerp(v,
          lerp(u, grad(@permutation[aa], x, y, z), grad(@permutation[ba], x - 1, y, z)),
          lerp(u, grad(@permutation[ab], x, y - 1, z), grad(@permutation[bb], x - 1, y - 1, z))
        ),
        lerp(v,
          lerp(u, grad(@permutation[aa + 1], x, y, z - 1), grad(@permutation[ba + 1], x - 1, y, z - 1)),
          lerp(u, grad(@permutation[ab + 1], x, y - 1, z - 1), grad(@permutation[bb + 1], x - 1, y - 1, z - 1))
        )
      )
    end

    def octave_noise(x : Float64, y : Float64, z : Float64, octaves : Int32, persistence : Float64 = 0.5) : Float64
      total = 0.0
      frequency = 1.0
      amplitude = 1.0
      max_value = 0.0

      octaves.times do
        total += noise(x * frequency, y * frequency, z * frequency) * amplitude
        max_value += amplitude
        amplitude *= persistence
        frequency *= 2.0
      end

      total / max_value
    end

    private def fade(t : Float64) : Float64
      t * t * t * (t * (t * 6 - 15) + 10)
    end

    private def lerp(t : Float64, a : Float64, b : Float64) : Float64
      a + t * (b - a)
    end

    private def grad(hash : Int32, x : Float64, y : Float64, z : Float64) : Float64
      h = hash & 15
      u = h < 8 ? x : y
      v = h < 4 ? y : (h == 12 || h == 14 ? x : z)
      (h & 1) == 0 ? u : -u + (h & 2) == 0 ? v : -v
    end
  end
end
