require 'chronic'
require 'contentful/webhook/listener'
require_relative "tasks"

module Contentful
  module Scheduler
    class Queue
      @@instance = nil

      attr_reader :config, :logger

      def self.instance(logger = ::Contentful::Webhook::Listener::Support::NullLogger.new)
        @@instance ||= new(logger)
      end

      def update_or_create(webhook)
        if publishable?(webhook)
          success = update_or_create_for_publish(webhook)
          log_event_success(webhook, success, 'publish', 'added to')
        end

        if unpublishable?(webhook)
          success = update_or_create_for_unpublish(webhook)
          log_event_success(webhook, success, 'unpublish', 'added to')
        end
      end

      def update_or_create_for_publish(webhook)
        remove_publish(webhook) if in_publish_queue?(webhook)
        return false unless publish_is_future?(webhook)

        return Resque.enqueue_at(
          publish_date(webhook),
          ::Contentful::Scheduler::Tasks::Publish,
          webhook.space_id,
          webhook.id,
          ::Contentful::Scheduler.config[:spaces][webhook.space_id][:management_token]
        )
      end

      def update_or_create_for_unpublish(webhook)
        remove_unpublish(webhook) if in_unpublish_queue?(webhook)
        return false unless unpublish_is_future?(webhook)

        return Resque.enqueue_at(
          unpublish_date(webhook),
          ::Contentful::Scheduler::Tasks::Unpublish,
          webhook.space_id,
          webhook.id,
          ::Contentful::Scheduler.config[:spaces][webhook.space_id][:management_token]
        )
      end

      def remove(webhook)
        remove_publish(webhook)
        remove_unpublish(webhook)
      end

      def remove_publish(webhook)
        return unless publishable?(webhook)
        return unless in_publish_queue?(webhook)

        success = Resque.remove_delayed(
          ::Contentful::Scheduler::Tasks::Publish,
          webhook.space_id,
          webhook.id,
          ::Contentful::Scheduler.config[:management_token]
        )

        log_event_success(webhook, success, 'publish', 'removed from')
      end

      def remove_unpublish(webhook)
        return unless unpublishable?(webhook)
        return unless in_unpublish_queue?(webhook)

        success = Resque.remove_delayed(
          ::Contentful::Scheduler::Tasks::Unpublish,
          webhook.space_id,
          webhook.id,
          ::Contentful::Scheduler.config[:management_token]
        )

        log_event_success(webhook, success, 'unpublish', 'removed from')
      end

      def log_event_success(webhook, success, event_kind, action)
        if success
          logger.info "Webhook {id: #{webhook.id}, space_id: #{webhook.space_id}} successfully #{action} the #{event_kind} queue"
        else
          logger.warn "Webhook {id: #{webhook.id}, space_id: #{webhook.space_id}} couldn't be #{action} the #{event_kind} queue"
        end
      end

      def publishable?(webhook)
        return false unless spaces.key?(webhook.space_id)

        if webhook_publish_field?(webhook)
          return !webhook_publish_field(webhook).nil? && publish_is_future?(webhook)
        end

        false
      end

      def unpublishable?(webhook)
        return false unless spaces.key?(webhook.space_id)

        if webhook_unpublish_field?(webhook)
          return !webhook_unpublish_field(webhook).nil? && unpublish_is_future?(webhook)
        end

        false
      end

      def publish_is_future?(webhook)
        publish_date(webhook) > Time.now.utc
      end

      def unpublish_is_future?(webhook)
        unpublish_date(webhook) > Time.now.utc
      end

      def in_publish_queue?(webhook)
        Resque.peek(::Contentful::Scheduler::Tasks::Publish, 0, -1).any? do |job|
          job['args'][0] == webhook.space_id && job['args'][1] == webhook.id
        end
      end

      def in_unpublish_queue?(webhook)
        Resque.peek(::Contentful::Scheduler::Tasks::Unpublish, 0, -1).any? do |job|
          job['args'][0] == webhook.space_id && job['args'][1] == webhook.id
        end
      end

      def publish_date(webhook)
        date_field = webhook_publish_field(webhook)
        date_field = date_field[date_field.keys[0]] if date_field.is_a? Hash
        Chronic.parse(date_field).utc
      end

      def unpublish_date(webhook)
        date_field = webhook_unpublish_field(webhook)
        date_field = date_field[date_field.keys[0]] if date_field.is_a? Hash
        Chronic.parse(date_field).utc
      end

      def spaces
        config[:spaces]
      end

      def webhook_publish_field?(webhook)
        webhook.fields.key?(spaces.fetch(webhook.space_id, {})[:publish_field]) if webhook.respond_to?(:fields)
      end

      def webhook_unpublish_field?(webhook)
        webhook.fields.key?(spaces.fetch(webhook.space_id, {})[:unpublish_field]) if webhook.respond_to?(:fields)
      end

      def webhook_publish_field(webhook)
        webhook.fields[spaces[webhook.space_id][:publish_field]]
      end

      def webhook_unpublish_field(webhook)
        webhook.fields[spaces[webhook.space_id][:unpublish_field]]
      end

      private

      def initialize(logger)
        @config = ::Contentful::Scheduler.config
        @logger = logger
      end
    end
  end
end
