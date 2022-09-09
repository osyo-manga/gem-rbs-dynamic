# frozen_string_literal: true

require "rbs"
require_relative "./builder/types.rb"
require_relative "./builder/methods.rb"

module RBS module Dynamic module Builder
  class Base
    attr_reader :interface_members

    def initialize
      @inclued_modules = []
      @prepended_modules = []
      @extended_modules = []
      @constant_variables = Hash.new { |h, name| h[name] = [] }
      @instance_variables = Hash.new { |h, name| h[name] = [] }
      @methods = Hash.new { |h, name| h[name] = Methods.new(name, kind: :instance) }
      @singleton_methods = Hash.new { |h, name| h[name] = Methods.new(name, kind: :singleton) }
      @other_members = []
      @interface_members = []
    end

    def add_inclued_module(mod)
      @inclued_modules << mod
    end

    def add_prepended_module(mod)
      @prepended_modules << mod
    end

    def add_extended_module(mod)
      @extended_modules << mod
    end

    def add_constant_variable(name, type)
      @constant_variables[name] << type
    end

    def add_instance_variable(name, type)
      @instance_variables[name] << type
    end

    def add_singleton_method(name, sig)
      @singleton_methods[name] << sig
    end

    def add_method(name, sig = {})
      @methods[name] << sig
    end

    def add_member(member)
      @other_members << member
    end

    def add_interface_members(member)
      @interface_members << member
    end

    def build_members
      [
        *build_inclued_modules,
        *build_prepended_modules,
        *build_extended_modules,
        *build_constant_variables,
        *build_singleton_methods,
        *build_methods,
        *build_instance_variables,
        *@interface_members.map(&:build),
        *@other_members
      ]
    end

    def build_inclued_modules
      @inclued_modules.map { |mod|
        RBS::AST::Members::Include.new(
          name: mod.name,
          args: [],
          annotations: [],
          location: nil,
          comment: nil
        )
      }
    end

    def build_prepended_modules
      @prepended_modules.map { |mod|
        RBS::AST::Members::Prepend.new(
          name: mod.name,
          args: [],
          annotations: [],
          location: nil,
          comment: nil
        )
      }
    end

    def build_extended_modules
      @extended_modules.map { |mod|
        RBS::AST::Members::Extend.new(
          name: mod.name,
          args: [],
          annotations: [],
          location: nil,
          comment: nil
        )
      }
    end

    def build_constant_variables
      @constant_variables.map { |name, types|
        RBS::AST::Members::InstanceVariable.new(
          name: name,
          type: Types.new(types.flatten).build,
          location: nil,
          comment: nil
        )
      }
    end

    def build_instance_variables
      @instance_variables.map { |name, types|
        RBS::AST::Declarations::Constant.new(
          name: name,
          type: Types.new(types.flatten).build,
          location: nil,
          comment: nil
        )
      }
    end

    def build_singleton_methods
      @singleton_methods.values.map(&:build)
    end

    def build_methods
      @methods.values.map(&:build)
    end
  end
  private_constant :Base

  class Module < Base
    attr_reader :module

    def initialize(module_)
      super()
      @module = module_
    end

    def build
      RBS::AST::Declarations::Module.new(
        name: self.module.name,
        type_params: [],
        self_types: [],
        members: build_members,
        location: nil,
        annotations: [],
        comment: nil
      )
    end
  end

  class Class < Base
    attr_reader :klass

    def initialize(klass)
      super()
      @klass = klass
    end

    def build
      RBS::AST::Declarations::Class.new(
        name: klass.name,
        type_params: [],
        super_class: build_super_class,
        members: build_members,
        location: nil,
        annotations: [],
        comment: nil
      )
    end

    def build_super_class
      ::RBS::AST::Declarations::Class::Super.new(
        name: klass.superclass.name,
        args: [],
        location: nil
      ) unless klass.superclass&.name.nil? || Object == klass.superclass
    end
  end

  class Interface < Base
    attr_reader :name
    attr_reader :methods

    def initialize(name)
      super()
      @name = name
    end

    def build
      RBS::AST::Declarations::Interface.new(
        name: @name,
        type_params: [],
        members: build_members,
        annotations: [],
        location: nil,
        comment: nil
      )
    end

    def eql?(other)
      self.methods.map { |_, method| [method.name, method.kind, method.sigs] } ==
        other.methods.map { |_, method| [method.name, method.kind, method.sigs] }
    end
  end
end end end
