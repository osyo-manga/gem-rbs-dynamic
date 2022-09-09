# frozen_string_literal: true

module RBS module Dynamic module Refine
  module BasicObjectWithKernel
    refine BasicObject do
      def class(...)
        ::Kernel.instance_method(:class).bind(self).call(...)
      end
    end
  end
end end end
