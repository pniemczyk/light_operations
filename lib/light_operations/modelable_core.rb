require 'active_support'

module LightOperations
  class ModelableCore < Core
    class << self
      def defaults
        @defaults ||= {}
      end

      def model(model_class = nil)
        if model_class.nil?
          defaults[:model] || fail('[LightOperations] missing model_class')
        else
          defaults[:model] = model_class
        end
      end

      def action_kind(type = nil)
        if type.nil?
          defaults[:action_kind] ||= :create
        else
          fail('[LightOperations] unknown action_kind type.') unless [:create, :update].include?(type)
          defaults[:action_kind] = type
        end
      end

      def validation(&block)
        if block_given?
          defaults[:validation] = block
        else
          defaults[:validation]
        end
      end
    end

    def form(*args)
      model(*args)
    end

    def model(*args)
      @subject ||= args.nil? ? self.class.model.new : self.class.model.new(*args)
    end

    def validate(params)
      model_instance = setup_model(params)
      execute_validation(model_instance) if self.class.validation
      yield(model_instance) if block_given?
      @subject = model_instance
    end

    def setup_model(params)
      instantiate_model(model_with_validation_class, params)
    end

    private

    def instantiate_model(model_class, params)
      send("#{self.class.action_kind}_model", model_class, params)
    end

    def create_model(model_class, params)
      model_class.new(params)
    end

    def update_model(model_class, params)
      find_model(model_class, params).tap do |model_instance|
        update_model_attrs(model_instance, params)
      end
    end

    # Should be overrided when the model is not a active_record model
    def update_model_attrs(model_instance, params)
      model_instance.update_attributes(params)
    end

    # Should be overrided when the model is not a active_record model
    def find_model(params)
      model_class.find(params[:id])
    end

    def execute_validation(model_instance)
      model_instance.valid?
    end

    def refined_model_class
      if self.class.validation
        refine_obj_by_validation(self.class.model, &self.class.validation)
      else
        self.class.model
      end
    end

    def model_with_validation_class
      @model_with_validation_class ||= model_class.clone.tap do |m_class|
        operation_name = self.class.name
        m_class.class_eval("def self.name; \"#{model_class}::#{operation_name}\"; end")
        m_class.class_eval(&self.class.validation) if self.class.validation
      end
    end

    def model_class
      self.class.model
    end
  end
end
