require 'active_support'

module LightOperations
  class Core
    include ::ActiveSupport::Rescuable
    MissingDependency = Class.new(StandardError)

    attr_reader :dependencies, :params, :subject, :bind_oject

    def initialize(params = {}, dependencies = {})
      @params, @dependencies = params, dependencies
    end

    # do not override this method
    def run
      @subject = execute
      self
    rescue => exception
      rescue_with_handler(exception) || raise
      self
    end

    def bind_with(binding_obj)
      @bind_oject = binding_obj
      self
    end

    def on_success(binded_method = nil, &block)
      if success?
        bind_oject.send(binded_method, subject) if can_use_binding_method?(binded_method)
        block.call(subject) if block_given?
      end
      self
    end

    def on_fail(binded_method = nil, &block)
      unless success?
        bind_oject.send(binded_method, subject, errors) if can_use_binding_method?(binded_method)
        block.call(subject, errors) if block_given?
      end
      self
    end

    def errors
      @errors ||= (subject.respond_to?(:errors) ? subject.errors : [])
    end

    def fail?
      !success?
    end

    def success?
      errors.respond_to?(:empty?) ? errors.empty? : !errors
    end

    protected

    def can_use_binding_method?(method_name)
      method_name && bind_oject && bind_oject.respond_to?(method_name)
    end

    def execute
      fail 'Not implemented yet'
    end

    def fail!(errors = [])
      @errors = errors
    end

    def dependency(name)
      dependencies.fetch(name)
    rescue KeyError => e
      raise MissingDependency, e.message
    end
  end
end
