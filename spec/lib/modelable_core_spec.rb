require 'spec_helper'
require 'active_model'
require 'byebug'

describe LightOperations::ModelableCore do
  class ModelClass
    include ActiveModel::Model
    attr_accessor :age, :name
  end

  let(:dependencies) { {} }

  it 'has ancestor LightOperations::Core' do
    expect(described_class.ancestors).to include(LightOperations::Core)
  end

  context '.model' do
    subject do
      core_class_factory(described_class) do
        model :model_class
      end
    end

    it 'assign model class' do
      expect(subject.model).to eq(:model_class)
    end
  end

  context '.validation' do
    subject do
      core_class_factory(described_class) do
        validation do
          validate :age, presence: true
        end
      end
    end

    it 'assign validation block' do
      expect(subject.validation).to be_a(Proc)
    end
  end

  context '#form' do
    subject do
      core_object_factory(described_class, dependencies: dependencies) do
        model ModelClass
      end
    end

    context 'when operation is just created' do
      it 'returns instance of model' do
        expect(subject.form).to be_an_instance_of(ModelClass)
      end

      it 'return instance of model with assign attributes' do
        opts   = { age: 10 }
        result = subject.form(opts)
        expect(result).to be_an_instance_of(ModelClass)
        expect(result.age).to eq(10)
      end
    end

    context 'when operation was executed' do
      it 'form is created by operation execution'
    end
  end

  context '#model' do
    subject do
      core_object_factory(described_class, dependencies: dependencies) do
        model ModelClass
      end
    end

    context 'when operation is just created' do
      it 'returns instance of model' do
        expect(subject.model).to be_an_instance_of(ModelClass)
      end

      it 'return instance of model with assign attributes' do
        opts   = { age: 20 }
        result = subject.model(opts)
        expect(result).to be_an_instance_of(ModelClass)
        expect(result.age).to eq(20)
      end
    end

    context 'when operation was executed' do
      it 'form is created by operation execution'
    end
  end

  context '#validate' do
    context 'when validation and validate block are used' do
      def subject_with_both_validate_and_validation_block(name = nil)
        core_object_factory(described_class, name: name, dependencies: dependencies) do
          action_kind :create
          model ModelClass
          validation do
            include ActiveModel::Validations
            validates :name, presence: true
          end
          def execute(params = {})
            validate(params) { |model| model.errors.add(:age, 'you are too young to play with me') if model.age < 10 }
          end
        end
      end

      context 'success' do
        subject { subject_with_both_validate_and_validation_block('TestOperationWithValidationAndValidateWhenSuccess') }
        it 'success with object' do
          subject.run(age: 10, name: 'Pawel Niemczyk')
          model = subject.subject
          expect(model.class.name).to eq('ModelClass::TestOperationWithValidationAndValidateWhenSuccess')
          expect(subject.success?).to eq(true)
          expect(model.age).to eq(10)
          expect(model.name).to eq('Pawel Niemczyk')
        end
      end

      context 'fail' do
        subject { subject_with_both_validate_and_validation_block('TestOperationWithValidationAndValidateWhenFail') }
        it 'with errors' do
          subject.run(age: 4)
          expect(subject.subject.class.name).to eq('ModelClass::TestOperationWithValidationAndValidateWhenFail')
          expect(subject.fail?).to eq(true)
          expect(subject.errors.as_json).to eq(name: ["can't be blank"], age: ['you are too young to play with me'])
        end
      end
    end

    context 'when validation block is used' do
      def subject_with_validation_block(name = nil)
        core_object_factory(described_class, name: name, dependencies: dependencies) do
          action_kind :create
          model ModelClass
          validation do
            include ActiveModel::Validations
            validates :name, presence: true
          end
          def execute(params = {})
            validate(params)
          end
        end
      end

      context 'fail' do
        subject { subject_with_validation_block('TestOperationWithValidationWhenFail') }

        it 'with errors' do
          subject.run
          model = subject.subject
          expect(model.class.name).to eq('ModelClass::TestOperationWithValidationWhenFail')
          expect(subject.fail?).to eq(true)
          expect(subject.errors.as_json).to eq(name: ["can't be blank"])
          expect(model.age).to eq(nil)
          expect(model.name).to eq(nil)
        end
      end

      context 'success' do
        subject { subject_with_validation_block('TestOperationWithValidationWhenSuccess') }

        it 'with object' do
          subject.run(name: 'Pawel Niemczyk')
          model = subject.subject
          expect(model.class.name).to eq('ModelClass::TestOperationWithValidationWhenSuccess')
          expect(subject.success?).to eq(true)
          expect(model.age).to eq(nil)
          expect(model.name).to eq('Pawel Niemczyk')
        end
      end
    end

    context 'when validate block is used' do
      def subject_with_validate_block(name = nil)
        core_object_factory(described_class, name: name, dependencies: dependencies) do
          action_kind :create
          model ModelClass
          def execute(params = {})
            validate(params) do |model|
              fail!(age: ['you are too young to play with me']) if model.age < 10
            end
          end
        end
      end

      context 'fail' do
        subject { subject_with_validate_block('TestOperationWithValidateWhenFail') }
        it 'with errors' do
          subject.run(age: 4)
          model = subject.subject
          expect(model.class.name).to eq('ModelClass::TestOperationWithValidateWhenFail')
          expect(subject.fail?).to eq(true)
          expect(subject.errors).to eq(age: ['you are too young to play with me'])
          expect(model.age).to eq(4)
          expect(model.name).to eq(nil)
        end
      end

      context 'success' do
        subject { subject_with_validate_block('TestOperationWithValidateWhenSuccess') }
        it 'with object' do
          subject.run(age: 10)
          model = subject.subject
          expect(model.class.name).to eq('ModelClass::TestOperationWithValidateWhenSuccess')
          expect(subject.success?).to eq(true)
          expect(model.age).to eq(10)
          expect(model.name).to eq(nil)
        end
      end
    end
  end
end
