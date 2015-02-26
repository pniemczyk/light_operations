require 'active_support'

module LightOperations
  class Core
    include ::ActiveSupport::Rescuable
    MissingDependency = Class.new(StandardError)

    attr_reader :dependencies, :params, :subject, :binding

    def initialize(params = {}, dependencies = {})
      @params, @dependencies = params, dependencies
    end

    # do not override this method
    def run
      @subject = execute
      self
    rescue => exception
      rescue_with_handler(exception) || raise
    ensure
      self
    end

    def bind_with(binding)
      @binding = binding
    end

    def on_success(binded_method = nil, &block)
      if success?
        binding.send(binded_method, subject) if binding && binding.respond_to?(binded_method)
        block.call(subject) if block_given?
      end
      self
    end

    def on_fail(binded_method = nil, &block)
      unless success?
        binding.send(binded_method, subject, errors) if binding && binding.respond_to?(binded_method)
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
