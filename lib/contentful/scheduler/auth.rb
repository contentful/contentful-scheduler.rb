module Contentful
  module Scheduler
    class Auth
      attr_reader :webhook

      def initialize(webhook)
        @webhook = webhook
      end

      def auth
        return true if auth_config.nil?

        return verify_key_value_config if key_value_config?
        return verify_lambda_config if lambda_config?

        false
      end

      private

      def key_value_config?
        auth_config.key?(:key) && auth_config.key?(:valid_tokens)
      end

      def verify_key_value_config
        value = webhook.raw_headers[auth_config[:key]]

        return false if value.nil?

        valid_tokens = auth_config[:valid_tokens]

        return valid_tokens.include?(value) if valid_tokens.is_a?(::Array)
        valid_tokens == value
      end

      def lambda_config?
        auth_config.key?(:key) && auth_config.key?(:validation)
      end

      def verify_lambda_config
        value = webhook.raw_headers[auth_config[:key]]

        return false if value.nil?

        validation = auth_config[:validation]

        return false unless validation.is_a?(::Proc)

        validation[value]
      end

      def auth_config
        ::Contentful::Scheduler.config
          .fetch(:spaces, {})
          .fetch(space_id, {})
          .fetch(:auth, nil)
      end

      def space_id
        webhook.space_id
      end
    end
  end
end
