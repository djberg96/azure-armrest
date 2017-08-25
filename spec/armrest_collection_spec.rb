########################################################################
# armest_collection_spec.rb
#
# Test suite for the base Azure::Armrest::ArmrestCollection type.
########################################################################
require 'spec_helper'

describe "ArmrestCollection" do
  before do
    hash = {:x_ms_ratelimit_remaining_subscription_reads => '14999'}
    allow_any_instance_of(String).to receive(:headers).and_return(hash)
    allow(json_response).to receive(:status).and_return(200)
    allow(json_response).to receive(:body).and_return(json_response)
  end

  let(:json_response) do
    '{"value": [{"id": "xxx"}, {"id": "yyy"}], "nextLink":"https://example.com?skipToken=123"}'
  end

  let(:klass) { Azure::Armrest::VirtualMachine }
  let(:collection) { Azure::Armrest::ArmrestCollection.create_from_response(json_response, klass) }

  context "class" do
    it "is a kind of Array" do
      expect(collection).to be_a_kind_of(Array)
    end
  end

  context "accessors" do
    it "defines a response_headers accessor" do
      expect(collection).to respond_to(:response_headers)
    end

    it "defines a continuation_token accessor" do
      expect(collection).to respond_to(:continuation_token)
    end

    it "defines a skip_token alias" do
      expect(collection).to respond_to(:skip_token)
    end
  end

  context "response_headers" do
    it "returns the expected result for the response_headers method" do
      hash = {:x_ms_ratelimit_remaining_subscription_reads => '14999'}
      expect(collection.response_headers).to eql(hash)
    end
  end

  context "continuation_token" do
    it "returns the expected result for the continuation_token method" do
      expect(collection.continuation_token).to eql('123')
    end
  end

  context "collection object" do
    it "returns an array of the expected class type" do
      expect(collection.first).to be_kind_of(Azure::Armrest::VirtualMachine)
    end

    it "returns elements with expected values" do
      expect(collection.first.id).to eql('xxx')
      expect(collection.last.id).to eql('yyy')
    end
  end
end
