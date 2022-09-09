# frozen_string_literal: true

module RBS module Dynamic
  class Config
    attr_reader :options

    def initialize(options)
      @options = options
    end

    def except_build_members
      ignore_class_members
    end

    def root_path
      options["root-path"] || options[:root_path] || Dir.pwd
    end

    def target_filepath_pattern
      options["target-filepath-pattern"] || options[:target_filepath_pattern] || /.*/
    end

    def ignore_filepath_pattern
      options["ignore-filepath-pattern"] || options[:ignore_filepath_pattern]
    end

    def target_classname_pattern
      Regexp.new(options["target-classname-pattern"] || options[:target_classname_pattern] || /.*/)
    end

    def ignore_classname_pattern
      (options["ignore-classname-pattern"] || options[:ignore_classname_pattern])&.then { Regexp.new(_1) }
    end

    def ignore_class_members
      (options["ignore-class_members"] || options[:ignore_class_members] || []).map(&:to_sym)
    end

    def method_defined_calssses
      (options["method-defined-calsses"] || options[:method_defined_calssses] || %i(defined_class receiver_class)).map(&:to_sym)
    end

    def show_method_location?
      options["show-method-location"] || options[:show_method_location] || false
    end

    def use_literal_type?
      options["use-literal_type"] || options[:use_literal_type] || false
    end

    def with_literal_type?
      options["with-literal_type"] || options[:with_literal_type] || false
    end

    def use_interface_method_argument?
      options["use-interface_method_argument"] || options[:use_interface_method_argument] || false
    end

    def trace_c_api_method?
      options["trace-c_api-method"] || options[:trace_c_api_method] || false
    end

    def stdout?
      (options["stdout"] || options[:stdout]).then { _1.nil? ? true : _1 }
    end
  end
end end
