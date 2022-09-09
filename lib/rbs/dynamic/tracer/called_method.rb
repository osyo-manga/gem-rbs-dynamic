# frozen_string_literal: true

require_relative "../refine/trace_point.rb"
require_relative "../refine/each_called_method.rb"

module RBS module Dynamic module Tracer
  class CalledMethod
    using Refine::TracePoint
    using Refine::TracePoint::ToRBSType
    using Refine::BasicObjectWithKernel

    using Module.new {
      refine BasicObject do
        def instance_variable_table
          instance_variables.to_h { |name|
            [name, instance_variable_get(name)]
          }
        end
      end

      refine Hash do
        using Module.new {
          refine Module do
            def original_classname
              if singleton_class?
                self.superclass.name
              else
                self.name
              end
            end
          end

          refine Hash do
            def to_arg_s
              if self[:op] == :key
                "#{self[:name]}: #{self[:value].inspect}"
              else
                "#{self[:name]} = #{self[:value].inspect}"
              end
            end
          end
        }

        def method_sig
          if self[:defined_class].singleton_class?
            "#{self[:defined_class].original_classname}.#{seif[:method_id]}(#{self[:arguments].map(&:to_arg_s).join(", ")})"
          elsif self[:defined_class] == BasicObject
            "#{self[:method_id]}(#{self[:arguments].map(&:to_arg_s).join(", ")})"
          else
            "#{self[:defined_class].original_classname}##{self[:method_id]}(#{self[:arguments].map(&:to_arg_s).join(", ")})"
          end
        end

        def difference(other)
          other.map { |key, value| [key, [self[key], value]] if value != self[key] }.compact.to_h
        end
      end
    }

    attr_reader :call_stack
    attr_reader :called_line_stack
    attr_reader :trace_point

    def initialize(
      target_filepath_pattern: /.*/,
      ignore_filepath_pattern: nil,
      target_classname_pattern: /.*/,
      ignore_classname_pattern: nil,
      trace_c_api_method: false
    )
      @target_filepath_pattern = Regexp.new(target_filepath_pattern)
      @ignore_filepath_pattern = ignore_filepath_pattern && Regexp.new(ignore_filepath_pattern)
      @target_classname_pattern = Regexp.new(target_classname_pattern)
      @ignore_classname_pattern = ignore_classname_pattern && Regexp.new(ignore_classname_pattern)
      @trace_c_api_method = trace_c_api_method
      clear
    end

    def clear
      @call_stack = [{ called_methods: [], block: [] }]
      @last_event = nil
      @called_line_stack = [{}]
      @ignore_rbs_dynamic_trace = false
      @trace_point = TracePoint.new(*tarvet_event, &method(:trace_call_methods))
      @trace_point.extend trace_point_ext
    end

    def called_methods
      {
        called_methods: call_stack.first[:called_methods]
      }
    end

    def ignore_rbs_dynamic_trace(&block)
      @ignore_rbs_dynamic_trace = true
      block.call
    ensure
      @ignore_rbs_dynamic_trace = false
    end

    def enable(**opt, &block)
      clear
      trace_point.enable(**opt, &block)
      ignore_rbs_dynamic_trace { called_methods }
    end

    def disable(**opt)
      ignore_rbs_dynamic_trace { trace_point.disable(**opt) }
    end

    def trace(**opt, &block)
      enable(**opt, &block)
    end

    using Refine::EachCalledMethod
    include Enumerable
    def each(&block)
      called_methods.each_called_method(&block)
    end

    private

    def trace_point_ext
      self_ = self
      Module.new {
        define_method(:__called_methods__) {
          self_.called_methods
        }

        define_method(:__ignore_rbs_dynamic_trace__) {
          self_.ignore_rbs_dynamic_trace(&block)
        }
      }
    end

    def tarvet_event
      if @trace_c_api_method
        %i(line call return b_call b_return c_call c_return)
      else
        %i(line call return b_call b_return)
      end
    end

    def target_event?(tp)
      tarvet_event.include?(tp.event)
    end

    def target_filepath?(path)
      @target_filepath_pattern =~ path
    end

    def ignore_filepath?(path)
      !target_filepath?(path) || (@ignore_filepath_pattern && @ignore_filepath_pattern =~ path)
    end

    def target_class?(klass)
      return true if !(Module === klass) || klass.singleton_class?
      @target_classname_pattern =~ klass&.name
    end

    def ignore_class?(klass)
      return false if !(Module === klass) || klass.singleton_class?
      @ignore_classname_pattern && @ignore_classname_pattern =~ klass&.name
    end

    def ignore_trace_call_methods?(tp)
      tp.method_id == :ignore_rbs_dynamic_trace \
      || tp.method_id == :__ignore_rbs_dynamic_trace__ \
      || @ignore_rbs_dynamic_trace \
      || ignore_filepath?(tp.path) \
      || (ignore_class?(tp.receiver_class) || ignore_class?(tp.receiver_defined_class)) \
      || !(target_class?(tp.receiver_class) || target_class?(tp.receiver_defined_class))
    end

    def trace_call_methods(tp)
      return unless target_event?(tp)
      return if ignore_trace_call_methods?(tp)

      @last_event = tp.event
      case tp.event
      when :line
        called_line_stack.last[:called_lineno] = tp.lineno
        called_line_stack.last[:called_path] = tp.path
        called_line_stack.last[:called_method_id] = tp.method_id
      when :call
        called_line_stack << called_line_stack.last.dup
        called_line = called_line_stack.last
        called_method = tp.meta.merge(
          called_lineno: called_line[:called_lineno],
          called_path: called_line[:called_path],
          called_method_id: called_line[:called_method_id],
          called_methods: [],
          block?: false,
          block: [],
          trace_point_event: tp.event
        )

        call_stack.last[:called_methods] << called_method
        call_stack << called_method
      when :return
        call_stack.last[:return_value_class] = tp.return_value.class
        call_stack.last[:return_value_rbs_type] = tp.return_value.to_rbs_type
        call_stack.last[:instance_variables_class] = tp.instance_variables_class
        call_stack.last[:instance_variables_rbs_type] = tp.instance_variables_rbs_type
        call_stack.pop if 1 < call_stack.size
        called_line_stack.pop if 1 < called_line_stack.size
      when :b_call
        called_line_stack << called_line_stack.last.dup
        called_line = called_line_stack.last
        called_method = tp.meta.merge(
          called_lineno: called_line[:called_lineno],
          called_path: called_line[:called_path],
          called_method_id: called_line[:called_method_id],
          called_methods: [],
          block?: true,
          block: [],
          trace_point_event: tp.event
        )

        call_stack.last[:called_methods] << called_method
        call_stack.last[:block] << called_method
        call_stack << called_method
      when :b_return
        call_stack.last[:return_value_class] = tp.return_value.class
        call_stack.last[:return_value_rbs_type] = tp.return_value.to_rbs_type
        call_stack.last[:instance_variables_class] = tp.instance_variables_class
        call_stack.last[:instance_variables_rbs_type] = tp.instance_variables_rbs_type
        call_stack.pop if 1 < call_stack.size
        called_line_stack.pop if 1 < called_line_stack.size
      when :c_call
        called_line_stack << called_line_stack.last.dup
        called_line = called_line_stack.last
        called_method = tp.meta.merge(
          called_lineno: called_line[:called_lineno],
          called_path: called_line[:called_path],
          called_method_id: called_line[:called_method_id],
          called_methods: [],
          block?: false,
          block: [],
          trace_point_event: tp.event
        )

        call_stack.last[:called_methods] << called_method
        call_stack.last[:block] << called_method
        call_stack << called_method
      when :c_return
        call_stack.last[:return_value_class] = tp.return_value.class
        call_stack.last[:return_value_rbs_type] = tp.return_value.to_rbs_type
        call_stack.last[:instance_variables_class] = tp.instance_variables_class
        call_stack.last[:instance_variables_rbs_type] = tp.instance_variables_rbs_type
        call_stack.pop if 1 < call_stack.size
        called_line_stack.pop if 1 < called_line_stack.size
      end
    end
  end
end end end
