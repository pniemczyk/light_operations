lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)

require 'light_operations/version'

Gem::Specification.new do |spec|
  spec.name          = 'light_operations'
  spec.version       = LightOperations::VERSION
  spec.authors       = ['Pawel Niemczyk']
  spec.email         = ['pniemczyk.info@.gmail.com']
  spec.summary       = %q{Light operations}
  spec.description   = %q{Light operations for success or fail result}
  spec.homepage      = 'https://github.com/pniemczyk/light_operations'
  spec.license       = 'MIT'

  spec.files         = `git ls-files`.split($INPUT_RECORD_SEPARATOR)
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ['lib']

  spec.add_runtime_dependency 'activesupport', '>= 3.0'
  spec.required_ruby_version = '>= 2.1.4'
  spec.add_development_dependency 'rails', '~> 3.2'
  spec.add_development_dependency 'bundler', '~> 1.6'
  spec.add_development_dependency 'rake', '~> 10.4'
  spec.add_development_dependency 'rspec', '~> 3.3'
  spec.add_development_dependency 'guard', '~> 2.12'
  spec.add_development_dependency 'rspec-rails', '~> 3.3'
  spec.add_development_dependency 'test-unit', '~> 3.0'
  spec.add_development_dependency 'guard-rspec', '~> 4.5'
  spec.add_development_dependency 'guard-rubocop', '~> 1.2'
  spec.add_development_dependency 'awesome_print', '~> 1.6'
end
