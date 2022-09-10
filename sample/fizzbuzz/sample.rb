require "rbs/dynamic"

class FizzBuzz
  def initialize(value)
    @value = value
  end

  def value; @value end

  def apply
      value % 15 == 0 ? "FizzBuzz"
    : value %  3 == 0 ? "Fizz"
    : value %  5 == 0 ? "Buzz"
    : value
  end
end

puts "Result"
rbs = RBS::Dynamic.trace_to_rbs_text do
  p (1..20).map { FizzBuzz.new(_1).apply }
end
puts rbs

__END__
output:
Result
[1, 2, "Fizz", 4, "Buzz", "Fizz", 7, 8, "Fizz", "Buzz", 11, "Fizz", 13, 14, "FizzBuzz", 16, 17, "Fizz", 19, "Buzz"]
class FizzBuzz
  private def initialize: (Integer value) -> Integer

  def apply: () -> (Integer | String)

  def value: () -> Integer

  @value: Integer
end
