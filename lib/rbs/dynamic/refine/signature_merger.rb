# frozen_string_literal: true


require_relative "../builder/types.rb"

module RBS module Dynamic module Refine
  module SignatureMerger
    module AsA
      refine Object do
        def as_a
          [self]
        end
      end

      refine Array do
        def as_a
          self
        end
      end
    end
    using AsA

    using Module.new {
      using RBS::Dynamic::Builder::Types::ToRBSType

      refine Array do
        # p [1, 2].zip([3, 4])            # => [[1, 3], [2, 4]]
        # p [1, 2].zip([3, 4, 5, 6])      # => [[1, 3], [2, 4]]
        # p [1, 2].zip_fill([3, 4, 5, 6]) # => [[1, 3], [2, 4], [nil, 5], [nil, 6]]
        def zip_fill(other, val = nil)
          if count < other.count
            fill(val, count...other.count).zip(other)
          else
            zip(other)
          end
        end

        def union_params_rbs_type
          map { |a, b|
            a ||= {}
            b ||= {}
            type = a.fetch(:type, []).as_a + b.fetch(:type, []).as_a
            { name: (a[:name] || b[:name]), type: type.map { _1.to_rbs_type }.uniq }
          }
        end

        def equal_type(other)
          count == Array(other).count && zip(Array(other)).all? { |a, b| a.equal_type(b) }
        end
      end

      refine Hash do
        def equal_type(other)
          rhs_type = Integer === self[:type] ? [Integer]
                   : String  === self[:type] ? [String]
                   : Symbol  === self[:type] ? [Symbol]
                   : Array   ==  self[:type] ? [Array]   # except args
                   : Hash    ==  self[:type] ? [Hash]    # except args
                   : [self[:type], self[:args]]

          lhs_type = Integer === other[:type] ? [Integer]
                   : String  === other[:type] ? [String]
                   : Symbol  === other[:type] ? [Symbol]
                   : Array   ==  other[:type] ? [Array]   # except args
                   : Hash    ==  other[:type] ? [Hash]    # except args
                   : [other[:type], other[:args]]

          rhs_type == lhs_type
        end

        def params
          slice(:required_positionals, :optional_positionals, :rest_positionals, :required_keywords, :optional_keywords)
        end

        def params_with_types
          params.to_h { |k, sigs| [k, sigs&.map { _1[:type].to_rbs_type }] }
        end

        def param_names_with_num
          params.to_h { |key, val| [key, val.count] }
        end

        def return_type
          fetch(:return_type, []).as_a.map { _1.to_rbs_type }
        end

        def param_mergeable?(other)
          param_names_with_num == other.param_names_with_num &&
            return_type == other.return_type
        end

        def return_type_mergeable?(other)
          params_with_types == other.params_with_types
        end

        def merge_params!(other)
          other.params.merge(self) { |key, other, current|
            current.zip_fill(other, {}).union_params_rbs_type
          }
        end

        def merge_params(other)
          return unless param_mergeable?(other)
          merge_params!(other)
        end

        def merge_return_type!(other)
          merge(return_type: (return_type + other.return_type).uniq)
        end

        def merge_return_type(other)
          return unless return_type_mergeable?(other)
          merge_return_type!(other)
        end
      end
    }

    refine Object do
      def merge_sig(*)
        nil
      end
    end

    refine Array do
      def merge_sig(other)
        (self + other).zip_sig
      end
    end

    refine Hash do
      def merge_sig(other)
        return unless Hash === other

        block_merged = self[:block]&.merge_sig(other[:block])

        if merged = merge_return_type(other)
          merged.merge(block: block_merged)
        elsif merged = merge_params(other)
          merged.merge(block: block_merged)
        end
      end

      def merge_sig!(other)
        return unless Hash === other

        merge_params!(other).merge_return_type!(other)
      end
    end

    refine Array do
      def push_merge_sig(other)
        each.with_index { |sig, i|
          merged = sig.merge_sig(other)
          if merged
            self[i] = merged
            return self
          end
        }
        push(other)
      end

      def zip_sig
        inject([]) { |result, sig|
          result.push_merge_sig(sig)
        }
      end

      def zip_sig!
        drop(1).inject(first) { |result, sig|
          result.merge_sig!(sig)
        }
      end
    end
  end
end end end
