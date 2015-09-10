require 'spec_helper'
require 'action_controller/railtie'
require 'action_view/railtie'
require 'rspec/rails'
require 'rspec/autorun'


describe 'LightOperations::Flow', type: :controller do
  RailsApp = Class.new(Rails::Application)
  RailsApp.config.secret_key_base = '5308dcbbb7dea1b44e3d1d55ea7656f9'
  RailsApp.config.eager_load = false
  RailsApp.config.root = File.dirname(__FILE__)
  RailsApp.routes.draw do
    resources :accounts, only: [:create, :show, :update]
  end

  module TestOperations
    module Accounts
      class Create < LightOperations::Core
        def execute(params:)
          params[:correct] ? 'Create OK' : fail!('Create Fail')
        end
      end

      class Show < LightOperations::Core
        def execute(params:)
          params[:correct] ? 'Show OK' : fail!('Show Fail')
        end
      end

      class Update < LightOperations::Core
        attr_reader :status
        AccessDeny = Class.new(StandardError)
        rescue_from AccessDeny, with: :access_deny_handler

        def execute(params:, current_user: {})
          @status = 200
          fail AccessDeny unless current_user[:id].to_i == 1
          params[:correct] ? 'Update OK' : fail_with_status!(text: 'Update Fail')
        end

        def fail_with_status!(text:, code: 422)
          @status = code
          fail!(text)
        end

        def access_deny_handler
          fail_with_status!(text: 'Update access deny', code: 401)
        end
      end
    end
  end
  context 'default use of flow' do
    controller(RailsApp::ActionController::Base) do
      include Rails.application.routes.url_helpers
      include LightOperations::Flow
      operation :accounts, namespace: TestOperations, actions: [:create]

      def render_create(op)
        render text: op.subject
      end

      def render_fail_create(op)
        render text: op.subject
      end
    end


    it '#render_create as success' do
      post :create, correct: true
      expect(response.body).to eq('Create OK')
    end

    it '#render_fail_create as fail' do
      post :create, {}
      expect(response.body).to eq('Create Fail')
    end
  end

  context 'flow with #view_prefix and #fail_view_prefix' do
    controller(RailsApp::ActionController::Base) do
      include Rails.application.routes.url_helpers
      include LightOperations::Flow
      operation :accounts, namespace: TestOperations, actions: [:create], view_prefix: 'view_', fail_view_prefix: 'fail_view_'

      def view_create(op)
        render text: op.subject
      end

      def fail_view_create(op)
        render text: op.subject
      end
    end


    it '#view_create as success' do
      post :create, correct: true
      expect(response.body).to eq('Create OK')
    end

    it '#fail_view_create as fail' do
      post :create, {}
      expect(response.body).to eq('Create Fail')
    end
  end

  context 'flow with #view_prefix and #fail_view_prefix as one' do
    controller(RailsApp::ActionController::Base) do
      include Rails.application.routes.url_helpers
      include LightOperations::Flow
      operation :accounts, namespace: TestOperations, actions: [:create], view_prefix: 'render_', fail_view_prefix: 'render_'

      def render_create(op)
        status = op.success? ? 200 : 404
        render text: op.subject, status: status
      end
    end


    it '#render_create as success' do
      post :create, correct: true
      expect(response.body).to eq('Create OK')
      expect(response.code).to eq('200')
    end

    it '#render_create as fail' do
      post :create, {}
      expect(response.body).to eq('Create Fail')
      expect(response.code).to eq('404')
    end
  end

  context 'flow with #default_view and #default_fail_view' do
    controller(RailsApp::ActionController::Base) do
      include Rails.application.routes.url_helpers
      include LightOperations::Flow
      operation :accounts, namespace: TestOperations, actions: [:create, :show], default_view: :render_view, default_fail_view: :render_fail_view

      def render_view(op)
        render text: op.subject
      end

      def render_fail_view(op)
        render text: op.subject, status: 422
      end
    end


    it '#render_view as success' do
      post :create, correct: true
      expect(response.body).to eq('Create OK')
      expect(response.code).to eq('200')
      get :show, id: 1, correct: true
      expect(response.body).to eq('Show OK')
      expect(response.code).to eq('200')
    end

    it '#render_fail_view as fail' do
      post :create, {}
      expect(response.body).to eq('Create Fail')
      expect(response.code).to eq('422')
      get :show, id: 1
      expect(response.body).to eq('Show Fail')
      expect(response.code).to eq('422')
    end
  end

  context 'flow with advance customization' do
    controller(RailsApp::ActionController::Base) do
      include Rails.application.routes.url_helpers
      include LightOperations::Flow
      operation :accounts, namespace: TestOperations, actions: [:update], default_view: :render_view, default_fail_view: :render_error

      def render_view(op)
        render text: op.subject, status: op.status
      end

      def render_error(op)
        render text: op.errors, status: op.status
      end

      def operation_opts
        { current_user: { id: params[:id] } }
      end
    end


    it '#render_view as success' do
      post :update, correct: true, id: 1
      expect(response.body).to eq('Update OK')
      expect(response.code).to eq('200')
    end

    it '#render_fail_view as fail' do
      post :update, id: 1
      expect(response.body).to eq('Update Fail')
      expect(response.code).to eq('422')
      post :update, id: 2
      expect(response.body).to eq('Update access deny')
      expect(response.code).to eq('401')
    end
  end
end
