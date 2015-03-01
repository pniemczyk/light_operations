require 'active_support'

module LightOperations
  class Core
    include ::ActiveSupport::Rescuable
    MissingDependency = Class.new(StandardError)

    attr_reader :dependencies, :bind_object, :subject

    def initialize(dependencies = {})
      @dependencies = dependencies
    end

    # do no.t override this method
    def run(params = {})
      clear_subject_with_errors!
      @subject = execute(params)
      execute_actions
      self
    rescue => exception
      rescue_with_handler(exception) || raise
      self
    end

    def on_success(binded_method = nil, &block)
      actions[:success] = binded_method || block
      self
    end

    def on_fail(binded_method = nil, &block)
      actions[:fail] = binded_method || block
      self
    end

    def on(actions_with_responses = {})
      actions_with_responses.slice(:success, :fail).each do |action, response|
        actions[action] = response
      end
      self
    end

    def clear!
      clear_actions!
      unbind!
      clear_subject_with_errors!
      self
    end

    def unbind!
      @bind_object = nil
      self
    end

    def clear_subject_with_errors!
      @subject, @fail_errors, @errors = nil, nil, nil
      self
    end

    def clear_actions!
      @actions = {}
      self
    end

    def bind_with(bind_object)
      @bind_object = bind_object
      self
    end

    def errors
      @errors ||= fail_errors || (subject.respond_to?(:errors) ? subject.errors : [])
    end

    def fail?
      !success?
    end

    def success?
      errors.respond_to?(:empty?) ? errors.empty? : !errors
    end

    protected

    attr_reader :fail_errors

    def execute_actions
      success? ? execute_success_action : execute_fail_action
    end

    def execute_success_action
      return unless actions.key?(:success)
      action = actions[:success]
      bind_object.send(action, subject) if action.is_a?(Symbol) && bind_object
      action.call(subject) if action.is_a?(Proc)
    end

    def execute_fail_action
      return unless actions.key?(:fail)
      action = actions[:fail]
      bind_object.send(action, subject, errors) if action.is_a?(Symbol) && bind_object
      action.call(subject, errors) if action.is_a?(Proc)
    end

    def fail!(errors = [])
      @fail_errors = errors
    end

    def actions
      @actions ||= {}
    end

    def execute(_params = {})
      fail 'Not implemented yet'
    end

    def dependency(name)
      dependencies.fetch(name)
    rescue KeyError => e
      raise MissingDependency, e.message
    end
  end
end
