# frozen_string_literal: true

RSpec.describe RBS::Dynamic::Tracer::CalledMethod do
  describe "#trace" do
    using RBS::Dynamic::Refine::EachCalledMethod
    class X; end
    module M; end

    let(:klass) { X }
    let(:options) { {} }
    let(:trace) { RBS::Dynamic::Tracer::CalledMethod.new(**options).trace(&body) }
    subject { trace.each_called_method.to_a }

    context "def func(a, b) a + b end" do
      before do
        class X
          def func(a, b) a + b end
        end
      end

      context "func(1, 2)" do
        let(:body) { -> { X.new.func(1, 2) } }
        it { is_expected.to include(
          include(
            receiver_class: X,
            method_id: :func,
            visibility: :public,
            singleton_method?: false,
            arguments: [include(op: :req, name: :a, type: Integer), include(op: :req, name: :b, type: Integer)],
            return_value_class: Integer
          )
        ) }
      end

      context "func('a', 'b')" do
        let(:body) { -> { X.new.func('a', 'b') } }
        it { is_expected.to include(
          include(
            receiver_class: X,
            method_id: :func,
            visibility: :public,
            singleton_method?: false,
            arguments: [include(op: :req, name: :a, type: String), include(op: :req, name: :b, type: String)],
            return_value_class: String
          )
        ) }
      end

      context "func(42, 3.14)" do
        let(:body) { -> { X.new.func(42, 3.14) } }
        it { is_expected.to include(
          include(
            receiver_class: X,
            method_id: :func,
            visibility: :public,
            singleton_method?: false,
            arguments: [include(op: :req, name: :a, type: Integer), include(op: :req, name: :b, type: Float)],
            return_value_class: Float
          )
        ) }
      end

      context "multi call func" do
        let(:body) { -> {
          x = X.new
          x.func(1, 2)
          x.func("hoge", "foo")
          x.func([], [])
        } }
        it { is_expected.to include(
          include(
            receiver_class: X,
            method_id: :func,
            arguments: [include(op: :req, name: :a, type: Integer), include(op: :req, name: :b, type: Integer)],
            return_value_class: Integer
          ),
          include(
            receiver_class: X,
            method_id: :func,
            arguments: [include(op: :req, name: :a, type: String), include(op: :req, name: :b, type: String)],
            return_value_class: String
          ),
          include(
            receiver_class: X,
            method_id: :func,
            arguments: [include(op: :req, name: :a, type: Array), include(op: :req, name: :b, type: Array)],
            return_value_class: Array
          ),
        ) }
      end
    end

    context "private def func(a, b) a + b end" do
      before do
        class X
          private def func(a, b) a + b end
        end
      end

      context "func(1, 2)" do
        let(:body) { -> { X.new.send(:func, 1, 2) } }
        it { is_expected.to include(
          include(
            receiver_class: X,
            method_id: :func,
            visibility: :private,
          )
        ) }
      end
    end

    context "protected def func(a, b) a + b end" do
      before do
        class X
          protected def func(a, b) a + b end
        end
      end

      context "func(1, 2)" do
        let(:body) { -> { X.new.send(:func, 1, 2) } }
        it { is_expected.to include(
          include(
            receiver_class: X,
            method_id: :func,
            visibility: :protected,
          )
        ) }
      end
    end

    context "def func(*)" do
      before do
        class X
          def func(*) end
        end
      end

      context "func(1, 2)" do
        let(:body) { -> { X.new.func(1, 2) } }

        it { is_expected.to include(
          include(
            receiver_class: X,
            method_id: :func,
            arguments: [include(op: :rest, type: Array)],
          )
        ) }
      end
    end

    context "def func(*option)" do
      before do
        class X
          def func(*option) end
        end
      end

      context "func(1, 2)" do
        let(:body) { -> { X.new.func(1, 2) } }

        it { is_expected.to include(
          include(
            receiver_class: X,
            method_id: :func,
            arguments: [include(op: :rest, name: :option, type: Array)],
          )
        ) }
      end
    end

    context "def func(**)" do
      before do
        class X
          def func(**) end
        end
      end

      context "func(a: 1, b: 2)" do
        let(:body) { -> { X.new.func(a: 1, b: 2) } }

        it { is_expected.to include(
          include(
            receiver_class: X,
            method_id: :func,
            arguments: [include(op: :keyrest, type: Hash)],
          )
        ) }
      end
    end

    context "def func(**option)" do
      before do
        class X
          def func(**option) end
        end
      end

      context "func(a: 1, b: 2)" do
        let(:body) { -> { X.new.func(a: 1, b: 2) } }

        it { is_expected.to include(
          include(
            receiver_class: X,
            method_id: :func,
            arguments: [include(op: :keyrest, name: :option, type: Hash)],
          )
        ) }
      end
    end

    context "Class singleton method" do
      context "def X.func(**option)" do
        before do
          def X.func(**option) end
        end

        context "X.func(a: 1, b: 2)" do
          let(:body) { -> { X.func(a: 1, b: 2) } }

          it { is_expected.to include(
            include(
              receiver_class: X,
              method_id: :func,
              singleton_method?: true
            )
          ) }
        end
      end

      context "def X.func" do
        before do
          def X.func; end
        end

        context "X.func" do
          let(:body) { -> { X.func } }

          it { is_expected.to include(
            include(
              receiver_class: X,
              method_id: :func,
              singleton_method?: true
            )
          ) }

        end
      end

      context "def X.func with private" do
        before do
          class <<X
            private def func; end
          end
        end

        context "func" do
          let(:body) { -> { X.send(:func) } }

          it { is_expected.to include(
            include(
              receiver_class: X,
              method_id: :func,
              singleton_method?: true,
              visibility: :private
            )
          ) }
        end
      end

      context "def X.func with protected" do
        before do
          class <<X
            protected def func; end
          end
        end

        context "func" do
          let(:body) { -> { X.send(:func) } }

          it { is_expected.to include(
            include(
              receiver_class: X,
              method_id: :func,
              singleton_method?: true,
              visibility: :protected
            )
          ) }
        end
      end
    end

    context "Module singleton method" do
      context "def X.func" do
        before do
          def M.func; end
        end

        context "M.func" do
          let(:body) { -> { M.func } }

          it { is_expected.to include(
            include(
              receiver_class: M,
              method_id: :func,
              singleton_method?: true
            )
          ) }
        end
      end
    end

    context "defined super class" do
      before do
        class Super1
          def func1; end
        end

        class Super2 < Super1
          def func2; end
        end

        class Super3 < Super2
          def func3; end
        end
      end

      context "func(1, 2)" do
        let(:body) { -> {
          Super1.new.func1
          Super2.new.func1
          Super2.new.func2
          Super3.new.func1
          Super3.new.func2
          Super3.new.func3
        } }
        it { is_expected.to include(
          include(
            receiver_class: Super1,
            receiver_defined_class: Super1,
            method_id: :func1,
          ),
          include(
            receiver_class: Super2,
            receiver_defined_class: Super1,
            method_id: :func1,
          ),
          include(
            receiver_class: Super3,
            receiver_defined_class: Super1,
            method_id: :func1,
          ),
          include(
            receiver_class: Super3,
            receiver_defined_class: Super2,
            method_id: :func2,
          ),
          include(
            receiver_class: Super3,
            receiver_defined_class: Super3,
            method_id: :func3,
          )
        ) }
      end
    end

    context "defined singleton_method super class" do
      before do
        class Super1
          def self.func1; end
        end

        class Super2 < Super1
          def self.func2; end
        end

        class Super3 < Super2
          def self.func3; end
        end
      end

      context "func(1, 2)" do
        let(:body) { -> {
          Super1.func1
          Super2.func1
          Super2.func2
          Super3.func1
          Super3.func2
          Super3.func3
        } }
        it { is_expected.to include(
          include(
            receiver_class: Super1,
            receiver_defined_class: Super1,
            method_id: :func1,
            singleton_method?: true,
          ),
          include(
            receiver_class: Super2,
            receiver_defined_class: Super1,
            method_id: :func1,
            singleton_method?: true,
          ),
          include(
            receiver_class: Super3,
            receiver_defined_class: Super1,
            method_id: :func1,
            singleton_method?: true,
          ),
          include(
            receiver_class: Super3,
            receiver_defined_class: Super2,
            method_id: :func2,
            singleton_method?: true,
          ),
          include(
            receiver_class: Super3,
            receiver_defined_class: Super3,
            method_id: :func3,
            singleton_method?: true,
          )
        ) }
      end
    end

    context "object singleton_method" do
      context "def X.func(**option)" do
        let(:x) { X.new }
        let(:body) {
          obj = x
          def obj.func(a); end
          -> {
            obj.func(a: 1, b: 2)
          }
        }

        it { is_expected.to include(
          include(
            defined_class: x.singleton_class,
            receiver_class: x,
            receiver_defined_class: x.singleton_class,
            method_id: :func,
            singleton_method?: true
          )
        ) }
      end
    end

    context "assigned instance variagles" do
      before do
        class X
          def func1
            @value1 = 1
          end

          def func2
            @value2 = "hoge"
          end

          def func3
            @value1 = []
            @value2 = 2
            @value3 = {}
            @value1 = :hoge
          end
        end
      end
      let(:body) { -> {
        x = X.new
        x.func1
        x.func2
        x.func3
      } }

      it { is_expected.to include(
        include(
          receiver_class: X,
          method_id: :func1,
          instance_variables_class: { :@value1 => Integer }
        ),
        include(
          receiver_class: X,
          method_id: :func2,
          instance_variables_class: { :@value1 => Integer, :@value2 => String }
        ),
        include(
          receiver_class: X,
          method_id: :func3,
          instance_variables_class: { :@value1 => Symbol, :@value2 => Integer, :@value3 => Hash }
        )
      ) }
    end

    context "nested called" do
      let(:body) { -> {
        load "#{__dir__}/test_called_method_nested_call_example.rb"
      } }

      it do
        func1 = -> (method_id, line) {
          include(method_id: :func1, called_method_id: method_id, called_lineno: line, called_methods: [])
        }
        func2 = -> (method_id, line) {
          include(method_id: :func2, called_method_id: method_id, called_lineno: line, called_methods: [func1[:func2, 6], func1[:func2, 8], func1[:func2, 8]])
        }
        func3 = -> (method_id, line) {
          include(method_id: :func3, called_method_id: method_id, called_lineno: line, called_methods: [func1[:func3, 13], func1[:func3, 15], func2[:func3, 15]])
        }
        func4 = -> (method_id, line) {
          include(method_id: :func4, called_method_id: method_id, called_lineno: line, called_methods: [func3[:func4, 21], func1[:func4, 22], func3[:func4, 23], func2[:func4, 23]])
        }

        expect(trace[:called_methods].first).to include(
          called_methods: [func4[nil, 26], func2[nil, 27], func4[nil, 27],]
        )
      end
    end

    context "nested called with block" do
      let(:body) { -> {
        load "#{__dir__}/test_called_method_nested_call_with_block_example.rb"
      } }

      it do
        func1_block = -> (line, method_id) {
          include(method_id: method_id, called_method_id: :func1, called_lineno: line, called_methods: [], block?: true)
        }
        func1 = -> (line, called_method) {
          include(
            method_id: :func1, called_method_id: called_method, called_lineno: line,
            called_methods: [func1_block[2, called_method], func1_block[3, called_method]],
            block: [func1_block[2, called_method], func1_block[3, called_method]]
          )
        }

        func2_block = -> (line, method_id) {
          include(method_id: method_id, called_method_id: :func2, called_lineno: line, called_methods: [], block?: true)
        }
        func2 = -> (line, called_method) {
          include(
            method_id: :func2, called_method_id: called_method, called_lineno: line,
            called_methods: [func1[7, :func2], func2_block[7, called_method]],
            block: [func2_block[7, called_method]]
          )
        }

        expect(trace[:called_methods].first).to include(
          called_methods: [func2[10, nil]]
        )
      end
    end

    context "call with block in block" do
      let(:body) { -> {
        load "#{__dir__}/test_called_method_nested_call_block_in_block_example.rb"
      } }

      it do
        func1_block = -> (line, method_id) {
          include(method_id: method_id, called_method_id: :func1, called_lineno: line, called_methods: [], block?: true)
        }
        func1 = -> (line, called_method) {
          include(
            method_id: :func1, called_method_id: called_method, called_lineno: line,
            called_methods: [func1_block[2, called_method]],
            block: [func1_block[2, called_method]]
          )
        }

        func2_block = -> (line, method_id, called_methods) {
          include(method_id: method_id, called_method_id: :func2, called_lineno: line, called_methods: called_methods, block?: true)
        }
        func2 = -> (line, called_method) {
          include(
            method_id: :func2, called_method_id: called_method, called_lineno: line,
            called_methods: [func2_block[6, called_method, [func1[11, called_method]]]],
            block: [func2_block[6, called_method, [func1[11, called_method]]]]
          )
        }

        func3 = -> (line, called_method) {
          include(
            method_id: :func3, called_method_id: called_method, called_lineno: line,
            called_methods: include(func2[10, :func3])
          )
        }

        expect(trace[:called_methods].first).to include(
          called_methods: [func3[15, nil]]
        )
      end
    end

    describe "rbs_type" do
      context "with symbol literals" do
        let(:body) { -> { X.new.func(:first, :second) } }
        before do
          class X
            def func(a, b) a end
          end
        end

        it { is_expected.to include(
          include(
            arguments: [
              include(op: :req, name: :a, type: Symbol, rbs_type: include(type: Symbol, value: :first, args: []), value_object_id: :first.object_id),
              include(op: :req, name: :b, type: Symbol, rbs_type: include(type: Symbol, value: :second, args: []), value_object_id: :second.object_id)
            ],
            return_value_rbs_type: include(type: Symbol, value: :first, args: [])
          )
        ) }
      end

      context "with integer literals" do
        let(:body) { -> { X.new.func(100, 200) } }
        before do
          class X
            def func(a, b) a end
          end
        end

        it { is_expected.to include(
          include(
            arguments: [
              include(op: :req, name: :a, type: Integer, rbs_type: include(type: Integer, value: 100, args: []), value_object_id: 100.object_id),
              include(op: :req, name: :b, type: Integer, rbs_type: include(type: Integer, value: 200, args: []), value_object_id: 200.object_id)
            ],
            return_value_rbs_type: include(type: Integer, value: 100, args: [])
          )
        ) }
      end

      context "with Array" do
        let(:body) { -> { X.new.func([:symbol, 42]) } }
        before do
          class X
            def func(a) a end
          end
        end

        it { is_expected.to include(
          include(
            arguments: [
              include(op: :req, name: :a, type: Array, rbs_type: include(type: Array, args: [[include(type: Symbol, value: :symbol), include(type: Integer, value: 42)]])),
            ],
            return_value_rbs_type: include(type: Array, args: [[include(type: Symbol, value: :symbol), include(type: Integer, value: 42)]])
          )
        ) }

        context "empty" do
          let(:body) { -> { X.new.func([]) } }

          it { is_expected.to include(
            include(
              arguments: [
                include(op: :req, name: :a, type: Array, rbs_type: include(type: Array, args: [[]])),
              ],
              return_value_rbs_type: include(type: Array, args: [[]])
            )
          ) }
        end
      end

      context "with Hash" do
        let(:body) { -> { X.new.func( { a: 1, "hoge" => 3.14 } ) } }
        before do
          class X
            def func(a) a end
          end
        end

        it { is_expected.to include(
          include(
            arguments: [
              include(op: :req, name: :a, type: Hash, rbs_type: include(type: Hash, args: [[include(type: Symbol, value: :a), include(type: String, value: nil)], [include(type: Integer, value: 1), include(type: Float)]])),
            ],
            return_value_rbs_type: include(type: Hash, args: [[include(type: Symbol, value: :a), include(type: String, value: nil)], [include(type: Integer, value: 1), include(type: Float)]])
          )
        ) }

        context "empty" do
          let(:body) { -> { X.new.func({}) } }

          it { is_expected.to include(
            include(
              arguments: [
                include(op: :req, name: :a, type: Hash, rbs_type: include(type: Hash, args: [[], []])),
              ],
              return_value_rbs_type: include(type: Hash, args: [[], []])
            )
          ) }
        end
      end
    end

    context "options with `target_filepath_pattern`" do
      let(:options) { { target_filepath_pattern: /test_called_method_nested_call_example/ } }
      let(:body) {
        -> {
          load "#{__dir__}/test_called_method_nested_call_example.rb"
          load "#{__dir__}/test_called_method_nested_call_block_in_block_example.rb"
        }
      }

      it { expect(subject.map { _1[:path] }).to be_all { /test_called_method_nested_call_example/ =~ _1 } }
    end

    context "options with `ignore_filepath_pattern`" do
      let(:options) { { ignore_filepath_pattern: /test_called_method_nested_call_block_in_block_example/ } }
      let(:body) {
        -> {
          load "#{__dir__}/test_called_method_nested_call_example.rb"
          load "#{__dir__}/test_called_method_nested_call_block_in_block_example.rb"
        }
      }

      it { expect(subject.map { _1[:path] }).to be_all { /called_method_spec|test_called_method_nested_call_example/ =~ _1 } }
    end

    context "options with `target_filepath_pattern` and `ignore_filepath_pattern`" do
      let(:options) { {
        target_filepath_pattern: /test_called_method_nested_call_block_in_block_example/,
        ignore_filepath_pattern: /test_called_method_nested_call_block_in_block_example/,
      } }
      let(:body) {
        -> {
          load "#{__dir__}/test_called_method_nested_call_example.rb"
          load "#{__dir__}/test_called_method_nested_call_block_in_block_example.rb"
        }
      }

      it { expect(subject.map { _1[:path] }).to be_all { /called_method_spec|test_called_method_nested_call_example/ =~ _1 } }
    end

    context "options with `target_classname_pattern`" do
      let(:options) { { target_classname_pattern: /^TargetClass$/ } }
      let(:body) {
        class TargetBaseClass
          def func; end
        end

        class TargetClass < TargetBaseClass
          def func2; end
        end

        class NoTargetClass < TargetClass
          def func3; end
        end

        obj1 = TargetClass.new
        obj2 = NoTargetClass.new
        -> {
          obj1.func
          obj1.func2

          obj2.func
          obj2.func2
          obj2.func3
        }
      }

      it { expect(subject.map { [_1[:receiver_class], _1[:receiver_defined_class]] }).to eq [
        [TargetClass, TargetBaseClass],
        [TargetClass, TargetClass],
        [NoTargetClass, TargetClass]
      ] }
    end

    context "options with `ignore_classname_pattern`" do
      let(:options) { { ignore_classname_pattern: /^TargetClass$/ } }
      let(:body) {
        class TargetBaseClass
          def func; end
        end

        class TargetClass < TargetBaseClass
          def func2; end
        end

        class NoTargetClass < TargetClass
          def func3; end
        end

        obj1 = TargetClass.new
        obj2 = NoTargetClass.new
        -> {
          obj1.func
          obj1.func2

          obj2.func
          obj2.func2
          obj2.func3
        }
      }

      it { expect(subject.map { [_1[:receiver_class], _1[:receiver_defined_class]] }).to eq [
        [RSpec::ExampleGroups::RBSDynamicTracerCalledMethod::Trace::OptionsWithIgnoreClassnamePattern,
         RSpec::ExampleGroups::RBSDynamicTracerCalledMethod::Trace::OptionsWithIgnoreClassnamePattern::LetDefinitions],
         [NoTargetClass, TargetBaseClass],
         [NoTargetClass, NoTargetClass]
      ] }
    end

    context "options with `target_classname_pattern` and `ignore_classname_pattern`" do
      let(:options) { {
        target_classname_pattern: /TargetClass/,
        ignore_classname_pattern: /No/,
      } }
      let(:body) {
        class TargetBaseClass
          def func; end
        end

        class TargetClass < TargetBaseClass
          def func2; end
        end

        class NoTargetClass < TargetClass
          def func3; end
        end

        obj1 = TargetClass.new
        obj2 = NoTargetClass.new
        -> {
          obj1.func
          obj1.func2

          obj2.func
          obj2.func2
          obj2.func3
        }
      }

      it { expect(subject.map { [_1[:receiver_class], _1[:receiver_defined_class]] }).to eq [
        [RSpec::ExampleGroups::RBSDynamicTracerCalledMethod::Trace::OptionsWithTargetClassnamePatternAndIgnoreClassnamePattern,
         RSpec::ExampleGroups::RBSDynamicTracerCalledMethod::Trace::OptionsWithTargetClassnamePatternAndIgnoreClassnamePattern::LetDefinitions],
         [TargetClass, TargetBaseClass],
         [TargetClass, TargetClass]
      ] }
    end

    context "nameless" do
      context "def func(*)" do
        before do
          class X
            def func(*) end
          end
        end

        context "func(1, 2)" do
          let(:body) { -> { X.new.func(1, 2) } }
          it { is_expected.to include(
            include(
              receiver_class: X,
              method_id: :func,
              visibility: :public,
              singleton_method?: false,
              arguments: [include(op: :rest, type: Array, rbs_type: { type: Array, args: [[]], value: nil })],
              return_value_class: NilClass,
              return_value_rbs_type: { type: NilClass, args: [], value: nil }
            )
          ) }
        end
      end

      context "def func(**)" do
        before do
          class X
            def func(**) end
          end
        end

        context "func(1, 2)" do
          let(:body) { -> { X.new.func(a: 1, b: 2) } }
          it { is_expected.to include(
            include(
              receiver_class: X,
              method_id: :func,
              visibility: :public,
              singleton_method?: false,
              arguments: [include(op: :keyrest, type: Hash, rbs_type: { type: Hash, args: [[], []], value: nil })],
              return_value_class: NilClass,
              return_value_rbs_type: { type: NilClass, args: [], value: nil }
            )
          ) }
        end
      end
    end
  end

  describe "#ignore_rbs_dynamic_trace" do
    using RBS::Dynamic::Refine::EachCalledMethod
    class X
      def func1; end
      def func2; end
      def func3; end
    end

    let(:klass) { X }
    let(:tracer) { RBS::Dynamic::Tracer::CalledMethod.new }
    subject {
      x = X.new
      tracer = RBS::Dynamic::Tracer::CalledMethod.new
      tracer.trace {
        x.func1
        tracer.ignore_rbs_dynamic_trace { x.func2 }
        x.func3
      }
      tracer.to_a
    }

    it { is_expected.to include(
      include(
        receiver_class: X,
        method_id: :func1,
      ),
      include(
        receiver_class: X,
        method_id: :func3,
      ),
    ) }
  end
end
