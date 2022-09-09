# frozen_string_literal: true

RSpec.describe RBS::Dynamic::Builder::Methods do
  describe "#build" do
    class X; end

    define_method(:eq_rbs) { |code| satisfy { |decl| expect(rbs decl).to eq code } }
    define_method(:have_rbs_method) { |method| satisfy(method.inspect) { |decl|
      expect(rbs decl).to eq <<~EOS
        class X
          #{method.split("\n").join("\n  ")}
        end
      EOS
    } }
    define_method(:rbs) { |decl = subject|
      stdout = StringIO.new
      writer = RBS::Writer.new(out: stdout)
      writer.write([decl])
      stdout.string
    }
    let(:klass_builder) { RBS::Dynamic::Builder::Class.new(X) }

    subject { klass_builder.build }

    before do
      sigs.each { |sig|
        klass_builder.add_method(:func, **sig)
      }
    end

    context "empty" do
      let(:sigs) { [{}] }

      it { is_expected.to have_rbs_method "def func: () -> void" }
    end

    context "singleton method" do
      let(:sigs) { [] }
      let(:singleton_sigs) { [{ return_type: String }] }
      before do
        singleton_sigs.each { |sig|
          klass_builder.add_singleton_method(:func, **sig)
        }
      end

      it { is_expected.to have_rbs_method("def self.func: () -> String") }
    end

    describe "return_type" do
      context "single return_type" do
        let(:sigs) { [{ return_type: String }] }

        it { is_expected.to have_rbs_method "def func: () -> String" }
      end

      context "other return_types" do
        let(:sigs) { [
          { return_type: String },
          { return_type: Integer },
          { return_type: Array }
        ] }
        it { is_expected.to have_rbs_method "def func: () -> (String | Integer | Array)" }
      end

      context "same return_type" do
        let(:sigs) { [
          { return_type: String },
          { return_type: String },
          { return_type: String }
        ] }
        it { is_expected.to have_rbs_method "def func: () -> String" }
      end

      context "with nil" do
        let(:sigs) { [
          { return_type: String },
          { return_type: nil }
        ] }
        it { is_expected.to have_rbs_method "def func: () -> String?" }
      end

      context "only nil" do
        let(:sigs) { [
          { return_type: nil }
        ] }
        it { is_expected.to have_rbs_method "def func: () -> nil" }

        context "multi sigs" do
          let(:sigs) { [
            { return_type: nil },
            { return_type: nil },
            { return_type: nil }
          ] }
          it { is_expected.to have_rbs_method "def func: () -> nil" }
        end
      end

      context "with NilClass" do
        let(:sigs) { [
          { return_type: String },
          { return_type: NilClass }
        ] }
        it { is_expected.to have_rbs_method "def func: () -> String?" }
      end

      context "without return_type" do
        let(:sigs) { [{ required_positionals: [{ type: String }] }] }
        it { is_expected.to have_rbs_method "def func: (String) -> void" }

        context "multi sigs" do
          let(:sigs) { [
            { required_positionals: [{ type: String }] },
            { required_positionals: [{ type: String }] },
            { required_positionals: [{ type: String }] },
          ] }
          it { is_expected.to have_rbs_method "def func: (String) -> void" }
        end

        context "with nil" do
          let(:sigs) { [
            { required_positionals: [{ type: String }] },
            { required_positionals: [{ type: String }], return_type: nil },
            { required_positionals: [{ type: String }] },
          ] }
          it { is_expected.to have_rbs_method "def func: (String) -> nil" }
        end
      end

      context "type with args" do
        context "return_type with args" do
          let(:sigs) { [
            { required_positionals: [{ type: String }], return_type: { type: Array, args: [[String]] }  },
            { required_positionals: [{ type: String }], return_type: { type: Array, args: [[Symbol]] } },
          ] }
          it { is_expected.to have_rbs_method "def func: (String) -> Array[String | Symbol]" }
        end

        context "required_positionals with args" do
          context "args is empty" do
            let(:sigs) { [
              { required_positionals: [{ type: { type: String, args: [] } }], return_type: { type: Symbol, args: [] }  },
              { required_positionals: [{ type: String }], return_type: String },
            ] }
            it { is_expected.to have_rbs_method "def func: (String) -> (Symbol | String)" }
          end
        end

        context "return_type with nil" do
          let(:sigs) { [
            { required_positionals: [{ type: String }], return_type: { type: nil, args: [] }  },
            { required_positionals: [{ type: String }], return_type: String },
            { required_positionals: [{ type: String }], return_type: { type: Symbol, args: [] }   },
          ] }
          it { is_expected.to have_rbs_method "def func: (String) -> (String | Symbol)?" }
        end

        context "return_type with NilClass" do
          let(:sigs) { [
            { required_positionals: [{ type: String }], return_type: { type: NilClass, args: [] }  },
            { required_positionals: [{ type: String }], return_type: String },
          ] }
          it { is_expected.to have_rbs_method "def func: (String) -> String?" }
        end
      end
    end

    describe "required_positionals" do
      context "empty required_positionals" do
        let(:sigs) { [
          { required_positionals: [] },
        ] }

        it { is_expected.to have_rbs_method "def func: () -> void" }

        context "multi arguments" do
          let(:sigs) { [
            { required_positionals: [] },
            { required_positionals: [] }
          ] }

          it { is_expected.to have_rbs_method "def func: () -> void" }
        end
      end

      context "with name" do
        let(:sigs) { [
          { required_positionals: [{ name: "n", type: String }] },
        ] }

        it { is_expected.to have_rbs_method "def func: (String n) -> void" }

        context "without type" do
          let(:sigs) { [
            { required_positionals: [{ name: "n"}] },
          ] }

          it { is_expected.to have_rbs_method "def func: (untyped n) -> void" }
        end
      end

      context "only nil" do
        let(:sigs) { [
          { required_positionals: [{ type: nil }] },
        ] }

        it { is_expected.to have_rbs_method "def func: (nil) -> void" }
      end

      context "with NilClass" do
        let(:sigs) { [
          { required_positionals: [{ type: String }] },
          { required_positionals: [{ type: NilClass }] }
        ] }

        it { is_expected.to have_rbs_method "def func: (String?) -> void" }
      end

      context "with nil" do
        let(:sigs) { [
          { required_positionals: [{ type: String }] },
          { required_positionals: [{ type: nil }] }
        ] }

        it { is_expected.to have_rbs_method "def func: (String?) -> void" }
      end

      context "other arguments num" do
        let(:sigs) { [
          { required_positionals: [{ type: String }, { type: Integer }] },
          { required_positionals: [{ type: String }] },
          { required_positionals: [{ type: String }, { type: Integer }, { type: Array }] },
        ] }

        it { is_expected.to have_rbs_method(<<~EOS) }
          def func: (String, Integer) -> void
                  | (String) -> void
                  | (String, Integer, Array) -> void
        EOS
      end

      context "multi arguments" do
        let(:sigs) { [
          { required_positionals: [{ name: "n", type: String }, { name: "m", type: Integer }, { type: Array }] },
        ] }

        it { is_expected.to have_rbs_method "def func: (String n, Integer m, Array) -> void" }

        context "and multi sigs" do
          let(:sigs) { [
            { required_positionals: [{ name: "n", type: String }, { name: "m", type: Integer }, { type: Array }] },
            { required_positionals: [{ name: "n", type: Array }, { name: "m", type: String }, { type: Hash }] },
          ] }

          it { is_expected.to have_rbs_method "def func: (String | Array n, Integer | String m, Array | Hash) -> void" }
        end

        context "other sigs" do
          let(:sigs) { [
            { required_positionals: [{ name: "n", type: String }, { name: "m", type: Integer }, { type: Array }] },
            { required_positionals: [{ name: "n", type: Array }, { name: "m", type: String }] },
          ] }

          it { is_expected.to have_rbs_method(<<~EOS) }
            def func: (String n, Integer m, Array) -> void
                    | (Array n, String m) -> void
          EOS
        end
      end

      context "with other type and same return_type" do
        let(:sigs) { [
          { required_positionals: [{ type: String }] },
          { required_positionals: [{ type: Integer }] }
        ] }

        it { is_expected.to have_rbs_method "def func: (String | Integer) -> void" }

        context "with nil" do
          let(:sigs) { [
            { required_positionals: [{ type: String }] },
            { required_positionals: [{ type: nil }] },
            { required_positionals: [{ type: Integer }] }
          ] }

          it { is_expected.to have_rbs_method "def func: ((String | Integer)?) -> void" }
        end
      end

      context "with return_type" do
        context "other param types and other return_type" do
          let(:sigs) { [
            { required_positionals: [{ type: String }], return_type: Array },
            { required_positionals: [{ type: Integer }], return_type: Hash }
          ] }

          it { is_expected.to have_rbs_method(<<~EOS) }
            def func: (String) -> Array
                    | (Integer) -> Hash
          EOS
        end

        context "same param types and same return_type" do
          let(:sigs) { [
            { required_positionals: [{ type: String }], return_type: Array },
            { required_positionals: [{ type: String }], return_type: Array }
          ] }

          it { is_expected.to have_rbs_method "def func: (String) -> Array" }
        end

        context "same param types and other return_type" do
          let(:sigs) { [
            { required_positionals: [{ type: String }], return_type: Array },
            { required_positionals: [{ type: String }], return_type: Integer }
          ] }

          it { is_expected.to have_rbs_method "def func: (String) -> (Array | Integer)" }
        end

        context "other param num and other return_type" do
          let(:sigs) { [
            { required_positionals: [{ type: String }, { type: Integer }], return_type: Array },
            { required_positionals: [{ type: String }], return_type: Integer }
          ] }

          it { is_expected.to have_rbs_method(<<~EOS) }
            def func: (String, Integer) -> Array
                    | (String) -> Integer
          EOS
        end

        context "other param types and same return_type NilClass" do
          let(:sigs) { [
            { required_positionals: [{ type: Integer }], return_type: Array },
            { required_positionals: [{ type: String }], return_type: Array }
          ] }

          it { is_expected.to have_rbs_method "def func: (Integer | String) -> Array" }
        end
      end

      context "with visibility" do
        context "private" do
          let(:sigs) { [
            { visibility: :private, required_positionals: [{ type: Integer }], return_type: Array },
            { visibility: :private, required_positionals: [{ type: String }], return_type: Array },
            { visibility: :private, required_positionals: [{ type: Array }], return_type: Integer },
            { visibility: :private, required_positionals: [{ type: Array }], return_type: Hash }
          ] }

          it { is_expected.to have_rbs_method(<<~EOS) }
            private def func: (Integer | String) -> Array
                            | (Array) -> (Integer | Hash)
          EOS
        end
      end

      context "type with args" do
        let(:sigs) { [
          { required_positionals: [{ type: { type: Symbol, args: [] } }], return_type: Integer },
          { required_positionals: [{ type: String }], return_type: Integer }
        ] }

        it { is_expected.to have_rbs_method "def func: (Symbol | String) -> Integer" }
      end
    end

    describe "optional_positionals" do
      context "with nil" do
        let(:sigs) { [
          { optional_positionals: [{ type: String }] },
          { optional_positionals: [{ type: nil }] }
        ] }

        it { is_expected.to have_rbs_method "def func: (?String?) -> void" }
      end

      context "type with args" do
        let(:sigs) { [
          { optional_positionals: [{ type: { type: Symbol, args: [] } }], return_type: Integer },
          { optional_positionals: [{ type: String }], return_type: Integer },
          { optional_positionals: [{ type: { type: Float, args: [] } }], return_type: Integer }
        ] }

        it { is_expected.to have_rbs_method "def func: (?Symbol | String | Float) -> Integer" }
      end
    end

    describe "optional_positionals and required_positionals" do
      context "other arguments" do
        let(:sigs) { [
          { required_positionals: [{ type: String }] },
          { optional_positionals: [{ type: Integer }] }
        ] }

        it { is_expected.to have_rbs_method(<<~EOS) }
          def func: (String) -> void
                  | (?Integer) -> void
        EOS
      end

      context "same arguments" do
        let(:sigs) { [
          { required_positionals: [{ type: String }] },
          { optional_positionals: [{ type: String }] }
        ] }

        it { is_expected.to have_rbs_method(<<~EOS) }
          def func: (String) -> void
                  | (?String) -> void
        EOS
      end

      context "with nil in required_positionals" do
        let(:sigs) { [
          { required_positionals: [{ type: String }] },
          { optional_positionals: [{ type: String }] },
          { required_positionals: [{ type: nil }] },
        ] }

        it { is_expected.to have_rbs_method(<<~EOS) }
          def func: (String?) -> void
                  | (?String) -> void
        EOS
      end

      context "with nil in optional_positionals" do
        let(:sigs) { [
          { required_positionals: [{ type: String }] },
          { optional_positionals: [{ type: nil }] },
          { optional_positionals: [{ type: String }] },
        ] }

        it { is_expected.to have_rbs_method(<<~EOS) }
          def func: (String) -> void
                  | (?String?) -> void
        EOS
      end

      context "with nil and multi arguments" do
        let(:sigs) { [
          { required_positionals: [{ type: String }] },
          { required_positionals: [{ type: nil }] },
          { optional_positionals: [{ type: String }] },
          { optional_positionals: [{ type: nil }] },
          { required_positionals: [{ type: Array }] },
        ] }

        it { is_expected.to have_rbs_method(<<~EOS) }
          def func: ((String | Array)?) -> void
                  | (?String?) -> void
        EOS
      end
    end

    describe "required_keywords" do
      context "empty required_positionals" do
        let(:sigs) { [
          { required_keywords: [] },
        ] }

        it { is_expected.to have_rbs_method "def func: () -> void" }

        context "multi arguments" do
          let(:sigs) { [
            { required_keywords: [] },
            { required_keywords: [] }
          ] }

          it { is_expected.to have_rbs_method "def func: () -> void" }
        end
      end

      context "only nil" do
        let(:sigs) { [
          { required_keywords: [{ name: "n", type: nil }] },
        ] }

        it { is_expected.to have_rbs_method "def func: (n: nil) -> void" }
      end

      context "with NilClass" do
        let(:sigs) { [
          { required_keywords: [{ name: "n", type: String }] },
          { required_keywords: [{ name: "n", type: NilClass }] }
        ] }

        it { is_expected.to have_rbs_method "def func: (n: String?) -> void" }
      end

      context "with nil" do
        let(:sigs) { [
          { required_keywords: [{ name: "n", type: String }] },
          { required_keywords: [{ name: "n", type: nil }] }
        ] }

        it { is_expected.to have_rbs_method "def func: (n: String?) -> void" }
      end

      context "other arguments num" do
        let(:sigs) { [
          { required_keywords: [{ name: "n", type: String }, { name: "m", type: Integer }] },
          { required_keywords: [{ name: "n", type: String }] },
          { required_keywords: [{ name: "n", type: String }, { name: "m", type: Integer }, { name: "l", type: Array }] },
        ] }

        it { is_expected.to have_rbs_method(<<~EOS) }
          def func: (n: String, m: Integer) -> void
                  | (n: String) -> void
                  | (n: String, m: Integer, l: Array) -> void
        EOS
      end

      context "multi arguments" do
        let(:sigs) { [
          { required_keywords: [{ name: "n", type: String }, { name: "m", type: Integer }, { name: "l", type: Array }] },
        ] }

        it { is_expected.to have_rbs_method "def func: (n: String, m: Integer, l: Array) -> void" }
      end

      context "with other type and same return_type" do
        let(:sigs) { [
          { required_keywords: [{ name: "n", type: String }] },
          { required_keywords: [{ name: "n", type: Integer }] }
        ] }

        it { is_expected.to have_rbs_method "def func: (n: String | Integer) -> void" }

        context "with nil" do
          let(:sigs) { [
            { required_keywords: [{ name: "n", type: String }] },
            { required_keywords: [{ name: "n", type: nil }] },
            { required_keywords: [{ name: "n", type: Integer }] }
          ] }

          it { is_expected.to have_rbs_method "def func: (n: (String | Integer)?) -> void" }
        end
      end

      context "with return_type" do
        context "other param types and other return_type" do
          let(:sigs) { [
            { required_keywords: [{ name: "n", type: String }], return_type: Array },
            { required_keywords: [{ name: "n", type: Integer }], return_type: Hash }
          ] }

          it { is_expected.to have_rbs_method(<<~EOS) }
            def func: (n: String) -> Array
                    | (n: Integer) -> Hash
          EOS
        end

        context "same param types and same return_type" do
          let(:sigs) { [
            { required_keywords: [{ name: "n", type: String }], return_type: Array },
            { required_keywords: [{ name: "n", type: String }], return_type: Array }
          ] }

          it { is_expected.to have_rbs_method "def func: (n: String) -> Array" }
        end

        context "same param types and other return_type" do
          let(:sigs) { [
            { required_keywords: [{ name: "n", type: String }], return_type: Array },
            { required_keywords: [{ name: "n", type: String }], return_type: Integer }
          ] }

          it { is_expected.to have_rbs_method "def func: (n: String) -> (Array | Integer)" }
        end

        context "other param num and other return_type" do
          let(:sigs) { [
            { required_keywords: [{ name: "n", type: String }, { name: "m", type: Integer }], return_type: Array },
            { required_keywords: [{ name: "n", type: String }], return_type: Integer }
          ] }

          it { is_expected.to have_rbs_method(<<~EOS) }
            def func: (n: String, m: Integer) -> Array
                    | (n: String) -> Integer
          EOS
        end

        context "other param types and same return_type NilClass" do
          let(:sigs) { [
            { required_keywords: [{ name: "n", type: Integer }], return_type: Array },
            { required_keywords: [{ name: "n", type: String }], return_type: Array }
          ] }

          it { is_expected.to have_rbs_method "def func: (n: Integer | String) -> Array" }
        end
      end

      context "type with args" do
        let(:sigs) { [
          { required_keywords: [{ name: "n", type: { type: Symbol, args: [] } }], return_type: Integer },
          { required_keywords: [{ name: "n", type: String }], return_type: Integer }
        ] }

        it { is_expected.to have_rbs_method "def func: (n: Symbol | String) -> Integer" }
      end
    end

    describe "optional_keywords" do
      context "with nil" do
        let(:sigs) { [
          { optional_keywords: [{ name: "n", type: String }] },
          { optional_keywords: [{ name: "n", type: nil }] }
        ] }

        it { is_expected.to have_rbs_method "def func: (?n: String?) -> void" }
      end

      context "type with args" do
        let(:sigs) { [
          { optional_keywords: [{ name: "n", type: { type: Symbol, args: [] } }], return_type: Integer },
          { optional_keywords: [{ name: "n", type: String }], return_type: Integer }
        ] }

        it { is_expected.to have_rbs_method "def func: (?n: Symbol | String) -> Integer" }
      end
    end

    describe "optional_keywords and required_keywords" do
      context "other arguments" do
        let(:sigs) { [
          { required_keywords: [{ name: "n", type: String }] },
          { optional_keywords: [{ name: "n", type: Integer }] }
        ] }

        it { is_expected.to have_rbs_method(<<~EOS) }
          def func: (n: String) -> void
                  | (?n: Integer) -> void
        EOS
      end

      context "same arguments" do
        let(:sigs) { [
          { required_keywords: [{ name: "n", type: String }] },
          { optional_keywords: [{ name: "n", type: String }] }
        ] }

        it { is_expected.to have_rbs_method(<<~EOS) }
          def func: (n: String) -> void
                  | (?n: String) -> void
        EOS
      end

      context "with nil in required_keywords" do
        let(:sigs) { [
          { required_keywords: [{ name: "n", type: String }] },
          { optional_keywords: [{ name: "n", type: String }] },
          { required_keywords: [{ name: "n", type: nil }] },
        ] }

        it { is_expected.to have_rbs_method(<<~EOS) }
          def func: (n: String?) -> void
                  | (?n: String) -> void
        EOS
      end

      context "with nil in optional_keywords" do
        let(:sigs) { [
          { required_keywords: [{ name: "n", type: String }] },
          { optional_keywords: [{ name: "n", type: nil }] },
          { optional_keywords: [{ name: "n", type: String }] },
        ] }

        it { is_expected.to have_rbs_method(<<~EOS) }
          def func: (n: String) -> void
                  | (?n: String?) -> void
        EOS
      end

      context "with nil and multi arguments" do
        let(:sigs) { [
          { required_keywords: [{ name: "n", type: String }] },
          { required_keywords: [{ name: "n", type: nil }] },
          { optional_keywords: [{ name: "n", type: String }] },
          { optional_keywords: [{ name: "n", type: nil }] },
          { required_keywords: [{ name: "n", type: Array }] },
        ] }

        it { is_expected.to have_rbs_method(<<~EOS) }
          def func: (n: (String | Array)?) -> void
                  | (?n: String?) -> void
        EOS
      end
    end

    describe "rest_positionals" do
      let(:sigs) { [
        { rest_positionals: [{ name: "n", type: Array }], return_type: Array },
        { rest_positionals: [{ name: "n", type: Hash }], return_type: Hash }
      ] }

      it { is_expected.to have_rbs_method(<<~EOS) }
          def func: (*Array n) -> Array
                  | (*Hash n) -> Hash
        EOS
    end

    describe "trailing_positionals" do
      let(:sigs) { [
        {
          required_positionals: [{ name: "first", type: Integer }],
          rest_positionals: [{ name: "first", type: Hash }],
          trailing_positionals: [{ name: "first", type: Array }],
          return_type: Array
        },
      ] }

      it { is_expected.to have_rbs_method "def func: (Integer first, *Hash first, Array first) -> Array" }
    end

    describe "rest_keywords" do
      let(:sigs) { [
        { rest_keywords: [{ name: "n", type: Hash }], return_type: Hash },
        { rest_keywords: [{ name: "n", type: Array }], return_type: Array },
      ] }

      it { is_expected.to have_rbs_method "def func: (**Hash n) -> (Hash | Array)" }
    end

    describe "block" do
      let(:sigs) { [ { block: block_sigs }, ] }
      context "other sigunature" do
        let(:block_sigs) { [
          { required_positionals: [{ name: :n, type: Float }], return_type: Float },
          { required_positionals: [{ name: :n, type: String }, { name: :m, type: Float }], return_type: Integer },
          { required_positionals: [{ name: :n, type: Integer }], return_type: Hash }
        ] }

        it { is_expected.to have_rbs_method "def func: () ?{ (Float | String | Integer n, Float m) -> (Float | Integer | Hash) } -> void" }
      end
    end
  end
end
