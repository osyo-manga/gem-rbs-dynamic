# frozen_string_literal: true

require "rbs"
require_relative "./../refine/signature_merger.rb"
require_relative "./types.rb"

module RBS module Dynamic module Builder
  class Methods
    using Refine::SignatureMerger
    using Refine::SignatureMerger::AsA

    using Module.new {
      refine String do
        def comment
          RBS::AST::Comment.new(string: self, location: nil)
        end
      end

      refine Array do
        def func_params
          map { |param| param.func_param }
        end
      end

      refine Hash do
        def func_param(name: self[:name])
          RBS::Types::Function::Param.new(
            type: has_key?(:type) ? Types.new(self[:type]).build : Types::ANY,
            name: name,
            location: nil
          )
        end

        def required_positionals
          self[:required_positionals]&.func_params || []
        end

        def optional_positionals
          self[:optional_positionals]&.func_params || []
        end

        def rest_positionals
          self[:rest_positionals]&.func_params || []
        end

        def trailing_positionals
          self[:trailing_positionals]&.func_params || []
        end

        def required_keywords
          self[:required_keywords]&.to_h { |sig|
            [sig[:name], sig.func_param(name: nil)]
          } || []
        end

        def optional_keywords
          self[:optional_keywords]&.to_h { |sig|
            [sig[:name], sig.func_param(name: nil)]
          } || []
        end

        def rest_keywords
          self[:rest_keywords]&.func_params || []
        end

        def return_type
          Types.new(self.fetch(:return_type, []).as_a).build || Types::VOID
        end

        def block_type
          return if self[:block].nil? || self[:block].empty?

          RBS::Types::Block.new(
            type: self[:block].zip_sig!.function_type,
            required: false
          )
        end

        def function_type
          RBS::Types::Function.new(
            required_positionals: required_positionals,
            optional_positionals: optional_positionals,
            rest_positionals: rest_positionals.first,
            trailing_positionals: trailing_positionals,
            required_keywords: required_keywords,
            optional_keywords: optional_keywords,
            rest_keywords: rest_keywords.first,
            return_type: return_type
          )
        end

        def method_type
          RBS::MethodType.new(
            type_params: [],
            type: function_type,
            block: block_type,
            location: nil
          )
        end
      end
    }

    attr_reader :sigs
    attr_reader :name
    attr_reader :kind

    def initialize(name, kind: :instance)
      @name = name
      @sigs = []
      @kind = kind
    end

    def <<(sig)
      sigs << sig
    end

    def build
      RBS::AST::Members::MethodDefinition.new(
        name: name,
        kind: kind,
        types: types,
        annotations: [],
        location: nil,
        comment: comment,
        overload: false,
        visibility: sigs.last[:visibility]
      )
    end

    def types
      sigs.zip_sig.map { |sig|
        sig.method_type
      }
    end

    def comment
      <<~EOS.comment if sigs.last[:source_location] && sigs.any? { _1[:reference_location] }
        source location: #{sigs.last[:source_location]}
        reference location:
        #{sigs.map { "  #{name}#{_1.method_type} #{_1[:reference_location]}" }.uniq.join("\n")}
      EOS
    end
  end
end end end
