require 'bundler/setup'
require 'awesome_print'
Bundler.setup

require 'coveralls'
Coveralls.wear!

require 'light_operations'
# root_path = File.expand_path('../../', __FILE__)
# Dir[root_path + '/spec/support/**/*.rb'].each { |f| require f }
Dir['./spec/support/**/*.rb'].sort.each { |f| require f }

RSpec.configure do |config|
  config.filter_run :focus
  config.run_all_when_everything_filtered = true

  config.default_formatter = 'doc' if config.files_to_run.one?

  config.profile_examples = 10
  config.order = :random

  Kernel.srand config.seed

  config.expect_with :rspec do |expectations|
    expectations.syntax = :expect
  end

  config.mock_with :rspec do |mocks|
    mocks.syntax = :expect
    mocks.verify_partial_doubles = true
  end
end
require 'guard/rubocop'
