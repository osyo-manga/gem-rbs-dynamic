# frozen_string_literal: true
require "thor"
require_relative "../dynamic.rb"

module RBS module Dynamic
  class CLI < Thor
    desc "version", "show version"
    def version
      puts "rbs dynamic version #{RBS::Dynamic::VERSION}"
    end

    desc "trace [filename]", ""
    option :"root-path", type: :string, default: Dir.pwd, desc: "Rooting path. Default: current dir"
    option :"target-filepath-pattern", type: :string, default: ".*", desc: "Target filepath pattern. e.g. hoge\\|foo\\|bar. Default '.*'"
    option :"ignore-filepath-pattern", type: :string, default: nil, desc: "Ignore filepath pattern. Priority over `target-filepath-pattern`. e.g. hoge\\|foo\\|bar. Default ''"
    option :"target-classname-pattern", type: :string, default: ".*", desc: "Target class name pattern. e.g. RBS::Dynamic. Default '.*'"
    option :"ignore-classname-pattern", type: :string, default: nil, desc: "Ignore class name pattern. Priority over `target-classname-pattern`. e.g. PP\\|PrettyPrint. Default ''"
    option :"ignore-class_members", type: :array, enum: %w(inclued_modules prepended_modules extended_modules constant_variables instance_variables singleton_methods methods)
    option :"method-defined-calsses", type: :array, enum: %w(defined_class receiver_class), desc: "Which class defines method type. Default: defined_class and receiver_class"
    option :"show-method-location", type: :boolean, default: false, desc: "Show source_location and called_location in method comments. Default: no"
    option :"use-literal_type", type: :boolean, default: false, desc: "Integer and Symbol as literal types. e.g func(:hoge, 42). Default: no"
    option :"with-literal_type", type: :boolean, default: false, desc: "Integer and Symbol with literal types. e.g func(Symbol | :hoge | :foo). Default: no"
    option :"use-interface_method_argument", type: :boolean, default: false, desc: "Define method arguments in interface. Default: no"
    option :"stdout", type: :boolean, default: false, desc: "stdout at runtime. Default: no"
    option :"trace-c_api-method", type: :boolean, default: false, desc: "Trace C API method. Default: no"
    def trace(filename)
      decls = RBS::Dynamic.trace(**options) {
        load filename
      }.values
      stdout = StringIO.new
      writer = RBS::Writer.new(out: stdout)
      writer.write(decls)
      puts "# RBS dynamic trace #{RBS::Dynamic::VERSION}"
      puts
      puts stdout.string
    end
  end
end end
