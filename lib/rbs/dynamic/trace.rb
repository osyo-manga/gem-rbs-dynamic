require "rbs"
require_relative "../dynamic.rb"

$rbs_dynamic_tracer = RBS::Dynamic::Tracer::CalledMethod.new
$rbs_dynamic_tracer.enable

END {
  $rbs_dynamic_tracer.ignore_rbs_dynamic_trace { $rbs_dynamic_tracer.disable }
  called_methods = $rbs_dynamic_tracer.called_methods

  puts "# RBS dynamic trace #{RBS::Dynamic::VERSION}"
  puts

  config = RBS::Dynamic::Config.new($rbs_dynamic_option)
  decls = RBS::Dynamic::Converter::TraceToRBS.new(called_methods).convert(
    root_path: config.root_path,
    except_build_members: config.except_build_members,
    method_defined_calssses: config.method_defined_calssses,
    include_method_location: config.show_method_location?,
    use_literal_type: config.use_literal_type?,
    with_literal_type: config.with_literal_type?,
    use_interface_method_argument: config.use_interface_method_argument?,
    target_classname_pattern: config.target_classname_pattern,
    ignore_classname_pattern: config.ignore_classname_pattern
  ).values
  stdout = StringIO.new
  writer = RBS::Writer.new(out: stdout)
  writer.write(decls)
  puts stdout.string
}
