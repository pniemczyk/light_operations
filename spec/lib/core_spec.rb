require 'spec_helper'

describe LightOperations::Core do
  let(:login_service) { double('login_service') }
  let(:params)        { { login: 'pawel', password: 'abc' } }
  let(:dependencies)  { { login_service: login_service } }

  def subject_factory(&block)
    Class.new(described_class).tap do |klass|
      klass.class_eval(&block)
    end.new(params, dependencies)
  end

  subject { described_class.new(params, dependencies) }

  it 'raise error when #execute is not implemented' do
    expect { subject.run }.to raise_error('Not implemented yet')
  end

  context 'use cases' do
    let(:binding_object) do
      Class.new(Object).tap do |klass|
        klass.class_eval do
          def success_action(_subject); end

          def error_action(_subject, _errors); end
        end
      end.new
    end

    # dependency using

    context 'dependency usage' do
      subject do
        subject_factory do
          def execute
            dependency(:login_service)
          end
        end
      end

      it 'is allowed when is initialized correctly' do
        expect { subject.run }.not_to raise_error
      end

      context 'raise_error' do
        let(:dependencies) { {} }
        it 'when dependency missing' do
          expect { subject.run }.to raise_error(LightOperations::Core::MissingDependency)
        end
      end
    end

    # error handling

    context '.rescue_from specific error' do
      context 'by block' do
        subject do
          subject_factory do
            rescue_from StandardError do |_exception|
              fail 'execute block instead original error'
            end

            def execute
              fail StandardError, 'What now'
            end
          end
        end

        it 'call' do
          expect { subject.run }.to raise_error('execute block instead original error')
        end
      end

      context 'by defined method' do
        subject do
          subject_factory do
            rescue_from StandardError, with: :rescue_me

            def rescue_me
              fail 'execute rescue_me method instead original error'
            end

            def execute
              fail StandardError, 'What now'
            end
          end
        end

        it 'execute' do
          expect { subject.run }.to raise_error('execute rescue_me method instead original error')
        end
      end
    end

    context 'when operation is successful' do
      subject do
        subject_factory do
          def execute
            :success
          end
        end
      end

      context '#on_success' do
        it 'when bind_with and send_method is used' do
          expect(binding_object).to receive(:success_action).with(:success)
          subject.run.bind_with(binding_object).on_success(:success_action)
        end

        it 'when block is used' do
          subject.run.on_success do |result|
            expect(result).to eq(:success)
          end
        end
      end

      context '#on_fail' do
        it 'when bind_with and send_method is used' do
          expect(binding_object).not_to receive(:error_action)
          subject.run.bind_with(binding_object).on_fail(:error_action)
        end

        it 'when block is used' do
          block_to_exec = -> () {}
          expect(block_to_exec).not_to receive(:call)
          subject.run.on_fail(&block_to_exec)
        end
      end

      it '#errors' do
        expect(subject.run.errors).to eq([])
      end

      it '#fail?' do
        expect(subject.run.fail?).to eq(false)
      end

      it '#success?' do
        expect(subject.run.success?).to eq(true)
      end
    end

    context 'when operation is fail' do
      subject do
        subject_factory do
          def execute
            fail!([email: :unknown])
            :fail
          end
        end
      end

      context '#on_success' do
        it 'when bind_with and send_method is used' do
          expect(binding_object).not_to receive(:success_action)
          subject.run.bind_with(binding_object).on_success(:success_action)
        end

        it 'when block is used' do
          block_to_exec = -> () {}
          expect(block_to_exec).not_to receive(:call)
          subject.run.on_success(&block_to_exec)
        end
      end

      context '#on_fail' do
        it 'when bind_with and send_method is used' do
          expect(binding_object).to receive(:error_action).with(:fail, [email: :unknown])
          subject.run.bind_with(binding_object).on_fail(:error_action)
        end

        it 'when block is used' do
          subject.run.on_fail do |result, errors|
            expect(result).to eq(:fail)
            expect(errors).to eq([email: :unknown])
          end
        end
      end

      it '#errors' do
        expect(subject.run.errors).to eq([email: :unknown])
      end

      it '#fail?' do
        expect(subject.run.fail?).to eq(true)
      end

      it '#success?' do
        expect(subject.run.success?).to eq(false)
      end
    end
  end
end
