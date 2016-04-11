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

describe Contentful::Scheduler::Tasks::Publish do
  let(:mock_client) { MockClient.new }
  let(:mock_entries) { MockEntries.new }
  let(:mock_entry) { MockEntry.new }

  before :each do
    ::Contentful::Scheduler.class_variable_set(:@@config, {management_token: 'foobar'})
  end

  describe 'class methods' do
    it '::perform' do
      expect(::Contentful::Management::Client).to receive(:new) { mock_client }
      expect(mock_client).to receive(:entries) { mock_entries }
      expect(mock_entries).to receive(:find).with('foo', 'bar') { mock_entry }
      expect(mock_entry).to receive(:publish)

      described_class.perform('foo', 'bar', ::Contentful::Scheduler.config[:management_token])
    end
  end
end
