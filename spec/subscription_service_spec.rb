########################################################################
# subscription_service_spec.rb
#
# Test suite for the Azure::Armrest::SubscriptionService class.
########################################################################
require 'spec_helper'

describe Azure::Armrest::SubscriptionService do
  before { setup_params }

  subject { described_class.new(@conf) }

  context "constructor" do
    it "returns an armrest service instance as expected" do
      expect(subject).to be_kind_of(Azure::Armrest::SubscriptionService)
    end
  end

  context "api-version" do
    it "defaults to the expected date" do
      expect(subject.api_version).to eql('2018-08-01')
    end
  end

  context "instance methods" do
    it "defines a get method" do
      expect(subject).to respond_to(:get)
    end

    it "defines a list method" do
      expect(subject).to respond_to(:list)
    end
  end
end
