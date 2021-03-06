module Draper
  # Provides shortcuts to decorate objects directly, so you can do
  # `@product.decorate` instead of `ProductDecorator.new(@product)`.
  #
  # This module is included by default into `ActiveRecord::Base` and
  # `Mongoid::Document`, but you're using another ORM, or want to decorate
  # plain old Ruby objects, you can include it manually.
  module Decoratable
    extend ActiveSupport::Concern

    # Decorates the object using the inferred {#decorator_class}.
    # @param [Hash] options
    #   see {Decorator#initialize}
    def decorate(options = {})
      decorator_class.decorate(self, options)
    end

    # (see ClassMethods#decorator_class)
    def decorator_class
      self.class.decorator_class
    end

    # The list of decorators that have been applied to the object.
    #
    # @return [Array<Class>] `[]`
    def applied_decorators
      []
    end

    # (see Decorator#decorated_with?)
    # @return [false]
    def decorated_with?(decorator_class)
      false
    end

    # Checks if this object is decorated.
    #
    # @return [false]
    def decorated?
      false
    end

    # Compares with possibly-decorated objects.
    #
    # @return [Boolean]
    def ==(other)
      super || (other.respond_to?(:source) && self == other.source)
    end

    module ClassMethods

      # Decorates a collection of objects. Used at the end of a scope chain.
      #
      # @example
      #   Product.popular.decorate
      # @param [Hash] options
      #   see {Decorator.decorate_collection}.
      def decorate(options = {})
        decorator_class.decorate_collection(self.scoped, options)
      end

      # Infers the decorator class to be used by {Decoratable#decorate} (e.g.
      # `Product` maps to `ProductDecorator`).
      #
      # @return [Class] the inferred decorator class.
      def decorator_class
        prefix = respond_to?(:model_name) ? model_name : name
        "#{prefix}Decorator".constantize
      rescue NameError
        raise Draper::UninferrableDecoratorError.new(self)
      end

      # Compares with possibly-decorated objects.
      #
      # @return [Boolean]
      def ===(other)
        super || (other.respond_to?(:source) && super(other.source))
      end

    end

  end
end
