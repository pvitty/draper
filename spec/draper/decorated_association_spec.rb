require 'spec_helper'

describe Draper::DecoratedAssociation do
  let(:decorated_association) { Draper::DecoratedAssociation.new(owner, :association, options) }
  let(:source) { Product.new }
  let(:owner) { source.decorate }
  let(:options) { {} }

  describe "#initialize" do
    describe "options validation" do
      let(:valid_options) { {with: ProductDecorator, scope: :foo, context: {}} }

      it "does not raise error on valid options" do
        expect { Draper::DecoratedAssociation.new(owner, :association, valid_options) }.to_not raise_error
      end

      it "raises error on invalid options" do
        expect { Draper::DecoratedAssociation.new(owner, :association, valid_options.merge(foo: 'bar')) }.to raise_error(ArgumentError, /Unknown key/)
      end
    end
  end

  describe "#call" do
    let(:context) { {foo: "bar"} }
    let(:expected_options) { {context: context} }

    before do
      source.stub association: associated
      decorated_association.stub context: context
    end

    context "for a singular association" do
      let(:associated) { Product.new }
      let(:decorator) { SpecificProductDecorator }

      context "when :with option was given" do
        let(:options) { {with: decorator} }

        it "uses the specified decorator" do
          decorator.should_receive(:decorate).with(associated, expected_options).and_return(:decorated)
          decorated_association.call.should be :decorated
        end
      end

      context "when :with option was not given" do
        it "infers the decorator" do
          associated.stub(:decorator_class).and_return(decorator)
          decorator.should_receive(:decorate).with(associated, expected_options).and_return(:decorated)
          decorated_association.call.should be :decorated
        end
      end
    end

    context "for a collection association" do
      let(:associated) { [Product.new, Widget.new] }
      let(:collection_decorator) { ProductsDecorator }

      context "when :with option is a collection decorator" do
        let(:options) { {with: collection_decorator} }

        it "uses the specified decorator" do
          collection_decorator.should_receive(:decorate).with(associated, expected_options).and_return(:decorated_collection)
          decorated_association.call.should be :decorated_collection
        end
      end

      context "when :with option is a singular decorator" do
        let(:options) { {with: decorator} }
        let(:decorator) { SpecificProductDecorator }

        it "uses a CollectionDecorator of the specified decorator" do
          decorator.should_receive(:decorate_collection).with(associated, expected_options).and_return(:decorated_collection)
          decorated_association.call.should be :decorated_collection
        end
      end

      context "when :with option was not given" do
        context "when the collection is decoratable" do
          it "infers the decorator" do
            associated.stub(:decorator_class).and_return(collection_decorator)
            collection_decorator.should_receive(:decorate).with(associated, expected_options).and_return(:decorated_collection)
            decorated_association.call.should be :decorated_collection
          end
        end

        context "when the collection is not decoratable" do
          it "uses a CollectionDecorator of inferred decorators" do
            Draper::CollectionDecorator.should_receive(:decorate).with(associated, expected_options).and_return(:decorated_collection)
            decorated_association.call.should be :decorated_collection
          end
        end
      end
    end

    context "with a scope" do
      let(:associated) { [] }
      let(:options) { {scope: :foo} }

      it "applies the scope before decoration" do
        scoped = [Product.new]
        associated.should_receive(:foo).and_return(scoped)
        decorated_association.call.should == scoped
      end
    end
  end

  describe "#context" do
    before { owner.stub context: :owner_context }

    context "when :context option was given" do
      let(:options) { {context: context} }

      context "and is callable" do
        let(:context) { ->(*){ :dynamic_context } }

        it "calls it with the owner's context" do
          context.should_receive(:call).with(:owner_context)
          decorated_association.context
        end

        it "returns the lambda's return value" do
          decorated_association.context.should be :dynamic_context
        end
      end

      context "and is not callable" do
        let(:context) { :static_context }

        it "returns the specified value" do
          decorated_association.context.should be :static_context
        end
      end
    end

    context "when :context option was not given" do
      it "returns the owner's context" do
        decorated_association.context.should be :owner_context
      end
    end
  end

end
