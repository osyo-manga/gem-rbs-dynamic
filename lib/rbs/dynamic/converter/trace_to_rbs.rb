# frozen_string_literal: true

require "rbs"
require_relative "../builder.rb"
require_relative "../refine/each_called_method.rb"
require_relative "./called_method_to_sigunature.rb"
require_relative "./called_method_to_with_interface.rb"

module RBS module Dynamic module Converter
  class TraceToRBS
    using RBS::Dynamic::Refine::EachCalledMethod
    using RBS::Dynamic::Refine::TracePoint::ToRBSType
    using CalledMethodToMethodSigunature
    using CalledMethodToWithInterface

    using Module.new {
      refine Module do
        def constants_wit_rbs_type(...)
          constants(...)
            # Except to ARGF.class
            .filter_map { |name| [name, const_get(name).to_rbs_type.except_value] if const_get(name).class.name =~ /^\w+$/ }
            .to_h
        end

        def include_prepend_modules
          ancestors = Class === self ? self.ancestors.take_while { _1 != self.superclass } : self.ancestors
          [ancestors.take_while { _1 != self }.reverse, ancestors.drop_while { _1 != self }.drop(1).reverse]
        end

        # M1::M2::X => [M1, M1::M2, M1::M2::X]
        def namespace_paths
          name.split("::").inject([]) { |result, scope|
            result << Object.const_get("#{result.last}::#{scope}")
          }
        end
      end
    }

    attr_reader :called_methods

    def initialize(called_methods)
      @called_methods = called_methods
    end

    def convert(
      root_path: nil,
      except_build_members: [],
      include_method_location: false,
      method_defined_calssses: %i(defined_class receiver_class),
      use_literal_type: false,
      with_literal_type: false,
      use_interface: false,
      use_interface_method_argument: false,
      target_classname_pattern: /.*/,
      ignore_classname_pattern: nil
    )
      called_methods_ = called_methods.each_called_method.reject { _1[:block?] }
      klass_with_called_methods = [
          if method_defined_calssses.include? :defined_class
            called_methods_.group_by { _1[:receiver_defined_class] }
          end,
          if method_defined_calssses.include? :receiver_class
            called_methods_.group_by { _1[:receiver_class] }
          end
        ]
        .compact
        .inject { |result, it| result.merge(it) { |key, a, b| a + b } }
        .select { |klass, _| Module === klass }.reject { |klass, _| klass.nil? || klass.singleton_class? }
        .to_h { |klass, called_methods|
          [klass, called_methods.uniq { [_1[:method_id], _1[:arguments], _1[:return_value_class], _1[:called_path], _1[:called_lineno]] }.group_by { _1[:method_id] }]
        }
      klasses = klass_with_called_methods.keys

      # Modules / classes that are defined but methods are not called are also defined in RBS
      non_called_klass = klass_with_called_methods.keys.map { _1.namespace_paths }.flatten \
                       + klasses.filter_map { Class === _1 && Object != _1.superclass && BasicObject != _1.superclass && _1.superclass } \
                       - klasses

      # non_called_klass += non_called_klass.map { _1.include_prepend_modules }.flatten
      klass_with_called_methods = non_called_klass.to_h { [_1, {}] }.merge(klass_with_called_methods)
      # klass_with_called_methods = klass_with_called_methods.merge(non_called_klass.to_h { [_1, {}] })

      # klass_with_called_methods.sort_by { |klass, _| klass.name }.to_h { |klass, name_with_called_methods|
      klass_with_called_methods
        .select { |klass, _| target_classname_pattern && target_classname_pattern =~ klass.name }
        .reject { |klass, _| ignore_classname_pattern && ignore_classname_pattern =~ klass.name }
        .to_h { |klass, name_with_called_methods|
        builder = Class === klass ? RBS::Dynamic::Builder::Class.new(klass) : RBS::Dynamic::Builder::Module.new(klass)

        # Add prepend / include
        # MEMO: Add only the traced module to RBS
        # TODO: Predefined RBS modules (e.g. core module) other than Trace are not mixin
        klass.include_prepend_modules.tap { |prepended, included|
          # prepend
          prepended.each { |mod|
            builder.add_prepended_module(mod) if klasses.include? mod
          } unless except_build_members.include? :prepended_modules

          # include
          included.each { |mod|
            builder.add_inclued_module(mod) if klasses.include? mod
          } unless except_build_members.include? :inclued_modules
        }

        # Add extend
        klass.singleton_class.include_prepend_modules.flatten.each { |mod|
          builder.add_extended_module(mod) if klasses.include? mod
        } unless except_build_members.include? :extended_modules

        # Add constant variable
        klass.constants_wit_rbs_type(false).each { |name, type|
          builder.add_constant_variable(name, type) if name == name.upcase
        } unless except_build_members.include? :constant_variables

        # Add instance variable
        name_with_called_methods.map { |_, called_methods| called_methods.map { _1[:instance_variables_rbs_type] } }.flatten.each { |instance_variables_rbs_type|
          instance_variables_rbs_type.each { |name, type|
            # TODO: Support use_literal_type and with_literal_type
            builder.add_instance_variable(name, type.except_value)
          }
        } unless except_build_members.include? :instance_variables

        # Add method and singleton method
        name_with_called_methods.each.with_index(1) { |(name, called_methods), i|
          called_methods.each.with_index(1) { |called_method, j|
            if use_interface_method_argument
              called_method, sub_interfaces = called_method.to_with_interface(defined_interfaces: builder.interface_members)
              sub_interfaces.map { builder.add_interface_members(_1) }
            end

            signature = called_method.method_sigunature(root_path: root_path, include_location: include_method_location, use_literal_type: use_literal_type, with_literal_type: with_literal_type)
            if called_method[:singleton_method?]
              builder.add_singleton_method(name, **signature) unless except_build_members.include? :singleton_methods
            else
              builder.add_method(name, **signature) unless except_build_members.include? :methods
            end
          }
        }

        [klass, builder.build]
      }
    end
  end
end end end
