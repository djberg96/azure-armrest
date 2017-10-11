########################################################################
# storage_account_spec.rb
#
# Test suite for the Azure::Armrest::StorageAccount json model class.
########################################################################
require 'spec_helper'

describe "StorageAccount" do
  before {
    @json = '{
      "name":"vhds",
      "properties":{"etag": "12345", "primaryEndpoints":{"blob": "123.blobs.microsoft.com"}}
    }'
  }

  let(:storage){ Azure::Armrest::StorageAccount.new(@json) }

  context "constructor" do
    it "returns a StorageAccount class as expected" do
      expect(storage).to be_kind_of(Azure::Armrest::StorageAccount)
    end
  end

  context "storage classes" do
    it "defines container and blob classes" do
      expect(Azure::Armrest::StorageAccount::Container)
      expect(Azure::Armrest::StorageAccount::ContainerProperty)
      expect(Azure::Armrest::StorageAccount::Blob)
      expect(Azure::Armrest::StorageAccount::BlobServiceProperty)
      expect(Azure::Armrest::StorageAccount::BlobServiceStat)
      expect(Azure::Armrest::StorageAccount::BlobMetadata)
      expect(Azure::Armrest::StorageAccount::Table)
      expect(Azure::Armrest::StorageAccount::TableData)
      expect(Azure::Armrest::StorageAccount::BlobSnapshot)
    end
  end

  context "accessors" do
    it "defines a storage_api_version accessor that defaults to 2016-05-31" do
      expect(storage).to respond_to(:storage_api_version)
      expect(storage.storage_api_version).to eq('2016-05-31')
    end

    it "defines a configuration accessor" do
      expect(storage).to respond_to(:configuration)
    end

    it "defines an access_key accessor that defaults to nil" do
      expect(storage).to respond_to(:access_key)
      expect(storage.access_key).to be_nil
    end
  end

  context "files and directories" do
    it "defines a create_directory method" do
      expect(storage).to respond_to(:create_directory)
    end

    it "defines a delete_directory method" do
      expect(storage).to respond_to(:delete_directory)
    end

    it "defines a directory_properties method" do
      expect(storage).to respond_to(:directory_properties)
    end

    it "defines a directory_metadata method" do
      expect(storage).to respond_to(:directory_metadata)
    end

    it "defines a files method" do
      expect(storage).to respond_to(:files)
    end

    it "returns the expected results for the files method" do
      xml = %Q{\xEF\xBB\xBF
        <?xml version=\"1.0\" encoding=\"utf-8\"?>
        <EnumerationResults ShareName=\"myshare\" DirectoryPath=\"\">
          <Entries>
            <File>
              <Name>bar.txt</Name>
              <Properties>
                <Content-Length>50</Content-Length>
              </Properties>
            </File>
            <File>
              <Name>foo.txt</Name>
              <Properties>
                <Content-Length>50</Content-Length>
              </Properties>
            </File>
          </Entries>
          <NextMarker />
        </EnumerationResults>
      }

      query = "comp=list&restype=directory"
      allow(storage).to receive(:file_response).with("abc", query, 'get', nil, 'foo').and_return(xml)
      allow(xml).to receive(:body).and_return(xml)

      expect(storage.files('foo', 'abc').size).to eql(2) 
      expect(storage.files('foo', 'abc').first).to be_kind_of(Azure::Armrest::StorageAccount::ShareFile)
      expect(storage.files('foo', 'abc').first.name).to eql('bar.txt')
      expect(storage.files('foo', 'abc').last.name).to eql('foo.txt')
    end

    it "defines a file_content method" do
      expect(storage).to respond_to(:file_content)
    end

    it "defines a file_properties method" do
      expect(storage).to respond_to(:file_properties)
    end

    it "defines a create_file method" do
      expect(storage).to respond_to(:create_file)
    end

    it "defines a delete_file method" do
      expect(storage).to respond_to(:delete_file)
    end

    it "defines a copy_file method" do
      expect(storage).to respond_to(:copy_file)
    end

    it "defines a add_file_content method" do
      expect(storage).to respond_to(:add_file_content)
    end
  end

  context "container methods" do
    let(:key) { 'xyz' }

    it "defines a containers method" do
      expect(storage).to respond_to(:containers)
    end

    it "returns the expected result for the containers method" do
      xml = %Q{\xEF\xBB\xBF
        <?xml version=\"1.0\" encoding=\"utf-8\"?>
        <EnumerationResults ServiceEndpoint=\"https://foo.blob.core.windows.net/\">
        <Containers>
          <Container>
            <Name>testcontainer</Name>
            <Properties>
              <Last-Modified>Fri, 30 Jun 2017 21:13:41 GMT</Last-Modified>
              <Etag>\"0x8D4BFFCE2070113\"</Etag>
              <LeaseStatus>unlocked</LeaseStatus>
              <LeaseState>available</LeaseState>
            </Properties>
          </Container>
          <Container>
            <Name>vhds</Name>
            <Properties>
              <Last-Modified>Thu, 10 Nov 2016 21:21:19 GMT</Last-Modified>
              <Etag>\"0x8D409AF835CC152\"</Etag>
              <LeaseStatus>unlocked</LeaseStatus>
              <LeaseState>available</LeaseState>
            </Properties>
          </Container>
        </Containers>
        <NextMarker />
        </EnumerationResults>
      }

      query = "comp=list"
      allow(storage).to receive(:blob_response).with(key, query).and_return(xml)
      allow(xml).to receive(:body).and_return(xml)

      containers = storage.containers(key)

      expect(containers.size).to eql(2)
      expect(containers.first).to be_kind_of(Azure::Armrest::StorageAccount::Container)
      expect(containers.first.name).to eql('testcontainer')
      expect(containers.last.name).to eql('vhds')
      expect(containers.first.properties.lease_status).to eql('unlocked')
    end

    it "defines a container_properties method" do
      expect(storage).to respond_to(:container_properties)
    end

    it "defines a container_acl method" do
      expect(storage).to respond_to(:container_acl)
    end

    context "on a single container" do
      let(:container_json) { {'Name' => 'box' } }
      let(:container)      { Azure::Armrest::StorageAccount::Container.new(container_json) }

      it "defines a name_from_hash method" do
        expect(container).to respond_to(:name_from_hash)
        expect(container.name_from_hash).to eq('box')
      end
    end
  end

  context "blob methods" do
    let(:container) { 'vhds' }
    let(:key) { 'xyz' }

    it "defines a blobs method" do
      expect(storage).to respond_to(:blobs)
    end

    it "returns the expected result for the blobs method" do
      xml = %Q{\xEF\xBB\xBF
        <?xml version=\"1.0\" encoding=\"utf-8\"?>
        <EnumerationResults ServiceEndpoint=\"https://foo.blob.core.windows.net/\" ContainerName=\"vhds\">
        <Blobs>
          <Blob>
            <Name>xyz.vhd</Name>
            <Properties>
              <Last-Modified>Thu, 10 Nov 2016 22:39:07 GMT</Last-Modified>
              <Etag>0x8D409BA6193F0C3</Etag>
              <Content-Length>31457280512</Content-Length>
              <Content-Type>application/octet-stream</Content-Type>
              <Content-Language />
              <Content-MD5>hKdOjkaup7sB/nzkWeuhWA==</Content-MD5>
              <x-ms-blob-sequence-number>1</x-ms-blob-sequence-number>
              <BlobType>PageBlob</BlobType>
              <LeaseStatus>unlocked</LeaseStatus>
              <LeaseState>available</LeaseState>
              <ServerEncrypted>false</ServerEncrypted>
            </Properties>
          </Blob>
          <Blob>
            <Name>foo</Name>
            <Properties>
              <Last-Modified>Thu, 06 Jul 2017 13:21:34 GMT</Last-Modified>
              <Etag>0x8D4C471ECC46568</Etag>
              <Content-Length>1024</Content-Length>
              <Content-Type>application/octet-stream</Content-Type>
              <Content-Language />
              <x-ms-blob-sequence-number>0</x-ms-blob-sequence-number>
              <BlobType>PageBlob</BlobType>
              <LeaseStatus>unlocked</LeaseStatus>
              <LeaseState>available</LeaseState>
              <ServerEncrypted>false</ServerEncrypted>
            </Properties>
          </Blob>
        </Blobs>
        <NextMarker />
        </EnumerationResults>
      }

      query = "restype=container&comp=list"
      allow(storage).to receive(:blob_response).with(key, query, container).and_return(xml)
      allow(xml).to receive(:body).and_return(xml)

      blobs = storage.blobs(container, key)

      expect(blobs.size).to eql(2)
      expect(blobs.first).to be_kind_of(Azure::Armrest::StorageAccount::Blob)
      expect(blobs.first.name).to eql('xyz.vhd')
      expect(blobs.last.name).to eql('foo')
      expect(blobs.first.properties.content_language).to eql(nil)
      expect(blobs.first.properties.x_ms_blob_sequence_number).to eql('1')
    end

    it "defines an all_blobs method" do
      expect(storage).to respond_to(:all_blobs)
    end

    it "allows an optional hash for the all_blobs method" do
      container_options = {:skip_accessors_definition => nil}
      allow(storage).to receive(:containers).with("abc", container_options).and_return([])
      expect(storage.all_blobs("abc", 5)).to eql([])
      expect(storage.all_blobs("abc", 5, :maxresults => 5)).to eql([])
    end

    it "defines a blob_properties method" do
      expect(storage).to respond_to(:blob_properties)
    end

    it "defines an update_blob_properties method" do
      expect(storage).to respond_to(:update_blob_properties)
    end

    it "defines a blob_service_properties method" do
      expect(storage).to respond_to(:blob_service_properties)
    end

    it "returns the expected result for the blob_service_properties" do
      xml = %Q{\xEF\xBB\xBF
        <?xml version=\"1.0\" encoding=\"utf-8\"?>
        <StorageServiceProperties>  
          <Logging>
            <Version>1.0</Version>
            <Read>false</Read>
            <Write>false</Write>
            <Delete>false</Delete>
            <RetentionPolicy>
              <Enabled>false</Enabled>
            </RetentionPolicy>
          </Logging>
          <HourMetrics>
            <Version>1.0</Version>
            <Enabled>true</Enabled>
            <IncludeAPIs>true</IncludeAPIs>
            <RetentionPolicy>
              <Enabled>true</Enabled>
              <Days>7</Days>
            </RetentionPolicy>
          </HourMetrics>
          <MinuteMetrics>
            <Version>1.0</Version>
            <Enabled>false</Enabled>
            <RetentionPolicy>
              <Enabled>false</Enabled>
            </RetentionPolicy>
          </MinuteMetrics>
          <Cors />
        </StorageServiceProperties>
      }

      query = "restype=service&comp=properties"
      allow(storage).to receive(:blob_response).with(key, query).and_return(xml)
      allow(xml).to receive(:body).and_return(xml)

      properties = storage.blob_service_properties(key)

      expect(properties).to be_kind_of(Azure::Armrest::StorageAccount::BlobServiceProperty)
      expect(properties.logging.version).to eql('1.0')
      expect(properties.hour_metrics.enabled).to eql('true')
      expect(properties.minute_metrics.retention_policy.enabled).to eql('false')
    end

    it "defines a blob_metadata method" do
      expect(storage).to respond_to(:blob_metadata)
    end

    it "defines a blob_service_stats method" do
      expect(storage).to respond_to(:blob_service_stats)
    end

    it "defines a copy_blob method" do
      expect(storage).to respond_to(:copy_blob)
    end

    it "defines a create_blob method" do
      expect(storage).to respond_to(:create_blob)
    end

    it "defines a delete_blob method" do
      expect(storage).to respond_to(:delete_blob)
    end

    it "defines a create_blob_snapshot method" do
      expect(storage).to respond_to(:create_blob_snapshot)
    end

    it "defines a get_blob_raw method" do
      expect(storage).to respond_to(:get_blob_raw)
    end

    context "on a single blob" do
      let(:blob_json) { {'Name' => 'Cousin Itt', 'Properties' => {'LeaseState' => 'on the floor' } } }
      let(:blob)      { Azure::Armrest::StorageAccount::Blob.new(blob_json) }

      it "defines a name_from_hash method" do
        expect(blob).to respond_to(:name_from_hash)
        expect(blob.name_from_hash).to eq('Cousin Itt')
      end

      it "defines a lease_state_from_hash method" do
        expect(blob).to respond_to(:lease_state_from_hash)
        expect(blob.lease_state_from_hash).to eq('on the floor')
      end
    end
  end

  context "table methods" do
    it "defines a tables method" do
      expect(storage).to respond_to(:tables)
    end

    it "defines a table_info method" do
      expect(storage).to respond_to(:table_info)
    end

    it "defines a table_data method" do
      expect(storage).to respond_to(:table_data)
    end
  end

  context "'from_hash' methods" do
    it "defines a name_from_hash method" do
      expect(storage).to respond_to(:name_from_hash)
      expect(storage.name_from_hash).to eq('vhds')
    end

    it "defines a blob_endpoint_from_hash method" do
      expect(storage).to respond_to(:blob_endpoint_from_hash)
      expect(storage.blob_endpoint_from_hash).to eq('123.blobs.microsoft.com')
    end
  end
end
