# frozen_string_literal: true

require 'pathname'
require_relative "./called_method_to_sigunature.rb"

module RBS module Dynamic module Converter
  module CalledMethodToWithInterface
    using CalledMethodToMethodSigunature
    refine Hash do
      def to_with_interface(defined_interfaces: [])
        self.dup.then { |called_method|
          interfaces = called_method[:arguments].each.with_index(1).inject([]) { |interfaces, (argument, i)|
            called_methods = called_method[:called_methods].select { _1[:receiver_object_id] == argument[:value_object_id] }
            next interfaces if called_methods.empty?

            interface = RBS::Dynamic::Builder::Interface.new("dummy_name")
            sub_interfaces = called_methods.map { |called_method|
              called_method, sub_interfaces = called_method.to_with_interface(defined_interfaces: defined_interfaces + interfaces)
              # Non support nexted defined interface in RBS
              # sub_interfaces.map { interface.add_member(_1.build) }
              interface.add_method(called_method[:method_id], **called_method.method_sigunature)
              sub_interfaces
            }.flatten
            interfaces += sub_interfaces

            unless interface_ = (defined_interfaces + interfaces).find { _1.eql? interface }
              interface_name = "_Interface_have__#{called_methods.map { _1[:method_id] }.uniq.join("__")}__#{(defined_interfaces + interfaces).count + 1}"
                                # except #+ #== #hoge? methods
                                .gsub(/[^[:alnum:]_]/, "")
              interface.instance_exec { @name = interface_name }
              interfaces << interface
            end

            argument[:rbs_type][:type] = RBS::Types::Interface.new(name: (interface_ || interface).name, args: [], location: nil)

            interfaces
          }

          [called_method, interfaces]
        }
      end
    end
  end
end end end
