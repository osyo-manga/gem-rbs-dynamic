# frozen_string_literal: true

RSpec.describe RBS::Dynamic do
  describe ".trace" do
    let(:options) { {} }
    subject {
      result = RBS::Dynamic.trace(**options, &body)
      decls = result.values
      stdout = StringIO.new
      writer = RBS::Writer.new(out: stdout)
      writer.write(decls)
      stdout.string
    }

    context "with constants" do
      let(:body) { -> {
        class DynamicX
          Value = 42
          VALUE = "hoge"

          class Sub; end

          def hoge; end
        end
        DynamicX.new.hoge
      } }

      it do
        is_expected.to include <<~EOS
          class DynamicX
            VALUE: String

            def hoge: () -> NilClass
          end
        EOS
      end

      context "mixin" do
        context "nested" do
          let(:body) { -> {
            module DynamicNestedM
              M_VALUE = $type1

              def m_value
                M_VALUE
              end
            end

            class Super
              SUPER_VALUE = $type2

              def s_value
                $type2
              end
            end

            class Y < Super
              include DynamicNestedM

              Y_VALUE = $type3

              def value
                m_value
                s_value
                $type3
              end
            end

            y = Y.new.value
          } }

          it do
            is_expected.to include <<~EOS
              class Y < Super
                include DynamicNestedM

                Y_VALUE: Type3

                def value: () -> Type3

                def m_value: () -> Type1

                def s_value: () -> Type2
              end

              module DynamicNestedM
                M_VALUE: Type1

                def m_value: () -> Type1
              end

              class Super
                SUPER_VALUE: Type2

                def s_value: () -> Type2
              end
            EOS
          end
        end

        context "include, prepend, extend" do
          let(:body) {
            module DynamicM1; def m1; end; end
            module DynamicM2; def m2; end; end
            module DynamicM3; def m3; end; end
            module DynamicM4; def m4; end; end
            module DynamicM5; def m5; end; end
            module DynamicM6; def m6; end; end

            class DynamicMixin
              prepend DynamicM1
              include DynamicM2
              extend DynamicM3
              prepend DynamicM4
              include DynamicM5
              extend DynamicM6

              def func; end
            end

            obj = DynamicMixin.new
            -> {
              obj.func
              obj.m1
              obj.m2
              DynamicMixin.m3
              obj.m4
              obj.m5
              DynamicMixin.m6
            }
          }

          it do
            is_expected.to include <<~EOS
              class DynamicMixin
                include DynamicM2

                include DynamicM5

                prepend DynamicM1

                prepend DynamicM4

                extend DynamicM3

                extend DynamicM6

                def self.m3: () -> NilClass

                def self.m6: () -> NilClass

                def func: () -> NilClass

                def m1: () -> NilClass

                def m2: () -> NilClass

                def m4: () -> NilClass

                def m5: () -> NilClass
              end

              module DynamicM1
                def m1: () -> NilClass
              end

              module DynamicM2
                def m2: () -> NilClass
              end

              module DynamicM3
                def self.m3: () -> NilClass
              end

              module DynamicM4
                def m4: () -> NilClass
              end

              module DynamicM5
                def m5: () -> NilClass
              end

              module DynamicM6
                def self.m6: () -> NilClass
              end
            EOS
          end
        end

        context "non tracing called method" do
          context "namespace" do
            let(:body) {
              module DynamicNonTracingModule
                class Test1
                  def func1; end
                end

                module Module1
                  class Test2
                    def func2; end
                  end
                end
              end
              test1 = DynamicNonTracingModule::Test1.new
              test2 = DynamicNonTracingModule::Module1::Test2.new

              -> {
                test1.func1
                test2.func2
              }
            }

            it do
              is_expected.to include <<~EOS
                module DynamicNonTracingModule
                end

                module DynamicNonTracingModule::Module1
                end

                class DynamicNonTracingModule::Test1
                  def func1: () -> NilClass
                end

                class DynamicNonTracingModule::Module1::Test2
                  def func2: () -> NilClass
                end
              EOS
            end
          end

          context "superclass" do
            let(:body) {
              module DynamicNonTracingModule
                class Test1
                  def func1; end
                end

                class Test2 < Test1
                  def func2; end
                end
              end
              test2 = DynamicNonTracingModule::Test2.new

              -> {
                test2.func2
              }
            }

            it do
              is_expected.to include <<~EOS
                module DynamicNonTracingModule
                end

                class DynamicNonTracingModule::Test1
                end

                class DynamicNonTracingModule::Test2 < DynamicNonTracingModule::Test1
                  def func2: () -> NilClass
                end
              EOS
            end
          end
        end
      end

      context "constant in ARGF" do
        let(:body) { -> {
          class DynamicX
            VALUE_ARGF = ARGF
            A = 42

            def func; end
          end
          DynamicX.new.func
        } }

        it { is_expected.not_to include "ARGF.class" }
      end
    end

    describe "method" do
      context "optional arguments" do
        let(:body) { -> {
          class DynamicX
            def func(a, b = 1, *c, d)
            end
          end
          DynamicX.new.func($type1, $type2, $type3, $type4, $type5)
        } }

        it do
          is_expected.to include <<~EOS
            def func: (Type1 a, ?Type2 b, *Array[Type3 | Type4] c, Type5 d) -> NilClass
          EOS
        end
      end

      context "keyword arguments" do
        let(:body) { -> {
          class DynamicX
            def func(a:, b: Type9.new, **kwd)
            end
          end
          DynamicX.new.func(a: $type1, b: $type2, c: $type3, d: $type4)
        } }

        it do
          is_expected.to include <<~EOS
            def func: (a: Type1, ?b: Type2, **Hash[Symbol, Type3 | Type4] kwd) -> NilClass
          EOS
        end
      end

      context "with block multi call" do
        let(:body) { -> {
          class DynamicX
            def func(&block)
              block.call($type1)
              block.call($type2)
            end
          end
          DynamicX.new.func { |a| a }
        } }

        it do
          is_expected.to include <<~EOS
            def func: () ?{ (?Type1 | Type2 a) -> (Type1 | Type2) } -> Type2
          EOS
        end
      end

      context "forwarding argument" do
        let(:body) { -> {
          class DynamicX
            def func(...)
            end
          end
          DynamicX.new.func($type1)
        } }

        if RUBY_VERSION < "3.1.0"
          it do
            is_expected.to include <<~EOS
              def func: (*Array[untyped]) -> NilClass
            EOS
          end
        else
          it do
            is_expected.to include <<~EOS
              def func: (*Array[untyped], **Hash[untyped, untyped]) -> NilClass
            EOS
          end
        end
      end

      context "with empty Array and Hash" do
        let(:body) { -> {
          class DynamicX
            def func(a, b)
              [a, b]
            end
          end
          DynamicX.new.func([], {})
        } }

        it do
          is_expected.to include <<~EOS
          def func: (Array[untyped] a, Hash[untyped, untyped] b) -> Array[Array[untyped] | Hash[untyped, untyped]]
          EOS
        end
      end

      context "with Range" do
        let(:argument) {  }
        let(:body) { -> {
          class DynamicX
            def func(a)
              a
            end
          end
          DynamicX.new.func(argument)
        } }

        context "finite range" do
          let(:argument) { (1..10) }

          context "with `use_literal_type: false` options" do
            it do
              is_expected.to include <<~EOS
                def func: (Range[Integer] a) -> Range[Integer]
              EOS
            end
          end

          context "with `use_literal_type: true` options" do
            let(:options) { { use_literal_type: true } }
            it do
              is_expected.to include <<~EOS
                def func: (Range[Integer | 1 | 10] a) -> Range[Integer | 1 | 10]
              EOS
            end
          end
        end

        context "beginless range" do
          let(:argument) { (..10) }

          context "with `use_literal_type: false` options" do
            let(:options) { { use_literal_type: false } }
            it do
              is_expected.to include <<~EOS
                def func: (Range[Integer?] a) -> Range[Integer?]
              EOS
            end
          end

          xcontext "with `use_literal_type: true` options" do
            let(:options) { { use_literal_type: true } }
            it do
              is_expected.to include <<~EOS
                def func: (Range[Integer | NilClass | 10] a) -> Range[Integer | NilClass | 10]
              EOS
            end
          end
        end

        context "endless range" do
          let(:argument) { (1..) }

          context "with `use_literal_type: false` options" do
            let(:options) { { use_literal_type: false } }
            it do
              is_expected.to include <<~EOS
                def func: (Range[Integer?] a) -> Range[Integer?]
              EOS
            end
          end

          xcontext "with `use_literal_type: true` options" do
            let(:options) { { use_literal_type: true } }
            it do
              is_expected.to include <<~EOS
                def func: (Range[Integer | 1 | NilClass] a) -> Range[Integer | 1 | NilClass]
              EOS
            end
          end
        end
      end
    end

    context "with block" do
      context "multi call in method" do
        let(:body) { -> {
          class DynamicX
            def func(&block)
              block.call($type1)
              block.call($type2)
            end
          end
          DynamicX.new.func { |a| a }
        } }

        it do
          is_expected.to include <<~EOS
            def func: () ?{ (?Type1 | Type2 a) -> (Type1 | Type2) } -> Type2
          EOS
        end
      end

      context "same call block" do
        let(:body) { -> {
          class DynamicX
            def func(a, &block)
              block.call(a)
            end
          end
          x = DynamicX.new
          x.func($type1) { |a| a }
          x.func($type2) { |a| a }
          x.func($type2) { |a| $type1 }
        } }

        it { is_expected.to include <<~EOS }
          def func: (Type1 | Type2 a) ?{ (?Type1 | Type2 a) -> Type1 } -> Type1
        EOS

        it { is_expected.to include <<~EOS }
          | (Type2 a) ?{ (?Type2 a) -> Type2 } -> Type2
        EOS
      end
    end

    describe "options" do
      context "use-literal_type" do
        let(:options) { { "use-literal_type" => true } }

        let(:body) { -> {
          class DynamicX
            def func(a, b, c)
              a
            end
          end
          x = DynamicX.new
          x.func(:hoge, 24, "Hoge")
          x.func(:hoge, :bar, 42)
          x.func(42, "hoge", :foo)
        } }

        it do
          is_expected.to include <<~EOS
            def func: (:hoge a, 24 | :bar b, String | 42 c) -> :hoge
          EOS
        end

        it { is_expected.to include <<~EOS }
          | (42 a, String b, :foo c) -> 42
        EOS
      end

      context "wiith-literal_type" do
        let(:options) { { "with-literal_type" => true } }

        let(:body) { -> {
          class DynamicX
            def func(a, b, c)
              a
            end
          end
          x = DynamicX.new
          x.func(:hoge, 24, "Hoge")
          x.func(:hoge, :bar, 42)
          x.func(42, "hoge", :foo)
        } }

        it do
          is_expected.to include <<~EOS
            def func: (Symbol | :hoge a, Integer | Symbol | 24 | :bar b, String | Integer | 42 c) -> (Symbol | :hoge)
          EOS
        end

        it { is_expected.to include <<~EOS }
          | (Integer | 42 a, String b, Symbol | :foo c) -> (Integer | 42)
        EOS
      end

      context "trace-c_api-method" do
        let(:options) { { trace_c_api_method: trace_c_api_method } }
        let(:body) {
          class String
            def dynamic_spec_test_not_c_api_method; end
          end
          -> {
            "hoge".dynamic_spec_test_not_c_api_method
            "hoge".valid_encoding?
          }
        }

        context "true" do
          let(:trace_c_api_method) { true }

          it { is_expected.to include <<~EOS }
            def dynamic_spec_test_not_c_api_method: () -> NilClass
          EOS

          it { is_expected.to include <<~EOS }
            def valid_encoding?: () -> TrueClass
          EOS
        end

        context "false" do
          let(:trace_c_api_method) { false }

          it { is_expected.to include <<~EOS }
            def dynamic_spec_test_not_c_api_method: () -> NilClass
          EOS

          it { is_expected.not_to include <<~EOS }
            def valid_encoding?: () -> TrueClass
          EOS
        end
      end

      context "ignore_class_members" do
        let(:options) { { ignore_class_members: ignore_class_members } }
        let(:ignore_class_members) { [] }
        let(:body) {
          module DynamicIgnoreClassMembersM1
            def m1; end
          end

          module DynamicIgnoreClassMembersM2
            def m2; end
          end

          module DynamicIgnoreClassMembersM3
            def m3; end
          end

          class DynamicIgnoreClassMembers
            include DynamicIgnoreClassMembersM1
            prepend DynamicIgnoreClassMembersM2
            extend DynamicIgnoreClassMembersM3

            def self.test_singleton_method; end
            def test_instance_method; end

            @value = 42
            VALUE = 42 unless const_defined? :VALUE
          end

          obj = DynamicIgnoreClassMembers.new
          -> {
            DynamicIgnoreClassMembers.test_singleton_method
            DynamicIgnoreClassMembers.m3
            obj.test_instance_method
            obj.m1
            obj.m2
          }
        }

        context "`inclued_modules`" do
          let(:ignore_class_members) { %i(inclued_modules) }
          it { is_expected.not_to include "include" }
        end
        context "`prepended_modules`" do
          let(:ignore_class_members) { %i(prepended_modules) }
          it { is_expected.not_to include "prepend" }
        end
        context "`extended_modules`" do
          let(:ignore_class_members) { %i(extended_modules) }
          it { is_expected.not_to include "extend" }
        end
        context "`constant_variables`" do
          let(:ignore_class_members) { %i(constant_variables) }
          it { is_expected.not_to include "VALUE" }
        end
        context "`singleton_methods`" do
          let(:ignore_class_members) { %i(singleton_methods) }
          it { is_expected.not_to include "self." }
        end
        context "`methods`" do
          let(:ignore_class_members) { %i(methods) }
          it { is_expected.not_to include "def test" }
        end
        context "`instance_variables`" do
          let(:ignore_class_members) { %i(instance_variables) }
          it { is_expected.not_to include "@value" }
        end
      end
    end

    context "inherited nameless class" do
      let(:body) { -> {
        class InheritedNamelessClass < Class.new
          def func; end
        end
        InheritedNamelessClass.new.func
      } }

      it { is_expected.to include <<~EOS }
        class InheritedNamelessClass
          def func: () -> NilClass
        end
      EOS
    end

    context "use BasicObject" do
      let(:body) {
        class DynamicSubBasicObject < BasicObject
          def func(a)
            a
          end
        end

        a = DynamicSubBasicObject.new
        -> {
          a.func(a)
        }
      }

      it { is_expected.to include <<~EOS }
        class DynamicSubBasicObject < BasicObject
          def func: (DynamicSubBasicObject a) -> DynamicSubBasicObject
        end
      EOS
    end

    context "options with `target_classname_pattern` and `ignore_classname_pattern`" do
      let(:body) {
        class DynamicTargetBaseClass
          def func; end
        end

        class DynamicTargetClass < DynamicTargetBaseClass
          def func2; end
        end

        class DynamicNoTargetClass < DynamicTargetClass
          def func3; end
        end

        obj1 = DynamicTargetClass.new
        obj2 = DynamicNoTargetClass.new
        -> {
          obj1.func
          obj1.func2

          obj2.func
          obj2.func2
          obj2.func3
        }
      }

      context "target_classname_pattern /^TargetClass$/" do
        let(:options) { { target_classname_pattern: /^DynamicTargetClass$/ } }

        it { is_expected.to eq <<~EOS }
          class DynamicTargetClass < DynamicTargetBaseClass
            def func2: () -> NilClass

            def func: () -> NilClass
          end
        EOS
      end

      context "ignore_classname_pattern /^TargetClass$/" do
        let(:options) { { ignore_classname_pattern: /^DynamicTargetClass$/ } }

        it { is_expected.to eq <<~EOS }
          class DynamicTargetBaseClass
            def func: () -> NilClass
          end

          class DynamicNoTargetClass < DynamicTargetClass
            def func3: () -> NilClass

            def func: () -> NilClass

            def func2: () -> NilClass
          end
        EOS
      end

      context "target_classname_pattern /^TargetClass$/ and ignore_classname_pattern /^TargetClass$/" do
        let(:options) { {
          target_classname_pattern: /TargetClass/,
          ignore_classname_pattern: /No/
        } }

        it { is_expected.to eq <<~EOS }
          class DynamicTargetClass < DynamicTargetBaseClass
            def func2: () -> NilClass

            def func: () -> NilClass
          end
        EOS
      end
    end

    context "receiver_class is BasicObject" do
      let(:body) {
        class BasicObject
          def dynamic_spec_test_method; end
        end
        obj = BasicObject.new

        -> {
          obj.dynamic_spec_test_method
        }
      }

      it { is_expected.to include <<~EOS }
        class BasicObject
          def dynamic_spec_test_method: () -> NilClass
        end
      EOS
    end

    context "instance variables" do
      context "with Generic" do
        let(:body) {
          class DynamicInstanceVariable
            def initialize
              @value = [1, 2, 3]
            end
          end

          -> {
            DynamicInstanceVariable.new
          }
        }

        it { is_expected.to include <<~EOS }
          class DynamicInstanceVariable
            private def initialize: () -> Array[Integer]

            @value: Array[Integer]
          end
        EOS
      end
    end

    context "constant variables" do
      context "with Generic" do
        let(:body) {
          class DynamicConstantVariable
            VALUE = [1, 2, 3]
            def initialize
            end
          end

          -> {
            DynamicConstantVariable.new
          }
        }

        it { is_expected.to include <<~EOS }
          class DynamicConstantVariable
            VALUE: Array[Integer]

            private def initialize: () -> NilClass
          end
        EOS
      end
    end
  end
end
