require 'contentful/webhook/listener'
require_relative 'auth'
require_relative 'queue'

module Contentful
  module Scheduler
    class Controller < ::Contentful::Webhook::Listener::Controllers::WebhookAware
      def create
        return unless webhook.entry?

        if !Auth.new(webhook).auth
          logger.warn "Skipping - Authentication failed for Space: #{webhook.space_id} - Entry: #{webhook.id}"
          return
        end

        logger.info "Queueing - Space: #{webhook.space_id} - Entry: #{webhook.id}"

        Queue.instance(logger).update_or_create(webhook)
      end
      alias_method :save, :create
      alias_method :auto_save, :create
      alias_method :unarchive, :create

      def delete
        return unless webhook.entry?

        if !Auth.new(webhook).auth
          logger.warn "Skipping - Authentication failed for Space: #{webhook.space_id} - Entry: #{webhook.id}"
          return
        end

        logger.info "Unqueueing - Space: #{webhook.space_id} - Entry: #{webhook.id}"

        Queue.instance(logger).remove(webhook)
      end
      alias_method :unpublish, :delete
      alias_method :archive, :delete
      alias_method :publish, :delete
    end
  end
end
