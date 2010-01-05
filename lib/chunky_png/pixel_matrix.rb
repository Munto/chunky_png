module ChunkyPNG
  
  class PixelMatrix
    
    FILTER_NONE    = 0
    FILTER_SUB     = 1
    FILTER_UP      = 2
    FILTER_AVERAGE = 3
    FILTER_PAETH   = 4
    
    attr_accessor :pixels, :palette, :width, :height
    
    def self.load(header, content)
      matrix = self.new(header.width, header.height)
      matrix.decode_pixelstream(content, header)
      return matrix
    end
    
    def [](x, y)
      pixels[y * width + x]
    end
    
    def each_scanline(&block)
      height.times do |i|
        scanline = @pixels[height * i, width]
        yield(scanline)
      end
    end
    
    def []=(x, y, color)
      @palette[@pixels[y * width + x]] -= 1
      @palette[color]  += 1
      @pixels[y * width + x] = color
    end
    
    def initialize(width, height, background_color = ChunkyPNG::Color::WHITE)
      @width, @height = width, height
      @pixels  = Array.new(width * height, background_color)
      @palette = { background_color => width * height }
      @palette.default = 0
    end
    
    def reset_pixels!
      @pixels = []
      @palette.clear
    end
    
    def decode_pixelstream(stream, header = nil)
      verify_length!(stream.length)
      reset_pixels!
      
      decoded_bytes = Array.new(header.width * 3, 0)
      height.times do |line_no|
        position      = line_no * (width * 3 + 1)
        line_length   = header.width * 3
        bytes         = stream.unpack("@#{position}CC#{line_length}")
        filter        = bytes.shift
        decoded_bytes = decode_scanline(filter, bytes, decoded_bytes, header)
        @pixels += decode_pixels(decoded_bytes, header)
      end
    end
    
    def decode_pixels(bytes, header)
      (0...width).map do |i|
        color = ChunkyPNG::Color.rgb(bytes[i*3+0], bytes[i*3+1], bytes[i*3+2])
        @palette[color] += 1
        color
      end
    end
    
    def decode_scanline(filter, bytes, previous_bytes, header = nil)
      case filter
      when FILTER_NONE    then decode_scanline_none( bytes, previous_bytes, header)
      when FILTER_SUB     then decode_scanline_sub(  bytes, previous_bytes, header)
      when FILTER_UP      then decode_scanline_up(   bytes, previous_bytes, header)
      when FILTER_AVERAGE then raise "Average filter are not yet supported!"
      when FILTER_PAETH   then raise "Paeth filter are not yet supported!"
      else raise "Unknown filter type"
      end
    end
    
    def decode_scanline_none(bytes, previous_bytes, header = nil)
      bytes
    end
    
    def decode_scanline_sub(bytes, previous_bytes, header = nil)
      bytes.each_with_index { |b, i| bytes[i] = (b + (i >= 3 ? bytes[i-3] : 0)) % 256 }
      bytes
    end
    
    def decode_scanline_up(bytes, previous_bytes, header = nil)
      bytes.each_with_index { |b, i| bytes[i] = (b + previous_bytes[i]) % 256 }
      bytes
    end
    
    def verify_length!(bytes_count)
      raise "Invalid stream length!" unless bytes_count == width * height * 3 + height
    end
    
    def encode_scanline(filter, bytes, previous_bytes, header = nil)
      case filter
      when FILTER_NONE    then encode_scanline_none( bytes, previous_bytes, header)
      when FILTER_SUB     then encode_scanline_sub(  bytes, previous_bytes, header)
      when FILTER_UP      then encode_scanline_up(   bytes, previous_bytes, header)
      when FILTER_AVERAGE then raise "Average filter are not yet supported!"
      when FILTER_PAETH   then raise "Paeth filter are not yet supported!"
      else raise "Unknown filter type"
      end
    end
    
    def encode_scanline_none(bytes, previous_bytes, header = nil)
      [FILTER_NONE] + bytes
    end
    
    def encode_scanline_sub(bytes, previous_bytes, header = nil)
      encoded = (3...bytes.length).map { |n| (bytes[n-3] - bytes[n]) % 256 }
      [FILTER_SUB] + bytes[0...3] + encoded
    end
    
    def encode_scanline_up(bytes, previous_bytes, header = nil)
      encoded = (0...bytes.length).map { |n| previous_bytes[n] - bytes[n] % 256 }
      [FILTER_UP] + encoded
    end
    
    def to_rgb_pixelstream
      stream = ""
      each_scanline do |line|
        bytes = line.map(&:to_rgb_array).flatten
        stream << encode_scanline(FILTER_NONE, bytes, nil, nil).pack('C*')
      end
      return stream
    end
  end
end