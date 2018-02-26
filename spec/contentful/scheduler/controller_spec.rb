require 'spec_helper'

describe Contentful::Scheduler::Controller do
  let(:server) { MockServer.new }
  let(:logger) { Contentful::Webhook::Listener::Support::NullLogger.new }
  let(:timeout) { 10 }
  let(:headers) { {'X-Contentful-Topic' => '', 'X-Contentful-Webhook-Name' => 'SomeName'} }
  let(:body) { {sys: { id: 'foo', space: { sys: { id: 'space_foo' } } }, fields: {} } }
  let(:queue) { ::Contentful::Scheduler::Queue.instance }
  subject { described_class.new server, logger, timeout }

  before :each do
    Contentful::Scheduler.config = base_config
  end

  describe 'events' do
    [:create, :save, :auto_save, :unarchive].each do |event|
      it "creates or updates webhook metadata in publish queue on #{event}" do
        expect(queue).to receive(:update_or_create)

        headers['X-Contentful-Topic'] = "ContentfulManagement.Entry.#{event}"
        request = RequestDummy.new(headers, body)
        subject.respond(request, MockResponse.new).join
      end
    end

    [:delete, :unpublish, :archive, :publish].each do |event|
      it "deletes webhook metadata in publish queue on #{event}" do
        expect(queue).to receive(:remove)

        headers['X-Contentful-Topic'] = "ContentfulManagement.Entry.#{event}"
        request = RequestDummy.new(headers, body)
        subject.respond(request, MockResponse.new).join
      end
    end

    [:create, :save, :unarchive, :delete, :unpublish, :archive, :publish].each do |event|
      ['Asset', 'ContentType'].each do |kind|
        it "ignores #{kind} on #{event}" do
          expect(queue).not_to receive(:remove)
          expect(queue).not_to receive(:update_or_create)

          headers['X-Contentful-Topic'] = "ContentfulManagement.#{kind}.#{event}"
          request = RequestDummy.new(headers, body)
          subject.respond(request, MockResponse.new).join
        end
      end
    end

    describe 'auth' do
      context 'on auth failure' do
        let(:body) { {sys: { id: 'invalid_auth', space: { sys: { id: 'valid_token_string' } } }, fields: {} } }

        it 'will stop the queueing process' do
          expect(queue).not_to receive(:update_or_create)

          headers['X-Contentful-Topic'] = "ContentfulManagement.Entry.save"
          request = RequestDummy.new(headers, body)
          subject.respond(request, MockResponse.new).join
        end
      end
    end
  end
end
