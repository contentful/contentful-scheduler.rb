# coding: utf-8
lib = File.expand_path('../lib', __FILE__)
$LOAD_PATH.unshift(lib) unless $LOAD_PATH.include?(lib)
require 'contentful/scheduler/version'

Gem::Specification.new do |spec|
  spec.name          = "contentful-scheduler"
  spec.version       = Contentful::Scheduler::VERSION
  spec.authors       = ["Contentful GmbH (David Litvak Bruno0"]
  spec.email         = ["david.litvak@contentful.com"]

  spec.summary       = %q{Customizable Scheduler for Contentful Entries.}
  spec.description   = %q{Customizable Scheduler for Contentful Entries.}
  spec.homepage      = "https://www.contentful.com"
  spec.license       = "MIT"

  spec.files         = `git ls-files -z`.split("\x0")
  spec.executables   = spec.files.grep(%r{^bin/}) { |f| File.basename(f) }
  spec.test_files    = spec.files.grep(%r{^(test|spec|features)/})
  spec.require_paths = ["lib"]

  spec.add_runtime_dependency "contentful-webhook-listener", "~> 0.2"
  spec.add_runtime_dependency "contentful-management", "~> 1.0"
  spec.add_runtime_dependency "resque", "~> 1.0"
  spec.add_runtime_dependency "resque-scheduler", "~> 4.0"
  spec.add_runtime_dependency "redis", "~> 3.0"

  spec.add_development_dependency "bundler", "~> 1.10"
  spec.add_development_dependency "rake", "~> 10.0"
  spec.add_development_dependency "rspec"
  spec.add_development_dependency "guard"
  spec.add_development_dependency "guard-rspec"
  spec.add_development_dependency "simplecov"
end
