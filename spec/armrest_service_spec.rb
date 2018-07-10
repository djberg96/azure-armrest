########################################################################
# armrest_service_spec.rb
#
# Test suite for the Azure::Armrest::ArmrestService class.
########################################################################
require 'spec_helper'

describe Azure::Armrest::ArmrestService do
  before { setup_params }

  subject { described_class.new(@conf, 'servicename', 'provider', {}) }

  context "constructor" do
    it "returns an armrest service instance as expected" do
      expect(subject).to be_kind_of(Azure::Armrest::ArmrestService)
    end
  end

  context "instance methods" do
    it "defines a locations method" do
      expect(subject).to respond_to(:locations)
    end

    it "defines a list_locations method that does not accept any arguments" do
      expect(subject).to respond_to(:list_locations)
      expect { subject.list_locations('foo') }.to raise_error(ArgumentError)
    end

    it "defines a providers method" do
      expect(subject).to respond_to(:providers)
    end

    it "defines a provider_info method" do
      expect(subject).to respond_to(:provider_info)
    end

    it "defines a provider_info alias for get_provider" do
      expect(subject).to respond_to(:provider_info)
    end

    it "defines a resources method" do
      expect(subject).to respond_to(:resources)
    end

    it "defines a resource_groups method" do
      expect(subject).to respond_to(:resource_groups)
    end

    it "defines a subscriptions method" do
      expect(subject).to respond_to(:subscriptions)
    end

    it "defines a subscription_info method" do
      expect(subject).to respond_to(:subscription_info)
    end

    it "defines a tags method" do
      expect(subject).to respond_to(:tags)
    end

    it "defines a tenants method" do
      expect(subject).to respond_to(:tenants)
    end

    it "defines a poll method" do
      expect(subject).to respond_to(:poll)
    end

    it "defines a wait method" do
      expect(subject).to respond_to(:wait)
    end

    it "defines a valid_api_versions method" do
      expect(subject).to respond_to(:valid_api_versions)
    end
  end

  context "poll and wait" do
    let(:url) { "http://www.foo.bar" }

    it "polls a resource as expected with a plain string" do
      expect(subject).to receive(:poll).and_return("Succeeded")
      expect(subject.poll(url)).to eql("Succeeded")
    end

    it "polls a resource as expected with a ResponseHeader" do
      expect(subject).to receive(:poll).and_return("Succeeded")
      header = Azure::Armrest::ResponseHeaders.new(:azure_asyncoperation => url)
      expect(subject.poll(header)).to eql("Succeeded")
    end

    it "waits on a resource as expected with a plain string" do
      expect(subject).to receive(:wait).and_return("Succeeded")
      expect(subject.wait(url, 1)).to eql("Succeeded")
    end

    it "waits on a resource as expected with a ResponseHeader" do
      expect(subject).to receive(:wait).and_return("Succeeded")
      header = Azure::Armrest::ResponseHeaders.new(:azure_asyncoperation => url)
      expect(subject.wait(header, 1)).to eql("Succeeded")
    end

    it "waits on a resource with a timeout value as expected" do
      expect(subject).to receive(:wait).with(url, 5).and_return("Succeeded")
      expect(subject.wait(url, 5)).to eql("Succeeded")
    end
  end

  context "delegated methods" do
    it "delegates the providers method to Azure::Armrest::Configuration" do
      expect(subject).to respond_to(:providers)
      expect(subject.providers).to be_kind_of(Array)
      expect(subject.providers.first).to be_kind_of(Azure::Armrest::ResourceProvider)
    end
  end

  context "accessors" do
    it "defines a base_url accessor" do
      expect(subject).to respond_to(:base_url)
      expect(subject).to respond_to(:base_url=)
      resource_url = subject.configuration.environment.resource_url
      expect(subject.base_url).to eq(File.join(resource_url, 'subscriptions', 'abc-123-def-456'))
    end

    it "defines a service_name accessor" do
      expect(subject).to respond_to(:service_name)
      expect(subject).to respond_to(:service_name=)
      expect(subject.service_name).to eq('servicename')
    end
  end

  context "api exception handling" do
    it "converts exception from rest_get" do
      expect(RestClient::Request).to receive(:execute).and_raise(RestClient::Exception.new)
      expect { described_class.send(:rest_get, :url => '') }.to raise_error(Azure::Armrest::ApiException)
    end

    it "converts exception from rest_put" do
      expect(RestClient::Request).to receive(:execute).and_raise(RestClient::Exception.new)
      expect { described_class.send(:rest_put, :url => '', :body => '') }.to raise_error(Azure::Armrest::ApiException)
    end

    it "converts exception from rest_post" do
      expect(RestClient::Request).to receive(:execute).and_raise(RestClient::Exception.new)
      expect { described_class.send(:rest_post, :url => '', :body => '') }.to raise_error(Azure::Armrest::ApiException)
    end

    it "converts exception from rest_patch" do
      expect(RestClient::Request).to receive(:execute).and_raise(RestClient::Exception.new)
      expect { described_class.send(:rest_patch, :url => '', :body => '') }.to raise_error(Azure::Armrest::ApiException)
    end

    it "converts exception from rest_delete" do
      expect(RestClient::Request).to receive(:execute).and_raise(RestClient::Exception.new)
      expect { described_class.send(:rest_delete, :url => '') }.to raise_error(Azure::Armrest::ApiException)
    end
  end
end
