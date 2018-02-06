require_relative "tasks"
require 'chronic'
require 'contentful/webhook/listener'

module Contentful
  module Scheduler
    class Queue
      @@instance = nil

      attr_reader :config, :logger

      def self.instance(logger = ::Contentful::Webhook::Listener::Support::NullLogger.new)
        @@instance ||= new(logger)
      end

      def update_or_create(webhook)
        return unless publishable?(webhook)
        remove(webhook) if in_queue?(webhook)
        return unless publish_is_future?(webhook)

        success = Resque.enqueue_at(
          publish_date(webhook),
          ::Contentful::Scheduler::Tasks::Publish,
          webhook.space_id,
          webhook.id,
          ::Contentful::Scheduler.config[:spaces][webhook.space_id][:management_token]
        )

        if success
          logger.info "Webhook {id: #{webhook.id}, space_id: #{webhook.space_id}} successfully added to queue"
        else
          logger.warn "Webhook {id: #{webhook.id}, space_id: #{webhook.space_id}} couldn't be added to queue"
        end
      end

      def remove(webhook)
        return unless publishable?(webhook)
        return unless in_queue?(webhook)

        success = Resque.remove_delayed(
          ::Contentful::Scheduler::Tasks::Publish,
          webhook.space_id,
          webhook.id,
          ::Contentful::Scheduler.config[:management_token]
        )

        if success
          logger.info "Webhook {id: #{webhook.id}, space_id: #{webhook.space_id}} successfully removed from queue"
        else
          logger.warn "Webhook {id: #{webhook.id}, space_id: #{webhook.space_id}} couldn't be removed from queue"
        end
      end

      def publishable?(webhook)
        return false unless spaces.key?(webhook.space_id)

        if webhook_publish_field?(webhook)
          return !webhook_publish_field(webhook).nil? && publish_is_future?(webhook)
        end

        false
      end

      def publish_is_future?(webhook)
        publish_date(webhook) > Time.now.utc
      end

      def in_queue?(webhook)
        Resque.peek(::Contentful::Scheduler::Tasks::Publish, 0, -1).any? do |job|
          job['args'][0] == webhook.space_id && job['args'][1] == webhook.id
        end
      end

      def publish_date(webhook)
        date_field = webhook_publish_field(webhook)
        date_field = date_field[date_field.keys[0]] if date_field.is_a? Hash
        Chronic.parse(date_field).utc
      end

      def spaces
        config[:spaces]
      end

      def webhook_publish_field?(webhook)
        webhook.fields.key?(spaces.fetch(webhook.space_id, {})[:publish_field])
      end

      def webhook_publish_field(webhook)
        webhook.fields[spaces[webhook.space_id][:publish_field]]
      end

      private

      def initialize(logger)
        @config = ::Contentful::Scheduler.config
        @logger = logger
      end
    end
  end
end
