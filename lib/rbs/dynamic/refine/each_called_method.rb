# frozen_string_literal: true

module RBS module Dynamic module Refine
  module EachCalledMethod
    refine Hash do
      def each_called_method(&block)
        return Enumerator.new { |y|
          each_called_method { |it| y << it }
        } unless block

        self[:called_methods].each { |called_method|
          block.call(called_method)
          if Hash === called_method
            called_method.each_called_method(&block)
          end
        }
      end
    end

    refine Array do
      using EachCalledMethod

      def each_called_method(&block)
        return Enumerator.new { |y|
          each_called_method { |it| y << it }
        } unless block
        each { |called_method|
          block.call(called_method)
          called_method.each_called_method(&block)
        }
      end
    end
  end
end end end
