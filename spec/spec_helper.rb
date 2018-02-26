require 'simplecov'
SimpleCov.start

require 'rspec'

$LOAD_PATH.unshift File.expand_path('../../lib', __FILE__)
require 'contentful/scheduler'
require 'contentful/webhook/listener'
require 'json'

class MockServer
  def [](key)
    nil
  end
end

class MockRequest
end

class MockResponse
  attr_accessor :status, :body
end

class RequestDummy
  attr_reader :headers, :body

  def initialize(headers, body)
    @headers = headers || {}
    @body = JSON.dump(body)
  end

  def [](key)
    headers[key]
  end

  def each
    headers.each do |h, v|
      yield(h, v)
    end
  end
end

class WebhookDouble
  attr_reader :id, :space_id, :sys, :fields, :raw_headers
  def initialize(id, space_id, sys = {}, fields = {}, headers = {})
    @id = id
    @space_id = space_id
    @sys = sys
    @fields = fields
    @raw_headers = headers
  end
end

class Contentful::Webhook::Listener::Controllers::Wait
  @@sleeping = false

  def sleep(time)
    @@sleeping = true
  end

  def self.sleeping
    value = @@sleeping
    @@sleeping = false
    value
  end
end

def base_config
  {
    logger: ::Contentful::Scheduler::DEFAULT_LOGGER,
    endpoint: ::Contentful::Scheduler::DEFAULT_ENDPOINT,
    port: ::Contentful::Scheduler::DEFAULT_PORT,
    redis: {
      host: 'localhost',
      port: 12341,
      password: 'foobar'
    },
    spaces: {
      'foo' => {
        publish_field: 'my_field',
        management_token: 'foo'
      },
      'no_auth' => {
        publish_field: 'my_field',
        management_token: 'foo'
      },
      'valid_token_array' => {
        publish_field: 'my_field',
        management_token: 'foo',
        auth: {
          key: 'auth',
          valid_tokens: ['test_1']
        }
      },
      'valid_token_string' => {
        publish_field: 'my_field',
        management_token: 'foo',
        auth: {
          key: 'auth',
          valid_tokens: 'test_2'
        }
      },
      'lambda_auth' => {
        publish_field: 'my_field',
        management_token: 'foo',
        auth: {
          key: 'auth',
          validation: -> (value) { value.size == 4 }
        }
      }
    }
  }
end

RSpec.configure do |config|
  config.filter_run :focus => true
  config.run_all_when_everything_filtered = true
end
