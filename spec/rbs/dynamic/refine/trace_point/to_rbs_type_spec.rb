# frozen_string_literal: true

RSpec.describe RBS::Dynamic::Refine::TracePoint::ToRBSType do
  describe "#to_rbs_type" do
    using RBS::Dynamic::Refine::TracePoint::ToRBSType
    subject { target_object.to_rbs_type }

    context "Integer" do
      let(:target_object) { 42 }
      it { is_expected.to include(type: Integer, value: 42, args: []) }
    end

    context "Symbol" do
      let(:target_object) { :homu }
      it { is_expected.to include(type: Symbol, value: :homu, args: []) }
    end

    context "String" do
      let(:target_object) { "mami" }
      it { is_expected.to include(type: String, value: nil, args: []) }
    end

    context "Class" do
      let(:target_object) { Integer }
      it { is_expected.to include(type: Class, value: nil, args: []) }
    end

    context "Array" do
      let(:target_object) { [1, 2, "homu"] }
      it { is_expected.to include(type: Array, value: nil, args: [[1.to_rbs_type, 2.to_rbs_type, "homu".to_rbs_type]]) }

      context "within Array" do
        let(:target_object) { [1, [2, [3, 4]]] }

        it { is_expected.to include(type: Array, value: nil, args: [
          [1.to_rbs_type, include(type: Array, value: nil, args: [
            [2.to_rbs_type, include(type: Array, value: nil, args: [
              [3.to_rbs_type, 4.to_rbs_type]
            ])
          ]])
        ]]) }
      end

      context "nested Array" do
        let(:target_object) {
          a = [1, 2]
          a[0] = a
        }

        it { is_expected.to include(type: Array, value: nil, args: [[
          include(type: Array, value: nil, args: [[]]),
          2.to_rbs_type
        ]]) }
      end

      context "empty Array" do
        let(:target_object) { [] }

        it { is_expected.to include(type: Array, value: nil, args: [[]]) }
      end
    end

    context "Hash" do
      let(:target_object) { { id: 1, name: "homu" } }

      it { is_expected.to include(type: Hash, value: nil, args: [
        [:id.to_rbs_type, :name.to_rbs_type],
        [1.to_rbs_type, "homu".to_rbs_type]
      ]) }

      context "within Hash" do
        let(:target_object) { { a: { b: { c: 1, d: "2" } } } }

        it { is_expected.to include(type: Hash, value: nil, args: [
          [:a.to_rbs_type],
          [include(type: Hash, value: nil, args: [
            [:b.to_rbs_type],
            [include(type: Hash, value: nil, args: [
              [:c.to_rbs_type, :d.to_rbs_type],
              [1.to_rbs_type, "2".to_rbs_type]
            ])]
          ])]
        ]) }
      end

      context "nested Hash" do
        let(:target_object) {
          h = { a: 1, b: 2 }
          h[:b] = h
        }

        it { is_expected.to include(type: Hash, value: nil, args: [
          [:a.to_rbs_type, :b.to_rbs_type],
          [1.to_rbs_type, include(type: Hash, value: nil, args: [[], []])]
        ]) }
      end

      context "empty Array" do
        let(:target_object) { {} }

        it { is_expected.to include(type: Hash, value: nil, args: [[], []]) }
      end
    end

    context "BasicObject" do
      let(:target_object) {
        class SubBasicObject < BasicObject
        end
        SubBasicObject.new
      }

      it { is_expected.to include(type: SubBasicObject, value: nil, args: []) }
    end

    context "Range" do
      context "finite range" do
        let(:target_object) { (1..10) }
        it { is_expected.to include(type: Range, value: nil, args: [[1.to_rbs_type, 10.to_rbs_type]]) }
      end

      context "beginless range" do
        let(:target_object) { (..10) }
        it { is_expected.to include(type: Range, value: nil, args: [[nil.to_rbs_type, 10.to_rbs_type]]) }
      end

      context "endless range" do
        let(:target_object) { (1..) }
        it { is_expected.to include(type: Range, value: nil, args: [[1.to_rbs_type, nil.to_rbs_type]]) }
      end
    end
  end
end
