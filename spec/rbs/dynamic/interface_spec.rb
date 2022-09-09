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

    describe "interface" do
      let(:options) { { use_interface_method_argument: true } }

      context "other argument and other method" do
        let(:body) {
          class InterfaceX
            def func(a)
              a.func("homu")
            end

            def func2(a)
              a.func(42)
            end
          end

          class InterfaceY
            def func(a); a end
            def func2(a); a end
          end

          x = InterfaceX.new
          y = InterfaceY.new

          -> {
            x.func(y); x.func2(y)
          }
        }

        it do
          is_expected.to include <<~EOS
            class InterfaceX
              def func: (_Interface_have__func__1 a) -> String

              def func2: (_Interface_have__func__2 a) -> Integer

              interface _Interface_have__func__1
                def func: (String a) -> String
              end

              interface _Interface_have__func__2
                def func: (Integer a) -> Integer
              end
            end

            class InterfaceY
              def func: (String a) -> String
                      | (Integer a) -> Integer
            end
          EOS
        end
      end

      context "other argument and same method" do
        let(:body) {
          class InterfaceX
            def func(a, b)
              a.func("homu")
              b.func(42)
            end
          end

          class InterfaceY
            def func(a); a end
            def func2(a); a end
          end

          x = InterfaceX.new
          y = InterfaceY.new
          y2 = InterfaceY.new

          -> {
            x.func(y, y2)
          }
        }

        it do
          is_expected.to include <<~EOS
            class InterfaceX
              def func: (_Interface_have__func__1 a, _Interface_have__func__2 b) -> Integer

              interface _Interface_have__func__1
                def func: (String a) -> String
              end

              interface _Interface_have__func__2
                def func: (Integer a) -> Integer
              end
            end

            class InterfaceY
              def func: (String a) -> String
                      | (Integer a) -> Integer
            end
          EOS
        end
      end

      context "same argument and same method" do
        let(:body) {
          class InterfaceX
            def func(a, b)
              a.func("homu")
              b.func("homu")
            end
          end

          class InterfaceY
            def func(a); a end
            def func2(a); a end
          end

          x = InterfaceX.new
          y = InterfaceY.new
          y2 = InterfaceY.new

          -> {
            x.func(y, y2)
          }
        }

        it do
          is_expected.to include <<~EOS
            class InterfaceX
              def func: (_Interface_have__func__1 a, _Interface_have__func__1 b) -> String

              interface _Interface_have__func__1
                def func: (String a) -> String
              end
            end

            class InterfaceY
              def func: (String a) -> String
            end
          EOS
        end
      end

      context "same argument and other method" do
        let(:body) {
          class InterfaceX
            def func(a, b)
              a.func("homu")
              b.func(42)
              b.func2(42)
            end
          end

          class InterfaceY
            def func(a); a end
            def func2(a); a end
          end

          x = InterfaceX.new
          y = InterfaceY.new
          y2 = InterfaceY.new

          -> {
            x.func(y, y2)
          }
        }

        it do
          is_expected.to include <<~EOS
            class InterfaceX
              def func: (_Interface_have__func__1 a, _Interface_have__func__func2__2 b) -> Integer

              interface _Interface_have__func__1
                def func: (String a) -> String
              end

              interface _Interface_have__func__func2__2
                def func: (Integer a) -> Integer

                def func2: (Integer a) -> Integer
              end
            end

            class InterfaceY
              def func: (String a) -> String
                      | (Integer a) -> Integer

              def func2: (Integer a) -> Integer
            end
          EOS
        end
      end

      context "call operator method" do
        let(:body) {
          class InterfaceOperator
            def +(a); end
            def +@; end
            def hoge?; end
          end

          class InterfaceCall
            def call_plus(a)
              a + a
            end

            def call_plus_at(a)
              +a
            end

            def call_hoge?(a)
              a.hoge?
            end
          end

          call = InterfaceCall.new
          op = InterfaceOperator.new
          -> {
            call.call_plus(op)
            call.call_plus_at(op)
            call.call_hoge?(op)
          }
        }

        it do
          is_expected.to include <<~EOS
            class InterfaceCall
              def call_plus: (_Interface_have____1 a) -> NilClass

              def call_plus_at: (_Interface_have____2 a) -> NilClass

              def call_hoge?: (_Interface_have__hoge__3 a) -> NilClass

              interface _Interface_have____1
                def +: (InterfaceOperator a) -> NilClass
              end

              interface _Interface_have____2
                def +@: () -> NilClass
              end

              interface _Interface_have__hoge__3
                def hoge?: () -> NilClass
              end
            end

            class InterfaceOperator
              def +: (InterfaceOperator a) -> NilClass

              def +@: () -> NilClass

              def hoge?: () -> NilClass
            end
          EOS
        end
      end

      context "dynamic conditional" do
        let(:body) {
          defined = InterfaceDefined.new
          caller = InterfaceCaller.new
          -> {
            caller.check(defined, true)
            caller.check(defined, false)
          }
        }
        before do
          class InterfaceDefined
            def func(a); end
            def func2(a); end
          end
          class InterfaceCaller; end
        end

        context "call same method and same argument" do
          before do
            class InterfaceCaller
              def check(a, flag)
                if flag
                  a.func($type1)
                else
                  a.func($type1)
                end
              end
            end
          end

          it do
            is_expected.to include <<~EOS
              class InterfaceCaller
                def check: (_Interface_have__func__1 a, bool flag) -> NilClass

                interface _Interface_have__func__1
                  def func: (Type1 a) -> NilClass
                end
              end

              class InterfaceDefined
                def func: (Type1 a) -> NilClass
              end
            EOS
          end
        end

        context "call same method and other argument" do
          before do
            class InterfaceCaller
              def check(a, flag)
                if flag
                  a.func($type1)
                else
                  a.func($type2)
                end
              end
            end
          end

          it do
            is_expected.to include <<~EOS
              class InterfaceCaller
                def check: (_Interface_have__func__1 | _Interface_have__func__2 a, bool flag) -> NilClass

                interface _Interface_have__func__1
                  def func: (Type1 a) -> NilClass
                end

                interface _Interface_have__func__2
                  def func: (Type2 a) -> NilClass
                end
              end

              class InterfaceDefined
                def func: (Type1 | Type2 a) -> NilClass
              end
            EOS
          end
        end

        context "call other method and same argument" do
          before do
            class InterfaceCaller
              def check(a, flag)
                if flag
                  a.func($type1)
                else
                  a.func2($type1)
                end
              end
            end
          end

          it do
            is_expected.to include <<~EOS
              class InterfaceCaller
                def check: (_Interface_have__func__1 | _Interface_have__func2__2 a, bool flag) -> NilClass

                interface _Interface_have__func__1
                  def func: (Type1 a) -> NilClass
                end

                interface _Interface_have__func2__2
                  def func2: (Type1 a) -> NilClass
                end
              end

              class InterfaceDefined
                def func: (Type1 a) -> NilClass

                def func2: (Type1 a) -> NilClass
              end
            EOS
          end
        end

        context "call other method and other argument" do
          before do
            class InterfaceCaller
              def check(a, flag)
                if flag
                  a.func($type1)
                else
                  a.func2($type2)
                end
              end
            end
          end
          it do
            puts subject
          end

          it do
            is_expected.to include <<~EOS
              class InterfaceCaller
                def check: (_Interface_have__func__1 | _Interface_have__func2__2 a, bool flag) -> NilClass

                interface _Interface_have__func__1
                  def func: (Type1 a) -> NilClass
                end

                interface _Interface_have__func2__2
                  def func2: (Type2 a) -> NilClass
                end
              end

              class InterfaceDefined
                def func: (Type1 a) -> NilClass

                def func2: (Type2 a) -> NilClass
              end
            EOS
          end
        end
      end

      context "some called methods" do
        let(:body) {
          defined = InterfaceDefined.new
          caller = InterfaceCaller.new
          -> {
            caller.check(defined)
            caller.check(defined)
          }
        }
        before do
          class InterfaceDefined
            def func; end
          end

          class InterfaceCaller
            def check(a)
              a.func
              a.func
            end
          end
        end

        it do
          is_expected.to include <<~EOS
            class InterfaceCaller
              def check: (_Interface_have__func__1 a) -> NilClass

              interface _Interface_have__func__1
                def func: () -> NilClass
              end
            end

            class InterfaceDefined
              def func: () -> NilClass
            end
          EOS
        end
      end
    end
  end
end
