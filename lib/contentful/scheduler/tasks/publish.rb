require 'contentful/management'

module Contentful
  module Scheduler
    module Tasks
      class Publish
        @queue = :publish

        def self.perform(space_id, entry_id, token)
          client = ::Contentful::Management::Client.new(
            token,
            raise_errors: true,
            application_name: 'contentful.scheduler',
            application_version: Contentful::Scheduler::VERSION
          )
          client.entries.find(space_id, entry_id).publish
        end
      end
    end
  end
end
