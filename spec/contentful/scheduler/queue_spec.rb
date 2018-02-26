require 'spec_helper'

describe Contentful::Scheduler::Queue do
  let(:config) { base_config }
  subject { described_class.instance }

  before :each do
    allow(Resque).to receive(:redis=)
    described_class.class_variable_set(:@@instance, nil)

    ::Contentful::Scheduler.class_variable_set(:@@config, base_config)
  end

  describe 'singleton' do
    it 'creates an instance if not initialized' do
      expect(subject).to be_a described_class
    end

    it 'reuses same instance' do
      expect(subject).to eq described_class.instance
    end
  end

  describe 'instance methods' do
    it '#webhook_publish_field?' do
      expect(subject.webhook_publish_field?(
        WebhookDouble.new('bar', 'foo', {}, {'my_field' => 'something'})
      )).to be_truthy

      expect(subject.webhook_publish_field?(
        WebhookDouble.new('bar', 'foo', {}, {'not_my_field' => 'something'})
      )).to be_falsey

      expect(subject.webhook_publish_field?(
        WebhookDouble.new('bar', 'not_foo', {}, {'not_my_field' => 'something'})
      )).to be_falsey
    end

    it '#webhook_publish_field' do
      expect(subject.webhook_publish_field(
        WebhookDouble.new('bar', 'foo', {}, {'my_field' => 'something'})
      )).to eq 'something'
    end

    describe '#publish_date' do
      it 'works if date field not localized' do
        expect(subject.publish_date(
          WebhookDouble.new('bar', 'foo', {}, {'my_field' => '2011-04-04T22:00:00+00:00'})
        )).to eq DateTime.new(2011, 4, 4, 22, 0, 0).to_time.utc
      end

      it 'works if date field localized by grabbing first available locale' do
        expect(subject.publish_date(
          WebhookDouble.new('bar', 'foo', {}, {'my_field' => {'en-US': '2011-04-04T22:00:00+00:00'}})
        )).to eq DateTime.new(2011, 4, 4, 22, 0, 0).to_time.utc

        expect(subject.publish_date(
          WebhookDouble.new('bar', 'foo', {}, {'my_field' => {'en-CA': '2011-04-04T23:00:00Z'}})
        )).to eq DateTime.new(2011, 4, 4, 23, 0, 0).to_time.utc
      end
    end

    describe '#publishable?' do
      it 'false if webhook space not present in config' do
        expect(subject.publishable?(
          WebhookDouble.new('bar', 'not_foo')
        )).to be_falsey
      end

      it 'false if publish_field is not found' do
        expect(subject.publishable?(
          WebhookDouble.new('bar', 'foo')
        )).to be_falsey
      end

      it 'false if publish_field is nil' do
        expect(subject.publishable?(
          WebhookDouble.new('bar', 'foo', {}, {'my_field' => nil})
        )).to be_falsey
      end

      it 'true if publish_field is populated' do
        expect(subject.publishable?(
          WebhookDouble.new('bar', 'foo', {}, {'my_field' => '2111-04-04T22:00:00+00:00'})
        )).to be_truthy
      end
    end

    describe '#in_queue?' do
      it 'false if not in queue' do
        allow(Resque).to receive(:peek) { [] }
        expect(subject.in_queue?(
          WebhookDouble.new('bar', 'foo')
        )).to be_falsey
      end

      it 'true if in queue' do
        allow(Resque).to receive(:peek) { [{'args' => ['foo', 'bar']}] }
        expect(subject.in_queue?(
          WebhookDouble.new('bar', 'foo')
        )).to be_truthy
      end
    end

    describe '#update_or_create' do
      it 'does nothing if webhook is unpublishable' do
        expect(Resque).not_to receive(:enqueue_at)

        subject.update_or_create(WebhookDouble.new('bar', 'not_foo'))
      end

      describe 'webhook is new' do
        it 'queues' do
          mock_redis = Object.new
          allow(mock_redis).to receive(:client) { mock_redis }
          allow(mock_redis).to receive(:id) { 'foo' }
          allow(Resque).to receive(:peek) { [] }
          allow(Resque).to receive(:redis) { mock_redis }

          expect(Resque).to receive(:enqueue_at).with(
            DateTime.strptime('2099-04-04T22:00:00+00:00').to_time.utc,
            ::Contentful::Scheduler::Tasks::Publish,
            'foo',
            'bar',
            'foo'
          ) { true }

          subject.update_or_create(WebhookDouble.new('bar', 'foo', {}, {'my_field' => '2099-04-04T22:00:00+00:00'}))
        end

        it 'does nothing if already published' do
          allow(Resque).to receive(:peek) { [] }
          expect(Resque).not_to receive(:enqueue_at)

          subject.update_or_create(WebhookDouble.new('bar', 'foo', {}, {'my_field' => '2011-04-04T22:00:00+00:00'}))
        end
      end

      describe 'webhook already in queue' do
        it 'calls remove then queues again' do
          mock_redis = Object.new
          allow(mock_redis).to receive(:client) { mock_redis }
          allow(mock_redis).to receive(:id) { 'foo' }
          allow(Resque).to receive(:redis) { mock_redis }

          allow(Resque).to receive(:peek) { [{'args' => ['foo', 'bar']}] }
          expect(Resque).to receive(:enqueue_at).with(
            DateTime.strptime('2099-04-04T22:00:00+00:00').to_time.utc,
            ::Contentful::Scheduler::Tasks::Publish,
            'foo',
            'bar',
            'foo'
          ) { true }
          expect(subject).to receive(:remove)

          subject.update_or_create(WebhookDouble.new('bar', 'foo', {}, {'my_field' => '2099-04-04T22:00:00+00:00'}))
        end
      end
    end

    describe '#remove' do
      it 'does nothing if webhook is unpublishable' do
        expect(Resque).not_to receive(:remove_delayed)

        subject.remove(WebhookDouble.new('bar', 'foo'))
      end

      it 'does nothing if webhook not in queue' do
        allow(Resque).to receive(:peek) { [] }
        expect(Resque).not_to receive(:remove_delayed)

        subject.remove(WebhookDouble.new('bar', 'foo', {}, {'my_field' => '2011-04-04T22:00:00+00:00'}))
      end

      it 'removes if in queue' do
        allow(Resque).to receive(:peek) { [{'args' => ['foo', 'bar']}] }
        expect(Resque).to receive(:remove_delayed)

        subject.remove(WebhookDouble.new('bar', 'foo', {}, {'my_field' => '2111-04-04T22:00:00+00:00'}))
      end
    end
  end
end
