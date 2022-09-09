# frozen_string_literal: true

require "rbs/dynamic"
$rbs_dynamic_option = {
  # stdout: false,
  # target_filepath_pattern: /rbs/,
  # ignore_filepath_pattern: /gems/
  target_classname_pattern: /RBS::Dynamic/,
  # ignore_classname_pattern: /RSpec/,
}
# require "rbs/dynamic/trace"

class Type1; end
class Type2; end
class Type3; end
class Type4; end
class Type5; end
class Type6; end
class Type7; end
class Type8; end
class Type9; end
$type1 = Type1.new
$type2 = Type2.new
$type3 = Type3.new
$type4 = Type4.new
$type5 = Type5.new
$type6 = Type6.new
$type7 = Type7.new
$type8 = Type8.new
$type9 = Type9.new

RSpec.configure do |config|
  # Enable flags like --only-failures and --next-failure
  config.example_status_persistence_file_path = ".rspec_status"

  # Disable RSpec exposing methods globally on `Module` and `main`
  config.disable_monkey_patching!

  config.expect_with :rspec do |c|
    c.syntax = :expect
  end
end
