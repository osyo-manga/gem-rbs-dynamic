# frozen_string_literal: true

RSpec.describe RBS::Dynamic::Builder::Class do
  class X; end
  let(:klass_builder) { RBS::Dynamic::Builder::Class.new(X) }
  define_method(:rbs) { |decl = klass_builder.build|
    stdout = StringIO.new
    writer = RBS::Writer.new(out: stdout)
    writer.write([decl])
    stdout.string
  }

  describe "#build" do
    subject { rbs }

    it { is_expected.to include "class X\nend" }
  end

  describe "#add_constant_variable" do
    subject { klass_builder.add_constant_variable(*args) }

    context "single types" do
      let(:args) { [:VALUE, String] }
      it { expect { subject }.to change { rbs }.to include "VALUE: String" }
    end

    context "multi types" do
      let(:args) { [:VALUE, [String, Array]] }
      it { expect { subject }.to change { rbs }.to include "VALUE: String | Array" }
    end

    context "mult called" do
      subject {
        klass_builder.add_constant_variable(:VALUE1, Integer)
        klass_builder.add_constant_variable(:VALUE1, Hash)
        klass_builder.add_constant_variable(:VALUE2, String)
        klass_builder.add_constant_variable(:VALUE2, Hash)
        klass_builder.add_constant_variable(:VALUE2, String)
      }
      it { expect { subject }.to change { rbs }.to include "VALUE1: Integer | Hash" }
      it { expect { subject }.to change { rbs }.to include "VALUE2: String | Hash" }
    end
  end

  describe "#add_instance_variable" do
    subject { klass_builder.add_instance_variable(*args) }

    context "single types" do
      let(:args) { [:@value, String] }
      it { expect { subject }.to change { rbs }.to include "@value: String" }
    end

    context "multi types" do
      let(:args) { [:@value, [String, Array]] }
      it { expect { subject }.to change { rbs }.to include "@value: String | Array" }
    end

    context "mult called" do
      subject {
        klass_builder.add_instance_variable(:@value1, Integer)
        klass_builder.add_instance_variable(:@value1, Hash)
        klass_builder.add_instance_variable(:@value2, String)
      }
      it { expect { subject }.to change { rbs }.to include "@value1: Integer | Hash" }
      it { expect { subject }.to change { rbs }.to include "@value2: String" }
    end
  end
end
