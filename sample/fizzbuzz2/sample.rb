require "rbs/dynamic"

class Integer
  def fizz?
    self % 3 == 0
  end

  def buzz?
    self % 5 == 0
  end

  def fizzbuzz?
    fizz? && buzz?
  end
end

class FizzBuzz
  def to_fizzbuzz(value)
      value.fizzbuzz? ? "FizzBuzz"
    : value.fizz?     ? "Fizz"
    : value.buzz?     ? "Buzz"
    : value
  end

  def call(range, m = nil)
    case [range, m]
    in [Range, nil]
      range.map { to_fizzbuzz(_1) }
    in [Integer, nil]
      call(0..range)
    in [Integer, Integer]
      call(range..m)
    end
  end
end
puts "Result"

fizzbuzz = FizzBuzz.new

# Generating RBS in block
rbs = RBS::Dynamic.trace_to_rbs_text do
  fizzbuzz.call(0..3)
  fizzbuzz.call(30)
  fizzbuzz.call(10, 20)
end
puts rbs
__END__
Result
class Numeric
end

class FizzBuzz
  def call: (Range[Integer] range, ?NilClass m) ?{ (?Integer _1) -> (String | Integer) } -> Array[String | Integer]
    | (Integer range, ?NilClass m) -> Array[String | Integer]
    | (Integer range, ?Integer m) -> Array[String | Integer]

    def to_fizzbuzz: (Integer value) -> (String | Integer)
end

class Integer < Numeric
  def fizzbuzz?: () -> bool

  def fizz?: () -> bool

  def buzz?: () -> bool
end
