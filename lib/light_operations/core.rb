require 'active_support'

module LightOperations
  class Core
    include ::ActiveSupport::Rescuable
    MissingDependency = Class.new(StandardError)

    attr_reader :subject

    def self.subject_name(method_name)
      send(:define_method, method_name, proc { self.subject })
    end

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
      execute_actions
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
      actions_assign(actions_with_responses, :success, :fail)
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

    attr_reader :dependencies, :bind_object, :fail_errors

    def actions_assign(hash, *keys)
      keys.each { |key| actions[key] = hash[key] if hash.key?(key) }
    end

    def execute_actions
      success? ? execute_action_kind(:success) : execute_action_kind(:fail)
    end

    def execute_action_kind(kind)
      return unless actions.key?(kind)
      action = actions[kind]
      bind_object.send(action, self) if action.is_a?(Symbol) && bind_object
      action.call(self) if action.is_a?(Proc)
    end

    def fail!(fail_obj = true)
      @errors      = nil
      @fail_errors = fail_obj
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
