require 'simplecov'
SimpleCov.start

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
