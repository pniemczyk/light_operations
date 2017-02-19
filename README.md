# LightOperations

[![Gem Version](https://badge.fury.io/rb/light_operations.svg)](http://badge.fury.io/rb/light_operations)
[![Build Status](https://travis-ci.org/pniemczyk/light_operations.svg)](https://travis-ci.org/pniemczyk/light_operations)
[![Dependency Status](https://gemnasium.com/pniemczyk/light_operations.svg)](https://gemnasium.com/pniemczyk/light_operations)
[![Code Climate](https://codeclimate.com/github/pniemczyk/light_operations/badges/gpa.svg)](https://codeclimate.com/github/pniemczyk/light_operations)

When you want to have slim controllers or some logic with several operations
this gem could help you to have nice separated and clean code. CAN HELP YOU! :D

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'light_operations'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install light_operations

 **Important latest version of gem > 1.2.x works only with ruby 2.x**

## How it works

Basically, this is a Container for business logic.

You can define dependencies during initialization and run with custom parameters.
When you define deferred actions on `success` and `fail` before operation execution is finished,
after execution one of those actions depend on for execution result will be executed.
Actions could be a block (Proc) or you could delegate execution to method another object,
by binding operation with the specific object with those methods.
You also could use operation as simple execution and check status by `success?` or `fail?` method
and then by using `subject` and `errors` method build your own logic to finish your result.
There are many possible use-cases where and how you could use operations.
You can build cascade of operations, use them one after the other,
use them recursively and a lot more.


Examples:

#### Simple
```ruby
require 'light_operations'

class CorrectNumber < LightOperations::Core
  def execute(params)
    params[:number] > 0 || fail!(:wrong_number)
  end
end

op = CorrectNumber.new

p op.run(number: 0).success? # return false
p op.run(number: 0).false?   # return true
p op.run(number: 1).success? # return true
p op.run(number: 1).false?   # return false
```

#### With active_model

```ruby
require 'light_operations'
require 'active_model'

class Person
  include ActiveModel::Model

  attr_accessor :name, :age
  validates_presence_of :name
end

class CreatePerson < LightOperations::Core
  subject_name :person
  def execute(params = {})
    dependency(:repository).new(params).tap do |person|
      person.valid?
    end
  end
end

class FakeController
  def create(params = {})
    create_operation.run(params)
  end

  def create_operation
    @create_operation ||= CreatePerson.new(repository: Person).bind_with(self).on(success: :render_success, fail: :render_fail)
  end

  def render_success(operation)
    person = operation.person
    puts "name: #{person.name}"
  end

  def render_fail(operation)
    person, errors = operation.subject, operation.errors
    puts errors.as_json
    puts "name: #{person.name}"
  end
end

```
Class

```ruby
class MyOperation < LightOperations::Core
  def execute(_params = nil)
    dependency(:my_service) # when missing MissingDependency error will be raised
  end
end

```

Initialization

```ruby
MyOperation.new(my_service: MyService.new)
```

You can add deferred actions for success and fail

```ruby
# 1
MyOperation.new.on_success { |operation| render :done, locals: { model: operation.subject } }
# 2
MyOperation.new.on(success: -> () { |operation| render :done, locals: { model: operation.subject } )
```

When you bind operation with another object you could delegate actions to bound object methods

```ruby
# 1
MyOperation.new.bind_with(self).on_success(:done)
# 2
MyOperation.new.bind_with(self).on(success: :done)
```

Execution method `#run` finalize actions execution

```ruby
MyOperation.new.bind_with(self).on(success: :done).run(params)
```

After execution operation hold execution state you could get back all info you need

- `#success?` => `true/false`
- `#fail?`    => `true/false`
- `#subject?` => `success or fail object`
- `#errors`   => `errors by default array but you can return any objec tou want`

Default usage

```ruby
operation.new(dependencies)
  .on(success: :done, fail: :show_error)
  .bind_with(self)
  .run(params)
```

or

```ruby
operation.new(dependencies).tap do |op|
  return op.run(params).success? ? op.subject : op.errors
end
```

#### success block or method receive operation as argument
##### operation.subject  hold success object. You can use subject_name to create alias_method for subject
`(operation) -> { }`

or

```ruby
def success_method(operation)
  ...
end

```
#### fail block or method receive operation as argument
##### operation.subject, operation.errors  hold failure object and errors. You can use subject_name to create alias_method for subject
`(operation) -> { }`

or

```ruby
def fail_method(operation)
  ...
end

```

## Usage


### Uses cases

#### Basic vote logic

Operation

```ruby
class ArticleVoteBumperOperation < LightOperations::Core
  rescue_from ActiveRecord::ActiveRecordError, with: :on_ar_error

  def execute(_params = nil)
    dependency(:article_model).tap do |article|
      article.vote = article.vote.next
      article.save
    end
    { success: true }
  end

  def on_ar_error(_exception)
    fail!(vote: 'could not be updated!')
  end
end
```

Controller

```ruby
class ArticleVotesController < ApplicationController
  def up
    response = operation.run.success? ? response.subject : response.errors
    render :up, json: response
  end

  private

  def operation
    @operation ||= ArticleVoteBumperOperation.new(article_model: article)
  end

  def article
    Article.find(params.require(:id))
  end
end
```

#### Basic recursive execution to collect news feeds from 2 sources

Operation

```ruby
class CollectFeedsOperation < LightOperations::Core
  rescue_from Timeout::Error, with: :on_timeout
  subject_name :news

  def execute(params = {})
    dependency(:http_client).get(params.fetch(:url)).body
  end

  def on_timeout
    fail!
  end
end
```

Controller

```ruby
class NewsFeedsController < ApplicationController
  DEFAULT_NEWS_URL = 'http://rss.best_news.pl'
  BACKUP_NEWS_URL = 'http://rss.not_so_bad_news.pl'
  def news
    collect_feeds_op
      .bind_with(self)
      .on(success: :display_news, fail: :second_attempt)
      .run(url: DEFAULT_NEWS_URL)
  end

  private

  def second_attempt(operation)
    operation
      .on_fail(:display_old_news)
      .run(url: BACKUP_NEWS_URL)
  end

  def display_news(operation)
    render :display_news, locals: { news: operation.news }
  end

  def display_old_news
  end

  def collect_feeds_op
    @collect_feeds_op ||= CollectFeedsOperation.new(http_client: http_client)
  end

  def http_client
    MyAwesomeHttpClient
  end
end
```

#### Basic with active_model/active_record object

Operation

```ruby
class AddBookOperation < LightOperations::Core
  subject_name :book
  def execute(params = {})
    dependency(:book_model).new(params).tap do |model|
      model.valid? # this method automatically provide errors from model.errors
    end
  end
end
```

Controller

```ruby
class BooksController < ApplicationController
  def index
    render :index, locals: { collection: Book.all }
  end

  def new
    render_book_form
  end

  def create
    add_book_op
      .bind_with(self)
      .on(success: :book_created, fail: :render_book_form)
      .run(permit_book_params)
  end

  private

  def book_created(operation)
    redirect_to :index, notice: "book #{operation.book.name} created"
  end

  def render_book_form(operation=nil)
  book = operation ? operation.book : Book.new
    render :new, locals: { book: book }
  end

  def add_book_op
    @add_book_op ||= AddBookOperation.new(book_model: Book)
  end

  def permit_book_params
    params.requre(:book)
  end
end
```

#### Simple case when you want have user authorization

Operation

```ruby
class AuthOperation < LightOperations::Core
  rescue_from AuthFail, with: :on_auth_error
  subject_name :account
  def execute(params = {})
    dependency(:auth_service).login(login: login(params), password: password(params))
  end

  def on_auth_error(_exception)
    fail!([login: 'unknown']) # or subject.errors.add(login: 'unknown')
  end

  def login(params)
    params.fetch(:login)
  end

  def password(params)
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
      .bind_with(self)
      .on_success(:create_session_with_dashbord_redirection)
      .on_fail(:render_account_with_errors)
      .run(params)
  end

  private

  def create_session_with_dashbord_redirection(operation)
    session_create_for(operation.account)
    redirect_to :dashboard
  end

  def render_account_with_errors(operation)
    render :new, locals: { account: operation.account }
  end

  def auth_op
    @auth_op ||= AuthOperation.new(auth_service: auth_service)
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
      .on_success{ |op| create_session_with_dashbord_redirection(op.account) }
      .on_fail { |op| render :new, locals: { account: op.account } }
      .run(params)
  end

  private

  def create_session_with_dashbord_redirection(account)
    session_create_for(account)
    redirect_to :dashboard
  end

  def auth_op
    @auth_op ||= AuthOperation.new(auth_service: auth_service)
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
    auth_op.on_success(&go_to_dashboard).on_fail(&go_to_login).run(params)
  end

  private

  def go_to_dashboard
    -> (op) do
      session_create_for(op.account)
      redirect_to :dashboard
    end
  end

  def go_to_login
    -> (op) { render :new, locals: { account: op.account } }
  end

  def auth_op
    @auth_op ||= AuthOperation.new(auth_service: auth_service)
  end

  def auth_service
    @auth_service ||= AuthService.new
  end
end
```

Register success and fails action is available by `#on` like:

```ruby
  def create
    auth_op.bind_with(self).on(success: :dashboard, fail: :show_error).run(params)
  end
```

Operation have some helper methods (to improve recursive execution)

- `#clear!`                     => return operation to init state
- `#unbind!`                    => unbind binded object
- `#clear_subject_with_errors!` => clear subject and errors

When operation status is most important we can simply use `#success?` or `#fail?` on the executed operation

Errors are available by `#errors` after operation is executed

### Whats new in 1.2.x
New module LightOperations::Flow which gives very simple and easy way to create operation per action in the controller (tested on rails).

#### How it works:

include the module in a controller like this
```ruby
class AccountsController < VersionController
  include LightOperations::Flow
  operation :accounts, namespace: Operations, actions: [:create, :show]
  def render_create(op)
    render text: op.subject
  end

  def render_fail_create(op)
    render text: op.errors # or if you want to show form use 'op.subject'
  end
end
```

Now create operation class for account creation (components/operations/accounts/create.rb):

```ruby
module Operations
  module Accounts
    class Create < LightOperations::Core
      rescue_from ActiveRecord::RecordInvalid, with: :invalid_record_handler

      def execute(params:)
        Account.create!(params.require(:account))
      end

      private

      def invalid_record_handler(ex)
        fail!(ex.record.errors)
      end
    end
  end
end
```

add into `application.rb`

```ruby
config.autoload_paths += %W(
  #{config.root}/app/components
)
```

But it is not all :D (operation params gives you a lot more)

```ruby
class AccountsController < VersionController
  include LightOperations::Flow
  operation(
    :accounts, # top-level namespace
    namespace: Operations, # Base namespace by default is Kernel
    actions: [:create, :show], # those are operations executed by router
    default_view: nil, # By changing this option you can have one method for render all successful operations for all actions.
    view_prefix: 'render_', # By changing this you can have #view_create instead of #render_create
    default_fail_view: nil, # By changing this option you can have one method for render all failed operations for all actions.
    fail_view_prefix: 'render_fail_' # By changing this you can have #view_fail_create instead of #render_fail_create
end
```

This simple module should give you the power to create something like this:

```ruby
module Api
  module V1
    class AccountsController < VersionController
      include LightOperations::Flow
      skip_before_action :authorize, only: [:create, :password_reset]
      operation :accounts,
                namespace: Operations,
                actions: [:create, :update, :show, :destroy, :password_reset],
                default_fail_view: :render_error

      private

      def render_operation_error(op)
        render json: op.errors, status: 422 # you can have status in operation if you want
      end

      def render_account(op)
        render json: AccountOwnerSerializer.new(op.account), status: op.status
      end

      def render_no_content(_op)
        render nothing: true, status: :no_content
      end

      alias_method :render_update, :render_account
      alias_method :render_create, :render_account
      alias_method :render_password_reset, :render_no_content
      alias_method :render_destroy, :render_no_content
    end
  end
end


```

## Contributing

1. Fork it ( https://github.com/[my-github-username]/light_operations/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
