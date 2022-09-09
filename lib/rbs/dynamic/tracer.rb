# frozen_string_literal: true

require_relative "./tracer/called_method.rb"

module RBS module Dynamic
  module Tracer
    def self.trace(**opt, &block)
      CalledMethod.new(**opt).enable(&block)[:called_methods].first[:called_methods]
    end
  end
end end
