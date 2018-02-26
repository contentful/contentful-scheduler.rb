require 'spec_helper'

describe Contentful::Scheduler::Auth do
  before :each do
    Contentful::Scheduler.config = base_config
  end

  describe 'auth' do
    context 'when no auth is provided' do
      it 'always returns true' do
        webhook = WebhookDouble.new('id', 'no_auth')
        expect(described_class.new(webhook).auth).to be_truthy
      end
    end

    context 'when providing token array auth' do
      it 'false when key not found' do
        webhook = WebhookDouble.new('id', 'valid_token_array')
        expect(described_class.new(webhook).auth).to be_falsey
      end

      it 'false when key found but value not matched' do
        webhook = WebhookDouble.new('id', 'valid_token_array', {}, {}, {'auth' => 'not_valid'})
        expect(described_class.new(webhook).auth).to be_falsey
      end

      it 'true when key found and value matched' do
        webhook = WebhookDouble.new('id', 'valid_token_array', {}, {}, {'auth' => 'test_1'})
        expect(described_class.new(webhook).auth).to be_truthy
      end
    end

    context 'when providing token string auth' do
      it 'false when key not found' do
        webhook = WebhookDouble.new('id', 'valid_token_string')
        expect(described_class.new(webhook).auth).to be_falsey
      end

      it 'false when key found but value not matched' do
        webhook = WebhookDouble.new('id', 'valid_token_string', {}, {}, {'auth' => 'not_valid'})
        expect(described_class.new(webhook).auth).to be_falsey
      end

      it 'true when key found and value matched' do
        webhook = WebhookDouble.new('id', 'valid_token_string', {}, {}, {'auth' => 'test_2'})
        expect(described_class.new(webhook).auth).to be_truthy
      end
    end

    context 'when providing lambda auth' do
      it 'false when key not found' do
        webhook = WebhookDouble.new('id', 'lambda_auth')
        expect(described_class.new(webhook).auth).to be_falsey
      end

      it 'false when key found but value not matched' do
        webhook = WebhookDouble.new('id', 'lambda_auth', {}, {}, {'auth' => 'not_valid'})
        expect(described_class.new(webhook).auth).to be_falsey
      end

      it 'true when key found and value matched' do
        webhook = WebhookDouble.new('id', 'lambda_auth', {}, {}, {'auth' => 'test'})
        expect(described_class.new(webhook).auth).to be_truthy
      end
    end
  end
end
