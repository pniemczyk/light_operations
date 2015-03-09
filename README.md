# LightOperations

[![Gem Version](https://badge.fury.io/rb/light_operations.svg)](http://badge.fury.io/rb/light_operations)
[![Build Status](https://travis-ci.org/pniemczyk/light_operations.svg)](https://travis-ci.org/pniemczyk/light_operations)
[![Dependency Status](https://gemnasium.com/pniemczyk/light_operations.svg)](https://gemnasium.com/pniemczyk/light_operations)
[![Code Climate](https://codeclimate.com/github/pniemczyk/light_operations/badges/gpa.svg)](https://codeclimate.com/github/pniemczyk/light_operations)

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

## How it works

Basicly this is a Container for buissnes logic.

You can define dependencies during initialization and run with custom parameters.
When you define deferred actions on `success` and `fail` before operation execution is finished,
after execution one of those action depend for execution result will be executed.
Actions could be a block (Proc) or you could delgate execution to method other object,
by binding operation with specific object with those methods.
You also could use operation as simple execution and check status by `success?` or `fail?` method
and then by using `subject` and `errors` method build your own logic to finish your result.
There is many possible usecases where and how you could use operations.
You can build csacade of opreations, use them one after the other,
use them recursively and a lot more.

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
MyOperation.new.on_success { |model| render :done, locals: { model: model } }
# 2
MyOperation.new.on(success: -> () { |model| render :done, locals: { model: model } )
```

When you bind operation with other object you could delegate actions to binded object methods

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

#### success block or method receive subject as argument
`(subject) -> { }`

or

```ruby
def success_method(subject)
  ...
end

```
#### fail block or method receive subject and errors as argument
`(subject, errors) -> { }`

or

```ruby
def fail_method(subject, errors)
  ...
end

```

## Usage

### Usage cases

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

#### Basic recursive execution to collect newsfeeds from 2 sources

Operation

```ruby
class CollectFeedsOperation < LightOperations::Core
  rescue_from Timeout::Error, with: :on_timeout

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

  def second_attempt(_news, _errors)
    collect_feeds_op
      .on_fail(:display_old_news)
      .run(url: BACKUP_NEWS_URL)
  end

  def display_news(news)
    render :display_news, locals: { news: news }
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

  def book_created(book)
    redirect_to :index, notice: "book #{book.name} created"
  end

  def render_book_form(book = Book.new, _errors = nil)
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

  def create_session_with_dashbord_redirection(account)
    session_create_for(account)
    redirect_to :dashboard
  end

  def render_account_with_errors(account, _errors)
    render :new, locals: { account: account }
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
      .on_success{ |account| create_session_with_dashbord_redirection(account) }
      .on_fail { |account, _errors| render :new, locals: { account: account } }
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
    -> (account) do
      session_create_for(account)
      redirect_to :dashboard
    end
  end

  def go_to_login
    -> (account, _errors) { render :new, locals: { account: account } }
  end

  def auth_op
    @auth_op ||= AuthOperation.new(auth_service: auth_service)
  end

  def auth_service
    @auth_service ||= AuthService.new
  end
end
```

Register success and fails action is avialable by `#on` like :

```ruby
  def create
    auth_op.bind_with(self).on(success: :dashboard, fail: :show_error).run(params)
  end
```

Operation have some helper methods (to improve recursive execution)

- `#clear!`                     => return operation to init state
- `#unbind!`                    => unbind binded object
- `#clear_subject_with_errors!` => clear subject and errors

When operation status is most importent we can simply use `#success?` or `#fail?` on the executed operation

Errors are available by `#errors` after operation is executed

#### In v0.0.7 was added new core `LightOperations::ModelableCore`

#### LightOperations::ModelableCore
It is based on `LightOperations::Core`.
This core allow to use model as subject of operation. This core nicely separate validation logic from domain model and could be helpful with view forms (smoothly adapts to `ActiveRecord::Base` and `ActiveModel::Model` models it's not a requirement)

## Usage

There are 2 different operation modes `[:create, :update]` those modes determines that you want to create new entity or update old one. In the following examples I try to explain those differences

Class with create operation
```ruby
class AddBookOperation < LightOperations::ModelableCore
  rescue_from ActiveRecord::Errors, with: :db_error
  action_kind :create # by default
  model Book
  validation do
    validates :name, presence: true
  end

  def execute(params = {})
  validate(params) do |instance|
    #additional validation
    if instance.name.include?('test')
      instance.save!
    else
      model.errors.add(:name, 'only test books allowed')
    end
  end
  end

  def db_error(e)
    model.errors.add(:name, 'could not be saved')
  end
end
```

Class with update operation
```ruby
class EditBookOperation < LightOperations::ModelableCore
  rescue_from ActiveRecord::Errors, with: :db_error
  action_kind :update
  model Book
  validation do
    validates :name, presence: true
    validates :editor, presence: true
  end

  def execute(params = {})
  validate(params) do |instance|
    instance.save!
  end
  end

  def db_error(e)
    model.errors.add(:name, 'could not be saved')
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

  def edit
    render_book_edit_form
  end

  def save
    edit_book_op
      .bind_with(self)
      .on(success: :book_created_or_saved, fail: :render_book_edit_form)
      .run(permit_book_params)
  end

  private

  def book_created_or_saved(book)
    redirect_to :index, notice: "book #{book.name} created or updated"
  end

  def render_book_edit_form(book = edit_book_op.form, _errors = nil)
    render :edit, locals: { book: book }
  end

  def render_book_form(book = add_book_op.form, _errors = nil)
    render :new, locals: { book: book }
  end

  def add_book_op
    @add_book_op ||= AddBookOperation.new
  end

  def edit_book_op
    @edit_book_op ||= EditBookOperation.new
  end

  def permit_book_params
    params.requre(:book)
  end
end
```



## Contributing

1. Fork it ( https://github.com/[my-github-username]/light_operations/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
