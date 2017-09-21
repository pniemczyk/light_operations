require 'spec_helper'

describe LightOperations::Core do
  let(:login_service) { double('login_service') }
  let(:params)        { { login: 'pawel', password: 'abc' } }
  let(:dependencies)  { { login_service: login_service } }

  let(:binding_object) do
    Class.new(Object).tap do |klass|
      klass.class_eval do
        def success_action(_operation); end

        def error_action(_operaation); end
      end
    end.new
  end

  def subject_factory(&block)
    Class.new(described_class).tap do |klass|
      klass.class_eval(&block)
    end.new(dependencies)
  end

  subject { described_class.new(dependencies) }

  it 'raise error when #execute is not implemented' do
    expect { subject.on(success: :do_nothing).run }.to raise_error('Not implemented yet')
  end

  it '.subject_name' do
    test_obj = subject_factory do
      subject_name :order
      def execute(params)
        params[:done] || fail!(:error)
      end
    end
    test_obj.run(done: :success)
    expect(test_obj.order).to eq(:success)
  end

  context 'use cases' do
    # dependency using

    context 'dependency usage' do
      subject do
        subject_factory do
          def execute(_params)
            dependency(:login_service)
          end
        end
      end

      before { subject.on(success: ->(_subject) {}) }

      it 'is allowed when is initialized correctly' do
        expect { subject.run }.not_to raise_error
      end

      context 'raise_error' do
        let(:dependencies) { {} }
        it 'when dependency missing' do
          expect { subject.run }.to raise_error(described_class::MissingDependency)
        end
      end
    end

    # error handling

    context '.rescue_from specific error' do
      TestError = Class.new(StandardError)

      before { subject.on(success: ->(_subject) {}) }

      context 'by block' do
        subject do
          subject_factory do
            rescue_from TestError do |exception|
              fail "execute block instead original #{exception.class}"
            end

            def execute(_params)
              fail TestError, 'What now'
            end
          end
        end

        it 'call' do
          expect { subject.run }.to raise_error('execute block instead original TestError')
        end
      end

      context 'by defined method' do
        subject do
          subject_factory do
            rescue_from TestError, with: :rescue_me

            def rescue_me(exception)
              fail "execute rescue_me method instead original #{exception.class}"
            end

            def execute(_params)
              fail TestError, 'What now'
            end
          end
        end

        it 'execute' do
          expect { subject.run }.to raise_error('execute rescue_me method instead original TestError')
        end
      end
    end

    # on actions success/fail

    context 'when operation is successful' do
      subject do
        subject_factory do
          def execute(_params)
            :success
          end
        end
      end

      context '#on_success' do
        it 'when bind_with and send_method is used' do
          expect(binding_object).to receive(:success_action).with(subject)
          subject.on_success(:success_action).bind_with(binding_object).run
        end

        it 'when block is used' do
          subject.on_success { |operation| expect(operation.subject).to eq(:success) }.run
        end
      end

      context '#on_fail' do
        it 'when bind_with and send_method is used' do
          expect(binding_object).not_to receive(:error_action)
          subject.bind_with(binding_object).on_fail(:error_action).run
        end

        it 'when block is used' do
          block_to_exec = -> {}
          expect(block_to_exec).not_to receive(:call)
          subject.on_fail(&block_to_exec).run
        end
      end

      it '#errors' do
        expect(subject.on_success(:success_action).run.errors).to eq([])
      end

      it '#fail?' do
        expect(subject.on_success(:success_action).run.fail?).to eq(false)
      end

      it '#success?' do
        expect(subject.on_success(:success_action).run.success?).to eq(true)
      end
    end

    context 'when operation is fail' do
      subject do
        subject_factory do
          def execute(_params)
            fail!([email: :unknown])
            :fail
          end
        end
      end

      context '#on_success' do
        it 'when bind_with and send_method is used' do
          expect(binding_object).not_to receive(:success_action)
          subject.bind_with(binding_object).on_success(:success_action).run
        end

        it 'when block is used' do
          block_to_exec = -> {}
          expect(block_to_exec).not_to receive(:call)
          subject.on_success(&block_to_exec).run
        end
      end

      context '#on_fail' do
        it 'when bind_with and send_method is used' do
          expect(binding_object).to receive(:error_action).with(subject)
          subject.bind_with(binding_object).on_fail(:error_action).run
        end

        it 'when block is used' do
          subject.on_fail do |operation|
            expect(operation.subject).to eq(:fail)
            expect(operation.errors).to eq([email: :unknown])
          end
          subject.run
        end
      end

      it '#errors' do
        expect(subject.on_fail(:error_action).run.errors).to eq([email: :unknown])
      end

      it '#fail?' do
        expect(subject.on_fail(:error_action).run.fail?).to eq(true)
      end

      it '#success?' do
        expect(subject.on_fail(:error_action).run.success?).to eq(false)
      end
    end
  end

  context 'prepare operation to reuse or simply clear' do
    it '#unbind!' do
      subject.bind_with(:some_object)
      expect { subject.unbind! }.to change { subject.send(:bind_object) }
        .from(:some_object)
        .to(nil)
    end

    it '#clear_actions!' do
      subject.on(success: :abc, fail: :def)
      expect { subject.clear_actions! }.to change { subject.send(:actions) }
        .from(success: :abc, fail: :def)
        .to({})
    end

    it '#clear_subject_with_errors!' do
      %w{subject fail_errors errors}.each do |variable|
        subject.instance_variable_set("@#{variable}", variable)
      end
      expect(subject.subject).to eq('subject')
      expect(subject.instance_variable_get('@errors')).to eq('errors')
      expect(subject.instance_variable_get('@fail_errors')).to eq('fail_errors')
      subject.clear_subject_with_errors!
      expect(subject.subject).to be_nil
      expect(subject.instance_variable_get('@errors')).to be_nil
      expect(subject.instance_variable_get('@fail_errors')).to be_nil
    end

    it '#clear!' do
      expect(subject).to receive(:unbind!)
      expect(subject).to receive(:clear_actions!)
      expect(subject).to receive(:clear_subject_with_errors!)
      subject.clear!
    end
  end

  context '#fail! in execute when is without arguments' do
    subject do
      subject_factory do
        def execute(params = {})
          fail! unless params.key?(:result)
          params[:result]
        end
      end
    end

    it 'setup operation in fail state' do
      expect(subject.run.success?).to eq(false)
      expect(subject.run.fail?).to eq(true)
    end

    it 'setup operation in fail state' do
      expect(subject.run(result: 'ok').success?).to eq(true)
      expect(subject.run(result: 'ok').fail?).to eq(false)
    end
  end

  context 'Operation executed several times' do
    subject do
      subject_factory do
        def execute(params = {})
          fail!(:missing_result) unless params.key?(:result)
          params[:result]
        end
      end
    end

    it 'always start with clean state of subject and errors' do
      subject
        .bind_with(binding_object)
        .on(success: :success_action, fail: :error_action)

      expect(binding_object).to receive(:error_action).with(subject)
      subject.run
      expect(binding_object).to receive(:success_action).with(subject)
      subject.run(result: :success)
    end
  end

  context 'Operation execution without params' do
    subject do
      subject_factory do
        def execute
          'hello world!'
        end
      end
    end

    it 'is allowed' do
      subject
        .bind_with(binding_object)
        .on(success: :success_action, fail: :error_action)
      expect(subject.run.success?).to eq(true)
    end
  end
end
