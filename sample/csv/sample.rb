require "rbs/dynamic"
require "csv"

rbs = RBS::Dynamic.trace_to_rbs_text do
  users =<<-EOS
    id|first name|last name|age
    1|taro|tanaka|20
    2|jiro|suzuki|18
    3|ami|sato|19
    4|yumi|adachi|21
  EOS

  csv = CSV.new(users, headers: true, col_sep: "|")
  p csv.class # => CSV
  p csv.first # => #<CSV::Row "id":"1" "first name":"taro" "last name":"tanaka" "age":"20">
end
puts rbs
