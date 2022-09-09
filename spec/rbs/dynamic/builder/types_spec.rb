# frozen_string_literal: true

RSpec.describe RBS::Dynamic::Builder::Types do
  describe "#optional?" do
    subject { RBS::Dynamic::Builder::Types.new(types).optional? }

    context "types is []" do
      let(:types) { [] }
      it { is_expected.to eq false }
    end

    context "types is [nil]" do
      let(:types) { [nil] }
      it { is_expected.to eq false }
    end

    context "types is nil" do
      let(:types) { nil }
      it { is_expected.to eq false }
    end

    context "types is [NilClass]" do
      let(:types) { [NilClass] }
      it { is_expected.to eq false }
    end

    context "types is [NilClass, nil]" do
      let(:types) { [NilClass, nil] }
      it { is_expected.to eq false }
    end

    context "types is [String]" do
      let(:types) { [String] }
      it { is_expected.to eq false }
    end

    context "types is [String, nil]" do
      let(:types) { [String, nil] }
      it { is_expected.to eq true }
    end

    context "types is [String, NilClass]" do
      let(:types) { [String, NilClass] }
      it { is_expected.to eq true }
    end

    context "types is [String, NilClass, nil, nil NilClass, Integer]" do
      let(:types) { [String, NilClass] }
      it { is_expected.to eq true }
    end
  end

  describe "#build" do
    subject { RBS::Dynamic::Builder::Types.new(types).build.to_s }

    describe "namespace" do
      context "types is RBS::Types::Bases::Base" do
        let(:types) { RBS::Types::Bases::Base }
        it { is_expected.to eq "RBS::Types::Bases::Base" }
      end

      context "types is [RBS::Types::Bases::Base, RBS::Types::Bases::Base]" do
        let(:types) { [RBS::Types::Bases::Base, RBS::Types::Bases::Base] }
        it { is_expected.to eq "RBS::Types::Bases::Base" }
      end

      context "types is [RBS::Types::Bases::Base, RBS::Types::Optional]" do
        let(:types) { [RBS::Types::Bases::Base, RBS::Types::Optional] }
        it { is_expected.to eq "RBS::Types::Bases::Base | RBS::Types::Optional" }
      end
    end

    describe "Class instance type" do
      context "without namespaced" do
        let(:types) { [Integer] }
        it { is_expected.to eq "Integer" }
      end

      context "with namespaced" do
        let(:types) { [::Integer] }
        it { is_expected.to eq "Integer" }
      end

      context "with args" do
        context "args is value" do
          let(:types) { { type: Array, args: [[1, :hoge]] } }
          it { is_expected.to eq "Array[1 | :hoge]" }
        end

        context "args is Class" do
          let(:types) { { type: Array, args: [Integer] } }
          it { is_expected.to eq "Array[Integer]" }
        end

        context "empty" do
          let(:types) { { type: Array, args: [[]] } }
          it { is_expected.to eq "Array[untyped]" }
        end
      end
    end

    xdescribe "Interface type" do
    end

    xdescribe "Alias type" do
    end

    xdescribe "Class singleton type" do
    end

    describe "Literal type" do
      describe "string" do
        context "types is ['hoge', 'foo']" do
          let(:types) { ['hoge', 'foo'] }
          it { is_expected.to eq '"hoge" | "foo"' }
        end
      end

      describe "symbol" do
        context "types is [:red, :green, :blue]" do
          let(:types) { [:red, :green, :blue] }
          it { is_expected.to eq ":red | :green | :blue" }
        end
      end

      describe "integer" do
        context "types is [10, 20, 42]" do
          let(:types) { [10, 20, 42] }
          it { is_expected.to eq "10 | 20 | 42" }
        end
      end

      describe "boolean" do
        context "types is [true]" do
          let(:types) { [true] }
          it { is_expected.to eq "true" }
        end

        context "types is [false]" do
          let(:types) { [false] }
          it { is_expected.to eq "false" }
        end

        context "types is [TrueClass]" do
          let(:types) { [TrueClass] }
          it { is_expected.to eq "TrueClass" }
        end

        context "types is [FalseClass]" do
          let(:types) { [FalseClass] }
          it { is_expected.to eq "FalseClass" }
        end

        context "types is [true, true]" do
          let(:types) { [true, true] }
          it { is_expected.to eq "true" }
        end

        context "types is [true, false, true]" do
          let(:types) { [true, false, true] }
          it { is_expected.to eq "bool" }
        end

        context "types is [true, FalseClass]" do
          let(:types) { [true, FalseClass] }
          it { is_expected.to eq "bool" }
        end

        context "types is [TrueClass, FalseClass]" do
          let(:types) { [TrueClass, FalseClass] }
          it { is_expected.to eq "bool" }
        end

        context "types is [true, FalseClass, TrueClass]" do
          let(:types) { [true, FalseClass, TrueClass] }
          it { is_expected.to eq "bool" }
        end

        context "types is [true, FalseClass, TrueClass, false]" do
          let(:types) { [true, FalseClass, TrueClass] }
          it { is_expected.to eq "bool" }
        end

        context "with args" do
          let(:types) { { type: Array, args: [[true, false]] } }
          it { is_expected.to eq "Array[bool]" }
        end
      end

      context "with args" do
        let(:types) { { type: Array, args: [[true, 10, :hoge, "foo"]] } }
        it { is_expected.to eq "Array[true | 10 | :hoge | \"foo\"]" }
      end
    end

    describe "Union type" do
      context "types is [Integer, Integer, Integer]" do
        let(:types) { [Integer, Integer, Integer] }
        it { is_expected.to eq "Integer" }
      end

      context "types is [Integer, Integer, String, Array]" do
        let(:types) { [Integer, Integer, String, Array] }
        it { is_expected.to eq "Integer | String | Array" }
      end

      context "types is [true, Integer]" do
        let(:types) { [Integer, Integer, String, Array] }
        it { is_expected.to eq "Integer | String | Array" }
      end

      context "with args" do
        context "other types" do
          let(:types) { [{ type: String, args: [] }, { type: Symbol, args: [] }] }
          it { is_expected.to eq "String | Symbol" }
        end

        context "nested Hash types" do
          let(:types) { [{ type: Array, args: [[{ type: Array, args: [Integer] }, String]] }] }
          it { is_expected.to eq "Array[Array[Integer] | String]" }
        end

        context "same type and other type" do
          context "single args" do
            let(:types) { [{ type: Array, args: [[String]] }, { type: Array, args: [[nil]] }, { type: Array, args: [[Symbol]] }] }
            it { is_expected.to eq "Array[(String | Symbol)?]" }
          end

          context "multi args" do
            let(:types) { [{ type: Hash, args: [[Symbol], [String]] }, { type: Hash, args: [[String], [Symbol]] }] }
            it { is_expected.to eq "Hash[Symbol | String, String | Symbol]" }
          end
        end

        context "other args count" do
          let(:types) { [{ type: Array, args: [[Integer]] }, { type: Array, args: [] }, { type: Array, args: [[Symbol]] }] }
          it { is_expected.to eq "Array[Integer | Symbol] | Array" }
        end

        context "same args count and other args" do
          let(:types) { [{ type: Array, args: [[]] }, { type: Array, args: [[Integer]] }, { type: Array, args: [[]] }] }
          it { is_expected.to eq "Array[Integer]" }
        end

        context "with empty args" do
          let(:types) { [{ type: Array, args: [[Integer]] }, { type: Array, args: [[]] }] }
          it { is_expected.to eq "Array[Integer]" }
        end

        context "type is hash and Class" do
          let(:types) { [String, { type: String, args: [] }, Symbol] }
          it { is_expected.to eq "String | Symbol" }
        end
      end
    end

    xdescribe "Intersection type" do
    end

    describe "Optional type" do
      context "types is [nil, String]" do
        let(:types) { [nil, String] }
        it { is_expected.to eq "String?" }
      end

      context "types is [nil, String, Integer]" do
        let(:types) { [nil, String, Integer] }
        it { is_expected.to eq "(String | Integer)?" }
      end

      context "types is [nil, String, Integer, NilClass]" do
        let(:types) { [nil, String, Integer, NilClass] }
        it { is_expected.to eq "(String | Integer)?" }
      end

      context "wtih args" do
        context "args with nil" do
          let(:types) { { type: Array, args: [[String, nil]] } }
          it { is_expected.to eq "Array[String?]" }
        end

        context "types with nil" do
          let(:types) { [{ type: Array, args: [[String]] }, nil] }
          it { is_expected.to eq "Array[String]?" }
        end
      end
    end

    xdescribe "Record type" do
    end

    xdescribe "Tuples" do
    end

    xdescribe "Type variables" do
    end

    xdescribe "Proc type" do
    end

    xdescribe "self" do
    end

    context "same types" do
      let(:types) { [{ type: Array, args: [[String]] }, String, Integer, { type: Array, args: [[String]] }, String] }
      it { is_expected.to eq "Array[String] | String | Integer" }
    end

    context "type with args" do
      context "empty args" do
        let(:types) { { type: Array, args: [] } }
        it { is_expected.to eq "Array" }
      end

      context "single args" do
        let(:types) { { type: Array, args: [[String]] } }
        it { is_expected.to eq "Array[String]" }

        context "multi args" do
          let(:types) { { type: Array, args: [[String, Integer]] } }
          it { is_expected.to eq "Array[String | Integer]" }
        end
      end

      context "multi args" do
        let(:types) { { type: Hash, args: [[Symbol], [Integer]] } }
        it { is_expected.to eq "Hash[Symbol, Integer]" }

        context "multi args" do
          let(:types) { { type: Hash, args: [[Symbol, String], [Integer, nil]] } }
          it { is_expected.to eq "Hash[Symbol | String, Integer?]" }
        end
      end
    end
  end
end
