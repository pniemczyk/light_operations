# LightOperations

When you want have slim controllers or some logic with several operations
this gem could help you to have nice separated and clan code. CAN HELP YOU! :D

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'light_operations'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install light_operations

## Usage


### Uses cases

#### Simple case when you want have user authorization

Operation

```ruby
class AuthOperation < LightOperations::Core
  rescue_from AuthFail, with: :on_auth_error

  def execute
    dependency(:auth_service).login(login: login, password: password)
  end

  def on_auth_error(_exception)
    fail!([login: 'unknown']) # or subject.errors.add(login: 'unknown')
  end

  def login
    params.fetch(:login)
  end

  def password
    params.fetch(:password)
  end
end
```

Controller way #1

```ruby
class AuthController < ApplicationController
  def new
    render :new, locals: { account: Account.new }
  end

  def create
    auth_op
      .run
      .bind_with(self)
      .on_success(:create_session_with_dashbord_redirection)
      .on_fail(:render_account_with_errors)
  end

  private

  def create_session_with_dashbord_redirection(account)
    session_create_for(account)
    redirect_to :dashboard
  end

  def render_account_with_errors(account, _errors)
    render :new, locals: { account: account }
  end

  def auth_op
    @auth_op ||= AuthOperation.new(params, auth_service: auth_service)
  end

  def auth_service
    @auth_service ||= AuthService.new
  end
end
```

Controller way #2

```ruby
class AuthController < ApplicationController
  def new
    render :new, locals: { account: Account.new }
  end

  def create
    auth_op
      .run
      .on_success{ |account| create_session_with_dashbord_redirection(account) }
      .on_fail { |account, _errors| render :new, locals: { account: account } }
  end

  private

  def create_session_with_dashbord_redirection(account)
    session_create_for(account)
    redirect_to :dashboard
  end

  def auth_op
    @auth_op ||= AuthOperation.new(params, auth_service: auth_service)
  end

  def auth_service
    @auth_service ||= AuthService.new
  end
end
```

Controller way #3

```ruby
class AuthController < ApplicationController
  def new
    render :new, locals: { account: Account.new }
  end

  def create
    auth_op.run.on_success(&go_to_dashboard).on_fail(&go_to_login)
  end

  private

  def go_to_dashboard
    -> (account) do
      session_create_for(account)
      redirect_to :dashboard
    end
  end

  def go_to_login
    -> (account, _errors) { render :new, locals: { account: account } }
  end

  def auth_op
    @auth_op ||= AuthOperation.new(params, auth_service: auth_service)
  end

  def auth_service
    @auth_service ||= AuthService.new
  end
end
```

When operation status is most importent we can simply use `#success?` or `#fail?` on the executed operation

Errors are available by `#errors` after operation is executed

## Contributing

1. Fork it ( https://github.com/[my-github-username]/swift_operations/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
