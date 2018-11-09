########################################################################
# test_virtual_machine_service.rb
#
# Test suite for the Azure::Armrest::VirtualMachineService class.
########################################################################
require 'spec_helper'

describe "VirtualMachineService" do
  before { setup_params }
  let(:vms) { Azure::Armrest::VirtualMachineService.new(@conf) }
  let(:series_response) { @series_response }
  let(:singleton) { Azure::Armrest::VirtualMachineService }

  context "inheritance" do
    it "is a subclass of ArmrestService" do
      expect(Azure::Armrest::VirtualMachineService.ancestors).to include(Azure::Armrest::ArmrestService)
    end
  end

  context "constructor" do
    it "returns a VMS instance as expected" do
      expect(vms).to be_kind_of(Azure::Armrest::VirtualMachineService)
    end
  end

  context "accessors" do
    it "defines a base_url accessor" do
      expect(vms).to respond_to(:base_url)
      expect(vms).to respond_to(:base_url=)
    end
  end

  context "instance methods" do
    it "defines a capture method" do
      expect(vms).to respond_to(:capture)
    end

    it "defines a create method" do
      expect(vms).to respond_to(:create)
    end

    it "defines a deallocate method" do
      expect(vms).to respond_to(:deallocate)
    end

    it "defines a delete method" do
      expect(vms).to respond_to(:delete)
    end

    it "defines a generalize method" do
      expect(vms).to respond_to(:generalize)
    end

    it "defines a get method" do
      expect(vms).to respond_to(:get)
    end

    it "defines a series method" do
      expect(vms).to respond_to(:series)
    end

    it "creates a sizes alias for the series method" do
      expect(vms.method(:sizes)).to eq(vms.method(:series))
    end

    it "defines an restart method" do
      expect(vms).to respond_to(:restart)
    end

    it "defines a start method" do
      expect(vms).to respond_to(:start)
    end

    it "defines a stop method" do
      expect(vms).to respond_to(:stop)
    end

    it "defines a provider= method" do
      expect(vms).to respond_to(:provider=)
    end
  end

  context "list" do
    let(:response) { IO.read('spec/fixtures/vms.json') }
    let(:hash) { {:content_type=>"application/json; charset=utf-8"} }

    before do
      allow(vms).to receive(:rest_get).and_return(response)
      allow(response).to receive(:code).and_return(200)
      allow(response).to receive(:headers).and_return(hash)
    end

    it "defines a list method" do
      expect(vms).to respond_to(:list)
    end

    it "returns the expected results with default resource group" do
      expect(vms.list.size).to eql(3)
      expect(vms.list.first.name).to eql('foo1')
    end

    it "returns the expected results with explicit resource group" do
      expect(vms.list('foo1').size).to eql(3)
      expect(vms.list('foo1').first.name).to eql('foo1')
    end

    it "returns the expected results with skipped accessors" do
      expect(vms.list('foo1', true).size).to eql(3)
      expect(vms.list('foo1', true).first['name']).to eql('foo1')
      expect(vms.list('foo1', true).first.respond_to?(:name)).to eql(false)
    end
  end

  context "operations" do
    let(:response_headers) { IO.read('spec/fixtures/operations_response.json') }
    let(:response) { double(:response, :code => 202, :headers => response_headers) }

    before { allow(vms).to receive(:rest_post).and_return(response) }

    it "returns the expected ResponseHeaders object for a start power operation" do
      expect(vms.start('foo', 'bar')).to eql(Azure::Armrest::ResponseHeaders.new(response_headers))
      expect(vms.start('foo', 'bar').response_code).to eql(202)
    end

    it "returns the expected ResponseHeaders object for a stop power operation" do
      expect(vms.stop('foo', 'bar')).to eql(Azure::Armrest::ResponseHeaders.new(response_headers))
      expect(vms.stop('foo', 'bar').response_code).to eql(202)
    end

    it "returns the expected ResponseHeaders object for a restart power operation" do
      expect(vms.restart('foo', 'bar')).to eql(Azure::Armrest::ResponseHeaders.new(response_headers))
      expect(vms.restart('foo', 'bar').response_code).to eql(202)
    end
  end

  context "list_all" do
    let(:response) { IO.read('spec/fixtures/vms.json') }
    let(:hash) { {:content_type=>"application/json; charset=utf-8"} }

    before do
      allow(vms).to receive(:rest_get).and_return(response)
      allow(response).to receive(:code).and_return(200)
      allow(response).to receive(:headers).and_return(hash)
    end

    it "returns the expected results with no arguments" do
      expect(vms.list_all.size).to eql(3)
      expect(vms.list_all.first.name).to eql('foo1')
    end

    it "returns the expected results with a filter" do
      expect(vms.list_all(:location => 'centralus').size).to eql(1)
      expect(vms.list_all(:location => 'centralus').first.name).to eql('foo2')
    end

    it "returns the expected results if skip accessors is used" do
      expect(vms.list_all(:location => 'centralus', :skip_accessors_definition => true).size).to eql(1)
      expect(vms.list_all(:location => 'centralus', :skip_accessors_definition => true).first['name']).to eql('foo2')
    end

    it "raises an error if an invalid filter is selected" do
      expect { vms.list_all(:bogus => 1) }.to raise_error(NoMethodError)
    end
  end

  context "series" do
    it "returns the expected results for the series method" do
      allow_any_instance_of(singleton).to receive(:series).and_return(series_response)
      expect(vms.series).to eql(series_response)
      expect(vms.series.first.name).to eql('Standard_A0')
    end
  end

  context "private methods" do
    it "makes internal methods private" do
      expect(vms).not_to respond_to(:add_network_profile)
      expect(vms).not_to respond_to(:get_nic_profile)
      expect(vms).not_to respond_to(:add_power_status)
      expect(vms).not_to respond_to(:set_default_subscription)
      expect(vms).not_to respond_to(:build_url)
    end
  end
end
