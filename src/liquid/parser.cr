require "./blocks"

module Liquid
  class Parser
    STATEMENT        = /^\s*(?<keyword>[a-z]+).*$/
    ENDRAW_STATEMENT = {
      "raw"     => /(?<!\\){%\s*endraw\s*\-?%}|$/,
      "comment" => /(?<!\\){%\s*endcomment\s*\-?%}|$/,
    }

    getter root : Root

    @str : String
    @i = 0
    @current_line = 0
    @escape = false
    @lstrip = false
    @rstrip = false

    # buffers
    @nodes = Array(Node).new
    @buffer = ""

    def self.parse(str : String)
      internal = self.new str
      internal.parse
      Template.new internal.root
    end

    def self.parse(file : File)
      str = file.gets_to_end
      path = File.dirname(file.path)

      internal = self.new str
      internal.parse
      Template.new internal.root, path
    end

    def initialize(@str)
      @root = Root.new
      @nodes << @root
    end

    def has_char?
      @i < str.size
    end

    # parse string
    def parse
      @i = 0
      while @i < @str.size - 1
        if @str[@i] == '{' && @str[@i + 1] == '%' && !@escape
          @i += 2
          if @str[@i] == '-'
            @rstrip = true
            @i += 1
          end
          add_raw
          consume_statement
        elsif @str[@i] == '{' && @str[@i + 1] == '{' && !@escape
          @i += 2
          if @str[@i] == '-'
            @rstrip = true
            @i += 1
          end
          add_raw
          consume_expression
        else
          consume_char
        end
        @escape = false if @escape
        @escape = true if @str[@i] == '\\'
        @i += 1
      end
      consume_char # last char ?
      add_raw
    end

    # Create and add a Raw node with current buffer
    def add_raw
      if !@buffer.empty?
        @buffer = @buffer.lstrip if @lstrip
        @buffer = @buffer.rstrip if @rstrip
        @nodes.last << Block::Raw.new @buffer
        @buffer = ""
      end
      @lstrip = false
      @rstrip = false
    end

    def consume_expression
      while @i < @str.size - 1
        if @str[@i] == '-' && @str[@i + 1] == '}' && @str[@i + 2] == '}'
          @lstrip = true
          @i += 2
          break
        elsif @str[@i] == '}' && @str[@i + 1] == '}'
          @i += 1
          break
        else
          consume_char
        end
        @i += 1
      end

      if !@buffer.empty?
        @nodes.last << Expression.new @buffer
        @buffer = ""
      else
        raise "Invalid Expression at line #{@current_line}"
      end
    end

    # Consume a statement
    def consume_statement
      while @i < @str.size - 1
        if @str[@i] == '-' && @str[@i + 1] == '%' && @str[@i + 2] == '}'
          @lstrip = true
          @i += 2
          break
        elsif @str[@i] == '%' && @str[@i + 1] == '}'
          @i += 1
          break
        else
          consume_char
        end
        @i += 1
      end

      if match = @buffer.match STATEMENT
        block_class = BlockRegister.for_name match["keyword"]
        case block_class.type
        when BlockType::End
          while (pop = @nodes.pop?) && pop.is_a? Block && !pop.class.type == BlockType::Begin
          end
        when BlockType::Begin
          block = block_class.new @buffer
          @nodes.last << block
          @nodes << block
        when BlockType::Inline
          @nodes.last << block_class.new @buffer
        else # when BlockType::Raw, BlockType::RawHidden
          if match = @str.match(ENDRAW_STATEMENT[match["keyword"]], @i)
            j = match.begin.not_nil! - 1
            @buffer = @str[@i + 1..j]
            @i = match.end.not_nil! - 1
            @nodes.last << block_class.new @buffer
          end
        end
      else
        raise "Invalid Statement at line #{@current_line}"
      end

      @buffer = ""
    end

    # Add current char to buffer
    def consume_char
      if @i < @str.size
        @buffer += @str[@i]
        @current_line += 1 if @str[@i] == '\n'
      end
    end
  end
end
