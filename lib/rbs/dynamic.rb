# frozen_string_literal: true

require "stringio"
require_relative "./dynamic/version"
require_relative "./dynamic/config.rb"
require_relative "./dynamic/tracer.rb"
require_relative "./dynamic/converter/trace_to_rbs.rb"

module RBS
  module Dynamic
    def self.trace(**options, &block)
      config = Config.new(options)
      tmp_stdout= $stdout
      $stdout = StringIO.new unless config.stdout?
      called_methods = RBS::Dynamic::Tracer.trace(
        target_filepath_pattern: config.target_filepath_pattern,
        ignore_filepath_pattern: config.ignore_filepath_pattern,
        # Fiter by Converter, not Tracer
        # Because it is difficult to filter considering `receiver_class` and `receiver_defined_class
        # target_classname_pattern: config.target_classname_pattern,
        # ignore_classname_pattern: config.ignore_classname_pattern,
        trace_c_api_method: config.trace_c_api_method?,
        &block
      )
      Converter::TraceToRBS.new(called_methods).convert(
        root_path: config.root_path,
        except_build_members: config.except_build_members,
        method_defined_calssses: config.method_defined_calssses,
        include_method_location: config.show_method_location?,
        use_literal_type: config.use_literal_type?,
        with_literal_type: config.with_literal_type?,
        use_interface_method_argument: config.use_interface_method_argument?,
        target_classname_pattern: config.target_classname_pattern,
        ignore_classname_pattern: config.ignore_classname_pattern
      )
    ensure
      $stdout = tmp_stdout
    end

    def self.trace_to_rbs_text(**options, &block)
      result = RBS::Dynamic.trace(**{ stdout: true }.merge(**options), &block)
      decls = result.values
      stdout = StringIO.new
      writer = RBS::Writer.new(out: stdout)
      writer.write(decls)
      stdout.string
    end
  end
end
