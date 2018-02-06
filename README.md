# Contentful Scheduler

Scheduling Server for Contentful entries.

## Contentful
[Contentful](https://www.contentful.com) provides a content infrastructure for digital teams to power content in websites, apps, and devices. Unlike a CMS, Contentful was built to integrate with the modern software stack. It offers a central hub for structured content, powerful management and delivery APIs, and a customizable web app that enable developers and content creators to ship digital products faster.

## What does `contentful-scheduler` do?
The aim of `contentful-scheduler` is to have developers setting up their Contentful
entries for scheduled publishing.

## How does it work
`contentful-scheduler` provides a web endpoint to receive webhook calls from Contentful.

Every time the endpoint recieves a call it looks for the value of the field defined in the configuration.
If the value is a time in the future it will schedule the entry for publishing at the specified time.

A background worker based on the popular `resque` gem will then proceed to actually make the publish call
against the Content Management API at the due time. For this the Entries you wish to publish require a
customizable Date field, which we advice to call `publishDate`, this field can be configured inside your
`Rakefile` and is specific per-space.

You can add multiple spaces to your configuration, making it useful if you have a milti-space setup.

## Requirements

* [Redis](http://redis.io/)

## Installation

Add this line to your application's Gemfile:

```ruby
gem 'contentful-scheduler'
```

And then execute:

    $ bundle

Or install it yourself as:

    $ gem install contentful-scheduler

## Usage

The best way to use Scheduler is as a stand-alone application that wraps Scheduler and Resque on an execution pipe using [Foreman](http://ddollar.github.io/foreman/).

You can get the template for this setup in the [`/example`](./example) directory.

If you want to roll out your own, you need to follow the next steps:

* Create a new folder
* Create a `Gemfile` with the following:

```ruby
source 'https://rubygems.org'

gem 'contentful-scheduler', '~> 0.1'
gem 'contentful-management', '~> 1.0'
gem 'resque', '~> 1.0'
gem 'resque-scheduler', '~> 4.0'
gem 'rake'
```

* Create a `Procfile` with the following:

```
web: env bundle exec rake contentful:scheduler
monitor: env bundle exec rackup
resque: env bundle exec rake resque:work
resque_scheduler: env bundle exec rake resque:scheduler
```

* Create a `Rakefile` with the following:

```ruby
require 'contentful/scheduler'

$stdout.sync = true

config = {
  logger: Logger.new(STDOUT), # Defaults to NullLogger
  port: 32123, # Defaults to 32123
  endpoint: '/scheduler', # Defaults to /scheduler
  redis: {
    host: 'YOUR_REDIS_HOST',
    port: 'YOUR_REDIS_PORT',
    password: 'YOUR_REDIS_PASSWORD'
  },
  spaces: {
    'YOUR_SPACE_ID' => {
      publish_field: 'publishDate', # It specifies the field ID for your Publish Date in your Content Type
      management_token: 'YOUR_TOKEN'
    }
  },
}

namespace :contentful do
  task :setup do
    Contentful::Scheduler.config = config
  end

  task :scheduler => :setup do
    Contentful::Scheduler.start
  end
end

require 'resque/tasks'
require 'resque/scheduler/tasks'

namespace :resque do
  task :setup => 'contentful:setup' do
    ENV['QUEUE'] = '*'
  end

  task :setup_schedule => :setup do
    require 'resque-scheduler'
  end

  task :scheduler => :setup_schedule
end
```

* Create a `config.ru` with the following for the Resque monitoring server:

```ruby
require 'resque'
require 'resque/server'
require 'resque/scheduler/server'

config = {
  host: 'YOUR_REDIS_HOST',
  port: 'YOUR_REDIS_PORT',
  password: 'YOUR_REDIS_PASSWORD'
}
Resque.redis = config

run Rack::URLMap.new \
  "/" => Resque::Server.new
```

* Run the Application:

```bash
$ foreman start
```

* Configure the webhook in Contentful:

Under the space settings menu choose webhook and add a new webhook pointing to `http://YOUR_SERVER:32123/scheduler`.

Keep in mind that if you modify the defaults, the URL should be changed to the values specified in the configuration.

## Running in Heroku

Heroku offers various Redis plugins, select the one of your liking, add the credentials into your configuration, and proceed to
`git heroku push master`.

This will get your application set up and running. It will require 4 dynos, so a free plan isn't enough for it to run.

To run the `monitor` process, you'll require to run it from a different application pointing to the same Redis instance.

Make sure to change the `Procfile`'s `web` process to the following:

```
web: PORT=$PORT bundle exec env rake contentful:scheduler
```

That will allow Heroku to set it's own Port according to their policy.

The URL for the webhook then will be on port 80, so you should change it to: `http://YOUR_APPLICATION/scheduler`.

## Contributing

Bug reports and pull requests are welcome on GitHub at https://github.com/contentful/contentful-scheduler.rb. This project is intended to be a safe, welcoming space for collaboration, and contributors are expected to adhere to the [Contributor Covenant](http://contributor-covenant.org) code of conduct.

## License

The gem is available as open source under the terms of the [MIT License](http://opensource.org/licenses/MIT).
