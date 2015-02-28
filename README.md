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
  end

  def on_ar_error(_exception)
    fail!({ vote: 'could not be updated!' })
  end
end
```

Controller

```ruby
class ArticleVotesController < ApplicationController
  def up
    response = article_vote_bumper_op.run.success? ? { success: true } : article_vote_bumper_op.errors
    render :up, json: response
  end

  private

  def article_vote_bumper_op
    @article_vote_bumper_op ||= ArticleVoteBumperOperation.new(article_model: article)
  end

  def article
    Article.find(params.require(:id))
  end
end
```

#### Basic recursion execution for collect newsfeeds from 2 sources

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
      on(success: :display_news, fail: :second_attempt)
      .run(url: DEFAULT_NEWS_URL)
  end

  private

  def second_attempt(_news, _errors)
    collect_feeds_op
      .on_fail(:display_old_news)
      .run(url: BACKUP_NEWS_URL)
  end

  def display_news(news)
    render :display_news, locals { news: news }
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

When operation status is most importent we can simply use `#success?` or `#fail?` on the executed operation

Errors are available by `#errors` after operation is executed

## Contributing

1. Fork it ( https://github.com/[my-github-username]/swift_operations/fork )
2. Create your feature branch (`git checkout -b my-new-feature`)
3. Commit your changes (`git commit -am 'Add some feature'`)
4. Push to the branch (`git push origin my-new-feature`)
5. Create a new Pull Request
