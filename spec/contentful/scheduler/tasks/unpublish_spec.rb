require 'spec_helper'

class MockEntry
  def publish
  end
end

class MockClient
  def entries
  end
end

class MockEntries
  def find
  end
end

describe Contentful::Scheduler::Tasks::Unpublish do
  let(:mock_client) { MockClient.new }
  let(:mock_entries) { MockEntries.new }
  let(:mock_entry) { MockEntry.new }

  before :each do
    ::Contentful::Scheduler.config = base_config
  end

  describe 'class methods' do
    it '::perform' do
      expect(::Contentful::Management::Client).to receive(:new).with(
        'foo',
        raise_errors: true,
        application_name: 'contentful.scheduler',
        application_version: Contentful::Scheduler::VERSION
      ) { mock_client }
      expect(mock_client).to receive(:entries) { mock_entries }
      expect(mock_entries).to receive(:find).with('foo', 'bar') { mock_entry }
      expect(mock_entry).to receive(:unpublish)

      described_class.perform('foo', 'bar', ::Contentful::Scheduler.config[:spaces]['foo'][:management_token])
    end
  end
end
