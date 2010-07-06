# Name   : Dice Library for Ruby
# Author : Randy Carnahan
# Version: 2.0
# License: LGPL

module Dice

  ####################
  ### Test Strings ###
  ####################

  TEST_COMPLEX = "(Attack) 1d20+8, (Damage) 2d8 + 8 + 1d6 - 3"
  TEST_SIMPLE  = "6x 4d6 !3"

  #############
  # Constants #
  #############

  EXPLODE_LIMIT = 20

  #######################
  # Regular Expressions #
  #######################

  SECTION_REGEX = /([+-]|[0-9*!xder]+)/i

  ROLL_REGEX = /(\d{1,2}x)?    # How many times?
    (\d{1,2})?d(\d{1,3}|\%)    # The dice to roll, xDx format
    (e\d{0,2})?                # Explode value
    (!\d{1,2})?                # Keep value
    (r\d{1,2})?                # Reroll value
    (\*\d{1,2})?               # Multiplier
  /xi

  ###########
  # Structs #
  ###########

  RollResult = Struct.new(:total, :tally)
  ComplexResult = Struct.new(:total, :parts, :label)

  ###########
  # Classes #
  ###########

  # The most simplest of a part. If a given part of
  # a dice string is not a Label, Fixnum, or a xDx part
  # it will be an instance of this class, which simply
  # returns the value given to it.
  class SimplePart
    attr :value

    def initialize(part)
      @value = part
    end

    def result
      return @value
    end

    def to_s
      return @value
    end
  end

  # The subclass for a label.
  class LabelPart < SimplePart
    def to_s
      return "(%s)" % @value
    end
  end

  # This represents a static, non-random number part
  # of the dice string.
  class StaticPart < SimplePart
    def initialize(num)
      num = num.to_i() if num.is_a?(String)
      @value = num
    end

    def total
      return @value
    end

    def to_s
      return @value.to_s()
    end
  end

  # This represents the xDx part of the dice string.
  # It takes the xDx part of the dice string and parses it
  # to get the individual parts. It also provides methods for
  # to get the roll result.
  class RollPart < SimplePart

    attr :parts

    def initialize(dstr)
      @last_roll = []
      @value = dstr

      # Our Default Values
      @parts = {
        :times   => 1,
        :num     => 1,
        :sides   => 6,
        :mult    => 0,
        :keep    => 0,
        :explode => 0,
        :reroll  => 0
      }

      self.parse()
    end

    # Uses the ROLL_REGEX constant to parse the xDx string
    # into the individual parts.
    def parse()

      dstr = @value.dup.downcase.gsub(/\s+/, "")
      parts = ROLL_REGEX.match(dstr)

      # Handle any crunchy-bits we found.
      if parts
        parts = parts.captures.dup()

        # Handle special d% sides
        parts[2] = 100 if parts[2] == "%"

        # Handle exploding value set to nothing.
        # Set it to the max-value of the die.
        parts[3] = parts[2] if parts[3] == "e"

        # Convert them to numbers.
        parts.collect! do |i|
          if i.nil?
            i = 0
          else
            i = i[1 .. -1] if i.match(/^[!*er]/)
            i.to_i
          end
        end
        
        @parts[:times]   = parts[0] if parts[0] > 0
        @parts[:num]     = parts[1] if parts[1] > 1
        @parts[:sides]   = parts[2] if parts[2] > 1
        @parts[:explode] = parts[3] if parts[3] > 1
        @parts[:mult]    = parts[4] if parts[4] > 1
        @parts[:keep]    = parts[5] if parts[5] > 0
        @parts[:reroll]  = parts[6] if parts[6] > 0
      end

      return self
    end

    # Checks to see if this instance has rolled yet
    # or not.
    def has_rolled?
      return @last_roll.empty? ? false : true
    end

    # Rolls a single die from the xDx string.
    def roll_die()
      num = 0
      reroll = (@parts[:reroll] >= @parts[:sides]) ? 0 : @parts[:reroll]

      while num <= reroll
        num = rand(@parts[:sides]) + 1
      end

      return num
    end

    # Rolls the dice, saving the results in the @last_roll
    # instance variable. @last_roll is cleared before the 
    # roll is handled.
    def roll
      @last_roll = []

      @parts[:times].times do

        results = []
        total = 0

        @parts[:num].times do
          roll = roll_die()

          results.push(roll)

          if @parts[:explode] and @parts[:explode] > 0
            explode_limit = 0

            while roll >= @parts[:explode]
              roll = roll_die()
              results.push(roll)
              explode_limit += 1
              break if explode_limit >= EXPLODE_LIMIT
            end
          end
        end

        disp_results = results.dup()
        results.sort!.reverse!

        if @parts[:keep] > 0
          sub_results = results[0 ... @parts[:keep]]
        else
          sub_results = results.dup()
        end
        
        total = sub_results.inject(0) {|t, i| t += i}
        total = total * @parts[:mult] if @parts[:mult] > 1

        res = RollResult.new(total, disp_results)

        @last_roll.push(res)
      end

      return @last_roll
    end

    # Gets the total of the last roll; if there is no 
    # last roll, it calls roll() first.
    def total
      self.roll() if @last_roll.empty?
      return @last_roll.inject(0) {|t, r| t += r.total()}
    end

    # Returns the result from the last roll, or if the dice
    # have not been rolled, rolls first.
    def result
      self.roll() if @last_roll.empty?
      return @last_roll
    end

    # The following methods ignore any :times and :explode 
    # values, so these won't be overly helpful in figuring 
    # out statistics or anything.

    def maximum()
      num = @parts[:keep].zero? ? @parts[:num] : @parts[:keep]
      mult = @parts[:mult].zero? ? 1 : @parts[:mult]
      return ((num * @parts[:sides]) * mult)
    end

    def minimum()
      # Short-circuit-ish logic here; if :sides and :reroll
      # are the same, return maximum() instead.
      return maximum() if @parts[:sides] == @parts[:reroll]

      num = @parts[:keep].zero? ? @parts[:num] : @parts[:keep]
      mult = @parts[:mult].zero? ? 1 : @parts[:mult]
        
      # Reroll value is <=, so we have to add 1 to get 
      # the minimum value for the die.
      sides = @parts[:reroll].zero? ? 1 : @parts[:reroll] + 1

      return ((num * sides) * mult)
    end

    def average()
      # Returns a float, of course.
      return (self.maximum() + self.minimum()) / 2.0
    end

    # This takes the @parts hash and recreates the xDx
    # string. Optionally, passing true to the method will
    # remove spaces form the finished string.
    def to_s(no_spaces=false)
      s = ""

      sp = no_spaces ? "" : " "
      
      s += case @parts[:times]
        when 0..1 then ""
        else @parts[:times].to_s + "x#{sp}"
      end

      s += @parts[:num].to_s if @parts[:num] != 0
      s += "d"
      s += @parts[:sides].to_s if @parts[:sides] != 0

      if @parts[:explode] != 0
        s += "#{sp}e"
        s += @parts[:explode].to_s if @parts[:explode] != @parts[:sides]
      end

      s += case @parts[:mult]
        when 0..1 then ""
        else "#{sp}*" + @parts[:mult].to_s
      end

      s += "#{sp}!" + @parts[:keep].to_s if @parts[:keep] != 0

      s += "#{sp}r" + @parts[:reroll].to_s if @parts[:reroll] != 0

      return s
    end
  end

  # Main class in the Dice module
  # This takes a complex dice string on instatiation,
  # parses it into it's individual parts, and then with
  # a call to the roll() method, will return an array of
  # results. Each element of the returned away will be an
  # instance of the ComplexResult structure, representing
  # a section of the complex dice string.
  class Roll
    attr :parsed

    def initialize(dstr="")
      @parsed = parse_dice_string(dstr)
    end

    def roll
      all = []

      @parsed.each do |section|
        total = 0
        parts = []
        label = ""

        section.each do |op, part|
          case op
          when :label
            label = part.value()
          when :start
            total = part.total()
            parts.push(part)
          when :add
            total += part.total()
            parts.push(part)
          when :sub
            total -= part.total()
            parts.push(part)
          end
        end

        all.push(ComplexResult.new(total, parts, label))
      end

      return all
    end

    # Recreates the complex dice string from the 
    # parsed array.
    def to_s
      return make_dice_string(@parsed)
    end

  end

  # Parses a complex dice string made up of one or more
  # comma-separated parts, each with an optional label.
  #
  # Example complex dice string:
  #   (Attack) 1d20+8, (Damage) 2d8 + 8 + 1d6 - 3
  #
  # Parsed to:
  #   [
  #     [
  #       [:label, "Attack"],
  #       [:start, "1d20"],
  #       [:add,   "8"]
  #     ],
  #     [
  #       [:label, "Damage"],
  #       [:start, "2d8"],
  #       [:add,   "8"],
  #       [:add,   "1d6"],
  #       [:sub,   "3"]
  #     ]
  #   ]
  #
  # Each part (the 2nd element in each sub-array) is a 
  # subclass of SimplePart: LabelPart, StaticPart, or
  # RollPart.
  def parse_dice_string(dstr="")
    all = []

    # Get our sections.
    sections = dstr.split(/,/)

    sections.each do |subsec|
      sec = []
      
      # First we look for labels.
      labels = subsec.scan(/\((.*?)\)/).flatten()

      # ...and then remove them and any spaces.
      subsec.gsub!(/\(.*?\)|\s/, "")

      # Record the first label found.
      if not labels.empty?
        label = labels.first()
        sec.push([:label, LabelPart.new(label)])
      end

      subs = subsec.scan(SECTION_REGEX).flatten()

      op = :start

      subs.each do |s|
        case s
        when "+"
          op = :add
        when "-"
          op = :sub
        else
          value = get_part(s)
          sec.push [op, value]
        end
      end

      all.push(sec)

    end

    return all
  end

  # Examines the given string and determines with
  # subclass of SimplePart the part should be. If it
  # can't figure it out, it defaults to SimplePart.
  def get_part(dstr="")
    part = case dstr
    when /^\d+$/
      StaticPart.new(dstr)
    when ROLL_REGEX
      RollPart.new(dstr)
    else
      SimplePart.new(dstr)
    end
    return part
  end

  # Takes a nested array, such as that returned from
  # parse_dice_string() and recreates the dice string.
  def make_dice_string(arr=[])
    return "" if arr.empty? or not arr.is_a?(Array)
    return arr.collect {|part| make_substring(part)}.join(", ")
  end

  # Builds the individual section by calling
  # each part's to_s() method. Returns a string.
  def make_substring(arr=[])
    s = ""
    return s if arr.empty? or not arr.is_a?(Array)

    arr.each do |op, part|
      case op
      when :label, :start
        s += "%s "   % part.to_s()
      when :add
        s += "+ %s " % part.to_s()
      when :sub
        s += "- %s " % part.to_s()
      end
    end

    return s.strip()
  end

end