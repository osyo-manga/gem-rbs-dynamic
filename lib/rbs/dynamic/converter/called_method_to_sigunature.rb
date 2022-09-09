# frozen_string_literal: true

require "rbs"
require_relative "../refine/trace_point.rb"
require 'pathname'

module RBS module Dynamic module Converter
  module CalledMethodToMethodSigunature
    using RBS::Dynamic::Refine::TracePoint::ToRBSType

    using Module.new {
      refine String do
        def relative_path(base_directory)
          delete_prefix(base_directory)
        end
      end

      refine Hash do
        def value_to_type
          merge(type: self[:value] || self[:type]).except(:value)
        end

        def type_to_rbs_type(use_literal_type: false, with_literal_type: false)
          if use_literal_type
            merge(type: self[:rbs_type].value_to_type).except(:op, :rbs_type, :value_object_id)
          elsif with_literal_type
            merge(type: self[:rbs_type]).except(:op, :rbs_type, :value_object_id)
          else
            merge(type: self[:rbs_type].except_value).except(:op, :rbs_type, :value_object_id)
          end
        end
      end
    }

    refine Array do
      def type_to_rbs_type(use_literal_type: false, with_literal_type: false)
        map { _1.type_to_rbs_type(use_literal_type: use_literal_type, with_literal_type: with_literal_type) }
      end
    end

    refine Hash do
      def method_sigunature(root_path: nil, include_location: false, use_literal_type: false, with_literal_type: false)
        opt = { use_literal_type: use_literal_type, with_literal_type: with_literal_type }
        visibility = self[:visibility] if self[:visibility] != :public

        req_opt = self[:arguments].take_while { _1[:op] != :rest }.to_a
        rest, *other = self[:arguments].drop_while { _1[:op] != :rest }.to_a
        req_opt ||= []
        rest ||= []
        {
          required_positionals: req_opt.select { _1[:op] == :req }.type_to_rbs_type(**opt),
          optional_positionals: req_opt.select { _1[:op] == :opt }.type_to_rbs_type(**opt),
          rest_positionals: self[:arguments].select { _1[:op] == :rest }.type_to_rbs_type(**opt),
          trailing_positionals: other.select { _1[:op] == :req }.type_to_rbs_type(**opt),
          required_keywords: self[:arguments].select { _1[:op] == :keyreq }.type_to_rbs_type(**opt),
          optional_keywords: self[:arguments].select { _1[:op] == :key }.type_to_rbs_type(**opt),
          rest_keywords: self[:arguments].select { _1[:op] == :keyrest }.type_to_rbs_type(**opt),
          block: self[:block].map { _1.method_sigunature(include_location: false, **opt) },
          source_location: ("#{self[:path].relative_path(root_path)}:#{self[:lineno]}" if include_location),
          reference_location: ("#{self[:called_path].relative_path(root_path)}:#{self[:called_lineno]}" if include_location)
        }.merge(
          return_type: (if use_literal_type
                          self[:return_value_rbs_type].value_to_type
                        elsif with_literal_type
                          self[:return_value_rbs_type]
                        else
                          self[:return_value_rbs_type].except_value
                        end),
          visibility: visibility
        )
    end
  end
end
end end end
