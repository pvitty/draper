require 'spec_helper'

describe Draper::Decorator do
  before { ApplicationController.new.view_context }
  subject { decorator_class.new(source) }
  let(:decorator_class) { Draper::Decorator }
  let(:source) { Product.new }

  describe "#initialize" do
    describe "options validation" do
      let(:valid_options) { {context: {}} }

      it "does not raise error on valid options" do
        expect { decorator_class.new(source, valid_options) }.to_not raise_error
      end

      it "raises error on invalid options" do
        expect { decorator_class.new(source, valid_options.merge(foo: 'bar')) }.to raise_error(ArgumentError, /Unknown key/)
      end
    end

    it "sets the source" do
      subject.source.should be source
    end

    it "stores context" do
      decorator = decorator_class.new(source, context: {some: 'context'})
      decorator.context.should == {some: 'context'}
    end

    context "when decorating an instance of itself" do
      it "does not redecorate" do
        decorator = ProductDecorator.new(source)
        ProductDecorator.new(decorator).source.should be source
      end

      context "when options are supplied" do
        it "overwrites existing context" do
          decorator = ProductDecorator.new(source, context: {role: :admin})
          ProductDecorator.new(decorator, context: {role: :user}).context.should == {role: :user}
        end
      end

      context "when no options are supplied" do
        it "preserves existing context" do
          decorator = ProductDecorator.new(source, context: {role: :admin})
          ProductDecorator.new(decorator).context.should == {role: :admin}
        end
      end
    end

    context "when decorating other decorators" do
      it "redecorates" do
        decorator = ProductDecorator.new(source)
        SpecificProductDecorator.new(decorator).source.should be decorator
      end

      context "when the same decorator has been applied earlier in the chain" do
        let(:decorator) { SpecificProductDecorator.new(ProductDecorator.new(Product.new)) }

        it "warns" do
          warning_message = nil
          Object.any_instance.stub(:warn) {|message| warning_message = message }

          expect{ProductDecorator.new(decorator)}.to change{warning_message}
          warning_message.should =~ /ProductDecorator/
          warning_message.should include caller(1).first
        end

        it "redecorates" do
          Object.any_instance.stub(:warn)
          ProductDecorator.new(decorator).source.should be decorator
        end
      end
    end
  end

  describe "#context=" do
    it "modifies the context" do
      decorator = decorator_class.new(source, context: {some: 'context'})
      decorator.context = {some: 'other_context'}
      decorator.context.should == {some: 'other_context'}
    end
  end

  describe ".decorate_collection" do
    let(:source) { [Product.new, Widget.new] }

    describe "options validation" do
      let(:valid_options) { {with: :infer, context: {}} }
      before(:each) { Draper::CollectionDecorator.stub(:new) }

      it "does not raise error on valid options" do
        expect { ProductDecorator.decorate_collection(source, valid_options) }.to_not raise_error
      end

      it "raises error on invalid options" do
        expect { ProductDecorator.decorate_collection(source, valid_options.merge(foo: 'bar')) }.to raise_error(ArgumentError, /Unknown key/)
      end
    end

    context "when a custom collection decorator does not exist" do
      subject { WidgetDecorator.decorate_collection(source) }

      it "returns a regular collection decorator" do
        subject.should be_a Draper::CollectionDecorator
        subject.should == source
      end

      it "uses itself as the item decorator by default" do
        subject.each {|item| item.should be_a WidgetDecorator}
      end
    end

    context "when a custom collection decorator exists" do
      subject { ProductDecorator.decorate_collection(source) }

      it "returns the custom collection decorator" do
        subject.should be_a ProductsDecorator
        subject.should == source
      end

      it "uses itself as the item decorator by default" do
        subject.each {|item| item.should be_a ProductDecorator}
      end
    end

    context "with context" do
      subject { ProductDecorator.decorate_collection(source, with: :infer, context: {some: 'context'}) }

      it "passes the context to the collection decorator" do
        subject.context.should == {some: 'context'}
      end
    end
  end

  describe "#helpers" do
    it "returns a HelperProxy" do
      subject.helpers.should be_a Draper::HelperProxy
    end

    it "is aliased to #h" do
      subject.h.should be subject.helpers
    end

    it "initializes the wrapper only once" do
      helper_proxy = subject.helpers
      helper_proxy.stub(:test_method) { "test_method" }
      subject.helpers.test_method.should == "test_method"
      subject.helpers.test_method.should == "test_method"
    end
  end

  describe "#localize" do
    before { subject.helpers.should_receive(:localize).with(:an_object, {some: 'parameter'}) }

    it "delegates to #helpers" do
      subject.localize(:an_object, some: 'parameter')
    end

    it "is aliased to #l" do
      subject.l(:an_object, some: 'parameter')
    end
  end

  describe ".helpers" do
    it "returns a HelperProxy" do
      subject.class.helpers.should be_a Draper::HelperProxy
    end

    it "is aliased to .h" do
      subject.class.h.should be subject.class.helpers
    end
  end

  describe ".decorates" do
    subject { Class.new(Draper::Decorator) }

    context "with a symbol" do
      it "sets .source_class" do
        subject.decorates :product
        subject.source_class.should be Product
      end
    end

    context "with a string" do
      it "sets .source_class" do
        subject.decorates "product"
        subject.source_class.should be Product
      end
    end

    context "with a class" do
      it "sets .source_class" do
        subject.decorates Product
        subject.source_class.should be Product
      end
    end
  end

  describe ".source_class" do
    context "when not set by .decorates" do
      context "for an anonymous decorator" do
        subject { Class.new(Draper::Decorator) }

        it "raises an UninferrableSourceError" do
          expect{subject.source_class}.to raise_error Draper::UninferrableSourceError
        end
      end

      context "for a decorator without a corresponding source" do
        subject { SpecificProductDecorator }

        it "raises an UninferrableSourceError" do
          expect{subject.source_class}.to raise_error Draper::UninferrableSourceError
        end
      end

      context "for a decorator called Decorator" do
        subject { Draper::Decorator }

        it "raises an UninferrableSourceError" do
          expect{subject.source_class}.to raise_error Draper::UninferrableSourceError
        end
      end

      context "for a decorator with a name not ending in Decorator" do
        subject { DecoratorWithApplicationHelper }

        it "raises an UninferrableSourceError" do
          expect{subject.source_class}.to raise_error Draper::UninferrableSourceError
        end
      end

      context "for an inferrable source" do
        subject { ProductDecorator }

        it "infers the source" do
          subject.source_class.should be Product
        end
      end

      context "for a namespaced inferrable source" do
        subject { Namespace::ProductDecorator }

        it "infers the namespaced source" do
          subject.source_class.should be Namespace::Product
        end
      end
    end
  end

  describe ".source_class?" do
    subject { Class.new(Draper::Decorator) }

    it "returns truthy when .source_class is set" do
      subject.stub(:source_class).and_return(Product)
      subject.source_class?.should be_true
    end

    it "returns false when .source_class is not inferrable" do
      subject.stub(:source_class).and_raise(Draper::UninferrableSourceError.new(subject))
      subject.source_class?.should be_false
    end
  end

  describe ".decorates_association" do
    let(:decorator_class) { Class.new(ProductDecorator) }
    before { decorator_class.decorates_association :similar_products, with: ProductDecorator }

    describe "overridden association method" do
      let(:decorated_association) { ->{} }

      describe "options validation" do
        let(:valid_options) { {with: ProductDecorator, scope: :foo, context: {}} }
        before(:each) { Draper::DecoratedAssociation.stub(:new).and_return(decorated_association) }

        it "does not raise error on valid options" do
          expect { decorator_class.decorates_association :similar_products, valid_options }.to_not raise_error
        end

        it "raises error on invalid options" do
          expect { decorator_class.decorates_association :similar_products, valid_options.merge(foo: 'bar') }.to raise_error(ArgumentError, /Unknown key/)
        end
      end

      it "creates a DecoratedAssociation" do
        Draper::DecoratedAssociation.should_receive(:new).with(subject, :similar_products, {with: ProductDecorator}).and_return(decorated_association)
        subject.similar_products
      end

      it "receives the Decorator" do
        Draper::DecoratedAssociation.should_receive(:new).with(kind_of(decorator_class), :similar_products, {with: ProductDecorator}).and_return(decorated_association)
        subject.similar_products
      end

      it "memoizes the DecoratedAssociation" do
        Draper::DecoratedAssociation.should_receive(:new).once.and_return(decorated_association)
        subject.similar_products
        subject.similar_products
      end

      it "calls the DecoratedAssociation" do
        Draper::DecoratedAssociation.stub(:new).and_return(decorated_association)
        decorated_association.should_receive(:call).and_return(:decorated)
        subject.similar_products.should be :decorated
      end
    end
  end

  describe ".decorates_associations" do
    subject { decorator_class }

    it "decorates each of the associations" do
      subject.should_receive(:decorates_association).with(:similar_products, {})
      subject.should_receive(:decorates_association).with(:previous_version, {})

      subject.decorates_associations :similar_products, :previous_version
    end

    it "dispatches options" do
      subject.should_receive(:decorates_association).with(:similar_products, {with: ProductDecorator})
      subject.should_receive(:decorates_association).with(:previous_version, {with: ProductDecorator})

      subject.decorates_associations :similar_products, :previous_version, with: ProductDecorator
    end
  end

  describe "#applied_decorators" do
    it "returns a list of decorators applied to a model" do
      decorator = ProductDecorator.new(SpecificProductDecorator.new(Product.new))
      decorator.applied_decorators.should == [SpecificProductDecorator, ProductDecorator]
    end
  end

  describe "#decorated_with?" do
    it "checks if a decorator has been applied to a model" do
      decorator = ProductDecorator.new(SpecificProductDecorator.new(Product.new))
      decorator.should be_decorated_with ProductDecorator
      decorator.should be_decorated_with SpecificProductDecorator
      decorator.should_not be_decorated_with WidgetDecorator
    end
  end

  describe "#decorated?" do
    it "returns true" do
      subject.should be_decorated
    end
  end

  describe "#source" do
    it "returns the wrapped object" do
      subject.source.should be source
    end

    it "is aliased to #to_source" do
      subject.to_source.should be source
    end

    it "is aliased to #model" do
      subject.model.should be source
    end
  end

  describe "#to_model" do
    it "returns the decorator" do
      subject.to_model.should be subject
    end
  end

  describe "#to_param" do
    it "proxies to the source" do
      source.stub(:to_param).and_return(42)
      subject.to_param.should == 42
    end
  end

  describe "#==" do
    context "with itself" do
      it "returns true" do
        (subject == subject).should be_true
      end
    end

    context "with another decorator having the same source" do
      it "returns true" do
        (subject == ProductDecorator.new(source)).should be_true
      end
    end

    context "with another decorator having a different source" do
      it "returns false" do
        (subject == ProductDecorator.new(Object.new)).should be_false
      end
    end

    context "with the source object" do
      it "returns true" do
        (subject == source).should be_true
      end
    end

    context "with another object" do
      it "returns false" do
        (subject == Object.new).should be_false
      end
    end
  end

  describe "#===" do
    context "with itself" do
      it "returns true" do
        (subject === subject).should be_true
      end
    end

    context "with another decorator having the same source" do
      it "returns true" do
        (subject === ProductDecorator.new(source)).should be_true
      end
    end

    context "with another decorator having a different source" do
      it "returns false" do
        (subject === ProductDecorator.new(Object.new)).should be_false
      end
    end

    context "with the source object" do
      it "returns true" do
        (subject === source).should be_true
      end
    end

    context "with another object" do
      it "returns false" do
        (subject === Object.new).should be_false
      end
    end
  end

  describe ".delegate" do
    subject { Class.new(Draper::Decorator) }

    it "defaults the :to option to :source" do
      Draper::Decorator.superclass.should_receive(:delegate).with(:foo, :bar, to: :source)
      subject.delegate :foo, :bar
    end

    it "does not overwrite the :to option if supplied" do
      Draper::Decorator.superclass.should_receive(:delegate).with(:foo, :bar, to: :baz)
      subject.delegate :foo, :bar, to: :baz
    end
  end

  describe ".delegate_all" do
    let(:decorator_class) { Class.new(ProductDecorator) }
    before { decorator_class.delegate_all }

    describe "#method_missing" do
      it "does not delegate methods that are defined on the decorator" do
        subject.overridable.should be :overridden
      end

      it "does not delegate methods inherited from Object" do
        subject.inspect.should_not be source.inspect
      end

      it "delegates missing methods that exist on the source" do
        source.stub(:hello_world).and_return(:delegated)
        subject.hello_world.should be :delegated
      end

      it "adds delegated methods to the decorator when they are used" do
        subject.methods.should_not include :hello_world
        subject.hello_world
        subject.methods.should include :hello_world
      end

      it "passes blocks to delegated methods" do
        subject.block{"marker"}.should == "marker"
      end

      it "does not confuse Kernel#Array" do
        Array(subject).should be_a Array
      end

      it "delegates already-delegated methods" do
        subject.delegated_method.should == "Yay, delegation"
      end

      it "does not delegate private methods" do
        expect{subject.private_title}.to raise_error NoMethodError
      end
    end

    context ".method_missing" do
      subject { decorator_class }

      context "without a source class" do
        it "raises a NoMethodError on missing methods" do
          expect{subject.hello_world}.to raise_error NoMethodError
        end
      end

      context "with a source class" do
        let(:source_class) { Product }
        before { subject.decorates source_class }

        it "does not delegate methods that are defined on the decorator" do
          subject.overridable.should be :overridden
        end

        it "delegates missing methods that exist on the source" do
          source_class.stub(:hello_world).and_return(:delegated)
          subject.hello_world.should be :delegated
        end
      end
    end

    describe "#respond_to?" do
      it "returns true for its own methods" do
        subject.should respond_to :awesome_title
      end

      it "returns true for the source's methods" do
        subject.should respond_to :title
      end

      context "with include_private" do
        it "returns true for its own private methods" do
          subject.respond_to?(:awesome_private_title, true).should be_true
        end

        it "returns false for the source's private methods" do
          subject.respond_to?(:private_title, true).should be_false
        end
      end
    end

    describe ".respond_to?" do
      subject { decorator_class }

      context "without a source class" do
        it "returns true for its own class methods" do
          subject.should respond_to :my_class_method
        end

        it "returns false for other class methods" do
          subject.should_not respond_to :sample_class_method
        end
      end

      context "with a source_class" do
        before { subject.decorates :product }

        it "returns true for its own class methods" do
          subject.should respond_to :my_class_method
        end

        it "returns true for the source's class methods" do
          subject.should respond_to :sample_class_method
        end
      end
    end
  end

  context "in a Rails application" do
    let(:decorator_class) { DecoratorWithApplicationHelper }

    it "has access to ApplicationHelper helpers" do
      subject.uses_hello_world.should == "Hello, World!"
    end

    it "is able to use the content_tag helper" do
      subject.sample_content.to_s.should == "<span>Hello, World!</span>"
    end

    it "is able to use the link_to helper" do
      subject.sample_link.should == %{<a href="/World">Hello</a>}
    end

    it "is able to use the truncate helper" do
      subject.sample_truncate.should == "Once..."
    end

    it "is able to access html_escape, a private method" do
      subject.sample_html_escaped_text.should == '&lt;script&gt;danger&lt;/script&gt;'
    end
  end

  it "pretends to be the source class" do
    subject.kind_of?(source.class).should be_true
    subject.is_a?(source.class).should be_true
  end

  it "is still its own class" do
    subject.kind_of?(subject.class).should be_true
    subject.is_a?(subject.class).should be_true
  end

  it "pretends to be an instance of the source class" do
    subject.instance_of?(source.class).should be_true
  end

  it "is still an instance of its own class" do
    subject.instance_of?(subject.class).should be_true
  end

  describe ".decorates_finders" do
    it "extends the Finders module" do
      ProductDecorator.should be_a_kind_of Draper::Finders
    end
  end

  describe "#serializable_hash" do
    let(:decorator_class) { ProductDecorator }

    it "serializes overridden attributes" do
      subject.serializable_hash[:overridable].should be :overridden
    end
  end

end
