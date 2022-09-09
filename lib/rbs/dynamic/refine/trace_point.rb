# frozen_string_literal: true

require_relative "./basic_object_with_kernel.rb"

module RBS module Dynamic module Refine
  module TracePoint
    using RBS::Dynamic::Refine::BasicObjectWithKernel

    module ToRBSType
      refine Symbol do
        def to_rbs_value
          self
        end
      end

      refine Integer do
        def to_rbs_value
          self
        end
      end

      refine String do
        # No supported literal-string
        # def to_rbs_value
        #   self
        # end
      end

      refine BasicObject do
        def to_rbs_value
          nil
        end

        def to_rbs_type(cache: [])
          { type: Kernel.instance_method(:class).bind(self).call, value: to_rbs_value, args: [] }
        end
      end

      refine Array do
        def to_rbs_type(cache: [])
          return { type: Array, value: nil, args: [[]] } if cache.include? __id__
          { type: Array, value: nil, args: (empty? ? [[]] : [filter_map { _1.to_rbs_type(cache: cache + [__id__]) }.uniq]) }
        end
      end

      refine Hash do
        def to_rbs_type(cache: [])
          return { type: Hash, value: nil, args: [[], []] } if cache.include? __id__
          args = empty? ? [[], []] : [keys.filter_map { _1.to_rbs_type(cache: cache + [__id__]) }.uniq, values.map  { _1.to_rbs_type(cache: cache + [__id__]) }]
          { type: Hash, value: nil, args: args }
        end

        def except_value
          { type: self[:type], args: self[:args]&.map { |args| args.map { _1.except_value } } || [] }
        end
      end

      refine Range do
        def to_rbs_type(*)
          return { type: Range, value: nil, args: [[self.begin.to_rbs_type, self.end.to_rbs_type]] }
        end
      end
    end

    refine ::TracePoint do
      using ToRBSType
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

      def receiver
        self.self
      end

      def original_classname
        if singleton_class?
          if result = self.inspect[/#<Class:([^#].*)>/, 1]
            result
          else
            self.ancestors.superclass
          end
        else
          self.name
        end
      end

      def block?
        method_id.nil? || defined_class.nil?
      end

      def singleton_method?
        defined_class&.singleton_class? || (Module === receiver)
      end

      def receiver_class
        singleton_method? ? receiver : receiver.class
      end

      def receiver_defined_class
        return defined_class unless singleton_method?
        return defined_class unless (Module === receiver)
        receiver.ancestors.find { _1.methods(false).include?(method_id) || _1.private_methods(false).include?(method_id) } || defined_class
      end

      def argument_param(name)
        value = binding.local_variable_get(name)
        { name: name, type: value.class, rbs_type: value.to_rbs_type, value_object_id: value.__id__ }
      end

      def arguments
        parameters.map { |op, name|
          if op == :opt && name.nil?
            { op: op, type: NilClass, rbs_type: { type: NilClass } }
          elsif op == :rest && name.nil? || name == :*
            { op: op, type: Array, rbs_type: [].to_rbs_type }
          elsif op == :keyrest && name.nil? || name == :**
            { op: op, type: Hash, rbs_type: {}.to_rbs_type }
          elsif op == :block && name.nil? || name == :&
            { op: op, type: Proc, rbs_type: { type: Proc } }
          elsif name.nil?
            { op: op, type: NilClass, rbs_type: { type: NilClass } }
          else
            { op: op, name: name }.merge(argument_param(name))
          end
        }
      end

      def arguments_with_value
        parameters.map { |op, name|
          { op: op, name: name, value: binding.local_variable_get(name) }
        }
      end

      def visibility
        return nil if block?

        if singleton_method?
          if receiver.singleton_class.private_method_defined?(method_id)
            :private
          elsif receiver.singleton_class.protected_method_defined?(method_id)
            :protected
          else
            :public
          end
        else
          if receiver.class.private_method_defined?(method_id)
            :private
          elsif receiver.class.protected_method_defined?(method_id)
            :protected
          else
            :public
          end
        end
      end

      def instance_variables_class
        binding.eval("::Kernel.instance_method(:instance_variables).bind(self).call.to_h { [_1, ::Kernel.instance_method(:instance_variable_get).bind(self).call(_1).class] }")
      end

      def instance_variables_rbs_type
        binding.eval("::Kernel.instance_method(:instance_variables).bind(self).call.to_h { [_1, ::Kernel.instance_method(:instance_variable_get).bind(self).call(_1)] }").to_h { [_1, _2.to_rbs_type] }
      end

      def meta
        {
          method_id: method_id,
          defined_class: defined_class,
          receiver_class: receiver_class,
          receiver_defined_class: receiver_defined_class,
          receiver_object_id: receiver.__id__,
          callee_id: callee_id,
          arguments: arguments,
          lineno: lineno,
          path: path,
          visibility: visibility,
          singleton_method?: singleton_method?,
        }
      end

      def method_sigunature
        if defined_class.nil?
          "-> (#{arguments_with_value.map(&:to_arg_s).join(", ")}) {}"
        elsif defined_class.singleton_class?
          "#{defined_class.original_classname}.#{method_id}(#{arguments_with_value.map(&:to_arg_s).join(", ")})"
        elsif defined_class == Object
          "#{method_id}(#{arguments_with_value.map(&:to_arg_s).join(", ")})"
        else
          "#{defined_class.original_classname}##{method_id}(#{arguments_with_value.map(&:to_arg_s).join(", ")})"
        end
      end
    end
  end
end end end
