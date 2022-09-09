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

    describe "method_defined_calssses" do

      before do
        class DynamicMethodDefiendClassBase
          def func(a)
          end
        end

        class DynamicMethodDefiendClassSub1 < DynamicMethodDefiendClassBase
        end

        class DynamicMethodDefiendClassSub2 < DynamicMethodDefiendClassBase
        end
      end

      context "option `defined_class`" do
        let(:options) { { method_defined_calssses: %i(defined_class) } }
        let(:body) {
          sub1 = DynamicMethodDefiendClassSub1.new
          sub2 = DynamicMethodDefiendClassSub2.new
          -> {
            sub1.func($type1)
            sub2.func($type2)
          }
        }

        it do
          is_expected.to include <<~EOS
            class DynamicMethodDefiendClassBase
              def func: (Type1 | Type2 a) -> NilClass
            end
          EOS
        end
      end

      context "option `receiver_class`" do
        let(:options) { { method_defined_calssses: %i(receiver_class) } }
        let(:body) {
          sub1 = DynamicMethodDefiendClassSub1.new
          sub2 = DynamicMethodDefiendClassSub2.new
          -> {
            sub1.func($type1)
            sub2.func($type2)
          }
        }

        it do
          is_expected.to include <<~EOS
            class DynamicMethodDefiendClassBase
            end

            class DynamicMethodDefiendClassSub1 < DynamicMethodDefiendClassBase
              def func: (Type1 a) -> NilClass
            end

            class DynamicMethodDefiendClassSub2 < DynamicMethodDefiendClassBase
              def func: (Type2 a) -> NilClass
            end
          EOS
        end
      end

      context "option `defined_class receiver_class`" do
        let(:options) { { method_defined_calssses: %i(defined_class receiver_class) } }
        let(:body) {
          sub1 = DynamicMethodDefiendClassSub1.new
          sub2 = DynamicMethodDefiendClassSub2.new
          -> {
            sub1.func($type1)
            sub2.func($type2)
          }
        }

        it do
          is_expected.to include <<~EOS
            class DynamicMethodDefiendClassBase
              def func: (Type1 | Type2 a) -> NilClass
            end

            class DynamicMethodDefiendClassSub1 < DynamicMethodDefiendClassBase
              def func: (Type1 a) -> NilClass
            end

            class DynamicMethodDefiendClassSub2 < DynamicMethodDefiendClassBase
              def func: (Type2 a) -> NilClass
            end
          EOS
        end
      end
    end
  end
end
