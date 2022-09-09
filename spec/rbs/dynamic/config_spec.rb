# frozen_string_literal: true

RSpec.describe RBS::Dynamic::Config do
  describe "#ignore_class_members" do
    subject { RBS::Dynamic::Config.new(options).ignore_class_members }

    context "key is string" do
      let(:options) { { "ignore-class_members" => %i(constant_variables) } }
      it { is_expected.to eq %i(constant_variables) }
    end

    context "key is symbol" do
      let(:options) { { ignore_class_members: %i(constant_variables) } }
      it { is_expected.to eq %i(constant_variables) }
    end

    context "value is symbol" do
      let(:options) { { ignore_class_members: %i(constant_variables) } }
      it { is_expected.to eq %i(constant_variables) }
    end

    context "value is string" do
      let(:options) { { ignore_class_members: %w(constant_variables) } }
      it { is_expected.to eq %i(constant_variables) }
    end
  end

  describe "#method_defined_calssses" do
    subject { RBS::Dynamic::Config.new(options).method_defined_calssses }

    context "key is string" do
      let(:options) { { "method-defined-calsses" => %i(defined_class) } }
      it { is_expected.to eq %i(defined_class) }
    end

    context "key is symbol" do
      let(:options) { { method_defined_calssses: %i(defined_class) } }
      it { is_expected.to eq %i(defined_class) }
    end

    context "value is symbol" do
      let(:options) { { method_defined_calssses: %i(defined_class) } }
      it { is_expected.to eq %i(defined_class) }
    end

    context "value is string" do
      let(:options) { { method_defined_calssses: %w(defined_class) } }
      it { is_expected.to eq %i(defined_class) }
    end

    context "empty options" do
      let(:options) { { method_defined_calssses: [] } }
      it { is_expected.to eq [] }
    end

    context "undefined options" do
      let(:options) { {} }
      it { is_expected.to eq %i(defined_class receiver_class) }
    end
  end
end
