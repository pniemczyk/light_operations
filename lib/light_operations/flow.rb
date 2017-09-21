module LightOperations
  module Flow
    def self.included(base)
      base.send(:extend, ClassMethods)
    end

    attr_reader :operation_opts, :operation_dependencies

    module ClassMethods
      def operation(operation_name, namespace: Kernel, actions: [], default_view: nil, view_prefix: 'render_', default_fail_view: nil, fail_view_prefix: 'render_fail_') # rubocop:disable all
        actions.each do |action_name|
          operation_method = "#{action_name}_op"

          define_method(action_name.to_s) do
            send(operation_method).run((operation_opts || {}).merge(params: params))
          end

          define_method(operation_method) do
            success_view = default_view || "#{view_prefix}#{action_name}".to_sym
            fail_view    = default_fail_view || "#{fail_view_prefix}#{action_name}".to_sym
            const        = operation_name.to_s.titleize.delete(' ')
            action       = action_name.to_s.titleize.delete(' ')
            namespace.const_get(const).const_get(action)
              .new(operation_dependencies)
              .bind_with(self)
              .on_success(success_view)
              .on_fail(fail_view)
          end
        end
      end
    end
  end
end
