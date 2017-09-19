########################################################################
# storage_snapshot_service_spec.rb
#
# Test suite for the Azure::Armrest::Storage::SnapshotService class.
########################################################################
require 'spec_helper'

describe "Storage::SnapshotService" do
  before { setup_params }
  let(:snapshot) { Azure::Armrest::Storage::SnapshotService.new(@conf) }

  context "inheritance" do
    it "is a subclass of ArmrestService" do
      expect(Azure::Armrest::Storage::SnapshotService.ancestors).to include(Azure::Armrest::ArmrestService)
    end
  end

  context "constructor" do
    it "returns an SnapshotService instance as expected" do
      expect(snapshot).to be_kind_of(Azure::Armrest::Storage::SnapshotService)
    end
  end

  context "instance methods" do
    it "defines a create method" do
      expect(snapshot).to respond_to(:create)
    end

    it "defines an update alias" do
      expect(snapshot).to respond_to(:update)
      expect(snapshot.method(:update)).to eql(snapshot.method(:create))
    end

    it "defines a delete method" do
      expect(snapshot).to respond_to(:delete)
    end

    it "defines a get method" do
      expect(snapshot).to respond_to(:get)
    end

    it "defines a stop method" do
      expect(snapshot).to respond_to(:list)
    end

    it "defines a get_blob_raw method" do
      expect(snapshot).to respond_to(:get_blob_raw)
    end
  end

  context "get_blob_raw" do
    it "requires a snapshot name and resource group" do
      expect { snapshot.get_blob_raw }.to raise_error(ArgumentError)
      expect { snapshot.get_blob_raw('foo', nil) }.to raise_error(ArgumentError)
    end

    it "will raise an error if :entire_image is not specified and no range is specified" do
      headers = Azure::Armrest::ResponseHeaders.new(:headers => {:azure_asyncoperation => "https://www.foo.bar"})
      body    = Azure::Armrest::ResponseBody.new(:status => "Succeeded", :body => {:status => "Succeeded", :properties => {:output => {:access_sas => 'xyz'}}})

      allow(snapshot).to receive(:rest_post).and_return(headers)
      allow(snapshot).to receive(:rest_get).and_return(body)

      expect { snapshot.get_blob_raw('foo', 'bar') }.to raise_error(ArgumentError, /must specify byte range/)
    end

    it "will raise an error if azure_asyncoperation and location headers cannot be found" do
      headers = Azure::Armrest::ResponseHeaders.new(:code => 200, :body => '', :headers => {:location => nil, :response_code => 200})
      allow(snapshot).to receive(:rest_post).and_return(headers)
      expect { snapshot.get_blob_raw('foo', 'bar') }.to raise_error(Azure::Armrest::NotFoundException)
      expect { snapshot.get_blob_raw('foo', 'bar') }.to raise_error(Azure::Armrest::NotFoundException, /Unable to find an operations URL*/i)
    end
  end
end
