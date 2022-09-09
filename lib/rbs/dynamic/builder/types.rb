# frozen_string_literal: true

require "rbs"
# require_relative "./../refine/signature_merger.rb"

module RBS module Dynamic module Builder
  class Types
    BOOL = RBS::Types::Bases::Bool.new(location: nil)
    VOID = RBS::Types::Bases::Void.new(location: nil)
    ANY  = RBS::Types::Bases::Any.new(location: nil)

    module ToRBSType
      refine Object do
        def to_rbs_type
          { type: self, args: [] }
        end
      end

      refine Hash do
        def to_rbs_type
          self
        end
      end
    end
    using ToRBSType

    module RBSTypeMerger
      refine Object do
        def merge_type(*)
          nil
        end
      end

      refine Hash do
        def merge_type(other)
          return unless Hash === other
          return unless self[:type] == other[:type]
          return unless self[:args].count == other[:args].count
          { type: self[:type], value: [self[:value], other[:value]].flatten.compact.uniq, args: self[:args].zip(other[:args]).map(&:flatten).map(&:uniq) }
        end
      end

      refine Array do
        def push_merge_type(other)
          each.with_index { |type, i|
            merged = type.merge_type(other)
            if merged
              self[i] = merged
              return self
            end
          }
          push(other)
        end

        def zip_type
          inject([]) { |result, type|
            result.push_merge_type(type)
          }
        end
      end
    end
    using RBSTypeMerger

    using Module.new {
      refine Object do
        def type(*)
          RBS::Types::Literal.new(
            literal: self,
            location: nil
          )
        end
      end

      refine Class do
        def type(*args)
          RBS::Types::ClassInstance.new(
            args: args.map { Array === _1 && _1.empty? ? ANY : Types.new(_1).build },
            location: nil,
            name: name
          )
        end
      end

      refine NilClass do
        def type(*)
          RBS::Types::Bases::Nil.new(location: nil)
        end
      end

      refine Hash do
        def type
          self[:type].type(*self[:args])
        end
      end

      refine RBS::Types::Bases::Base do
        def |(other)
          RBS::Types::Union.new(
            types: [self, other],
            location: nil
          )
        end

        def type
          self
        end
      end

      refine RBS::Types::Literal do
        def |(other)
          RBS::Types::Union.new(
            types: [self, other],
            location: nil
          )
        end
      end

      refine RBS::Types::Application do
        def type(*)
          self
        end

        def |(other)
          RBS::Types::Union.new(
            types: [self, other],
            location: nil
          )
        end
      end

      refine RBS::Types::Union do
        def |(other)
          RBS::Types::Union.new(
            types: (types + [other]),
            location: nil
          )
        end
      end

      refine Array do
        def union_type
          map { _1.type }.inject { _1 | _2 }
        end
      end
    }

    attr_reader :types

    def initialize(type)
      @types = case type
               when nil
                 [nil]
               when Hash
                 [type]
               else
                 Array(type)
               end.map(&:to_rbs_type).uniq.zip_type
    end

    def build
      if optional?
        RBS::Types::Optional.new(
          type: (target_types - [NIL_RBS_TYPE, NILCLASS_RBS_TYPE]).union_type,
          location: nil
        )
      else
        target_types.union_type
      end
    end

    NILCLASS_RBS_TYPE = NilClass.to_rbs_type
    NIL_RBS_TYPE = nil.to_rbs_type

    TRUECLASS_RBS_TYPE = TrueClass.to_rbs_type
    TRUE_RBS_TYPE = true.to_rbs_type

    FALSECLASS_RBS_TYPE = FalseClass.to_rbs_type
    FALSE_RBS_TYPE = false.to_rbs_type

    def optional?
      !!types.group_by { _1 == NIL_RBS_TYPE || _1 == NILCLASS_RBS_TYPE }.values.then { |opt, other| opt&.size&.>=(1) && other&.size&.>=(1) }
    end

    def in_bool?
      0 < types.count { _1 == TRUE_RBS_TYPE || _1 == TRUECLASS_RBS_TYPE } && 0 < types.count { _1 == FALSE_RBS_TYPE || _1 == FALSECLASS_RBS_TYPE }
    end

    def target_types
      (types + types.flat_map { Array(_1[:value]).map { |value| { type: value, args: [] } } })
        .tap { break _1 - [NIL_RBS_TYPE, NILCLASS_RBS_TYPE] if optional? }
        .tap { break _1 - [TRUE_RBS_TYPE, TRUECLASS_RBS_TYPE, FALSE_RBS_TYPE, FALSECLASS_RBS_TYPE] + [BOOL] if in_bool? }
    end
  end
end end end
