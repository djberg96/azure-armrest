#################################################################################
# insights_alert_service_spec.rb
#
# Test suite for the Azure::Armrest::Insights::AlertService class.
#################################################################################
require 'spec_helper'

describe "Insights::AlertService" do
  before { setup_params }
  let(:ias) { Azure::Armrest::Insights::AlertService.new(@conf) }

  context "inheritance" do
    it "is a subclass of ArmrestService" do
      expect(Azure::Armrest::Insights::AlertService.ancestors).to include(Azure::Armrest::ArmrestService)
    end
  end

  context "constructor" do
    it "returns a ias instance as expected" do
      expect(ias).to be_kind_of(Azure::Armrest::Insights::AlertService)
    end
  end

  context "instance methods" do
    it "defines a get method" do
      expect(ias).to respond_to(:get)
    end

    it "defines a list method" do
      expect(ias).to respond_to(:list)
    end

    it "defines a list_all method" do
      expect(ias).to respond_to(:list_all)
    end
  end
end
