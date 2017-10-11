require 'azure-signature'
require 'active_support/core_ext/hash/conversions'
require 'ox'

module Azure
  module Armrest
    class StorageAccount < BaseModel
      attr_from_hash :name          => :name,
                     :blob_endpoint => [:properties, :primaryEndpoints, :blob]

      # Classes used to wrap container and blob information.
      class Container < BaseModel
        attr_from_hash :name => :Name
      end
      class ContainerProperty < BaseModel; end
      class Blob < BaseModel
        attr_from_hash :name        => :Name,
                       :lease_state => [:Properties, :LeaseState]
      end
      class BlobProperty < BaseModel; end
      class PrivateImage < BlobProperty; end
      class BlobServiceProperty < BaseModel; end
      class BlobServiceStat < BaseModel; end
      class BlobMetadata < BaseModel; end
      class BlobSnapshot < Blob; end

      # Classes used to wrap table information
      class Table < BaseModel; end
      class TableData < BaseModel; end

      # Classes used to wrap file shares
      class ShareDirectory < BaseModel; end
      class ShareFile < BaseModel; end

      # The version string used in headers sent as part any internal http
      # request. The default is 2016-05-31.
      attr_accessor :storage_api_version

      # The default access key used when creating a signature for internal http requests.
      attr_accessor :access_key

      # The parent configuration object
      attr_accessor :configuration

      def initialize(json, skip_accessors_definition = false)
        super
        @storage_api_version = '2016-05-31'
      end

      # Returns a list of tables for the given storage account +key+. Note
      # that full metadata is returned.
      #
      def tables(key = access_key)
        raise ArgumentError, "No access key specified" unless key
        response = table_response(key, nil, "Tables")
        JSON.parse(response.body)['value'].map { |t| Table.new(t) }
      end

      # Return information about a single table for the given storage
      # account +key+. If you are looking for the entities within the
      # table, use the table_data method instead.
      #
      def table_info(table, key = access_key)
        raise ArgumentError, "No access key specified" unless key
        response = table_response(key, nil, "Tables('#{table}')")
        Table.new(response.body)
      end

      # Returns a list of TableData objects for the given table +name+ using
      # account +key+. The exact nature of the TableData object depends on the
      # type of table that it is.
      #
      # You may specify :filter, :select or :top as options to restrict your
      # result set.
      #
      # By default you will receive a maximum of 1000 records. If you wish to
      # receive more records, you will need to use the continuation token. You
      # may also set the :all option to true if you want all records, though we
      # recommend using a filter as well if you use that option as there can
      # be thousands of results.
      #
      # You may also specify a :NextRowKey, :NextPartitionKey or :NextTableset
      # explicitly for paging. Normally you would just pass the
      # collection's continuation_token, however. See below for an example.
      #
      # When using continuation tokens, you should retain your original
      # filtering as well, or you may get unexpected results.
      #
      # Examples:
      #
      #   # Get the first 10 rows of data from the last 3 days
      #   date = (Time.now - (86400 * 3)).iso8601
      #   my_filter = "timestamp ge datetime'#{date}'"
      #   options = {:top => 10, :filter => my_filter}
      #
      #   results = storage_account.table_data(table, key, options)
      #
      #   # Now get the next 10 records
      #   if results.continuation_token
      #     options[:continuation_token] = results.continuation_token
      #     more_results = storage_account.table_data(table, key, options)
      #   end
      #
      def table_data(name, key = access_key, options = {})
        raise ArgumentError, "No access key specified" unless key

        query = build_query(options)
        response = table_response(key, query, name)

        klass = Azure::Armrest::StorageAccount::TableData
        data  = Azure::Armrest::ArmrestCollection.create_from_response(response, klass)

        # Continuation tokens are parsed differently for storage
        data.continuation_token = parse_continuation_tokens(response)

        if options[:all] && data.continuation_token
          options[:continuation_token] = data.continuation_token
          data.push(*table_data(name, key, options))
          data.continuation_token = nil # Clear when finished
        end

        data
      end

      ### Files and Directories

      # Create a new directory under the specified +share+ or parent directory.
      #
      # The only supported option at this time is a "timeout" option.
      #
      def create_directory(share, directory, key = access_key, options = {})
        raise ArgumentError, "No access key specified" unless key

        query = {:restype => 'directory'}.merge(options).to_query

        response = file_response(key, query, 'put', '', File.join(share, directory))

        Azure::Armrest::ResponseHeaders.new(response.headers).tap do |rh|
          rh.response_code = response.code
        end
      end

      # Delete the specified +share+ or parent directory.
      #
      # The only supported option at this time is a "timeout" option.
      #
      def delete_directory(share, directory, key = access_key, options = {})
        raise ArgumentError, "No access key specified" unless key

        query = {:restype => 'directory'}.merge(options).to_query

        response = file_response(key, query, 'delete', '', File.join(share, directory))

        Azure::Armrest::ResponseHeaders.new(response.headers).tap do |rh|
          rh.response_code = response.code
        end
      end

      # Get properties for the specified +share+ or parent directory.
      #
      # The only supported option at this time is a "timeout" option.
      #
      def directory_properties(share, directory, key = access_key, options = {})
        raise ArgumentError, "No access key specified" unless key

        query = {:restype => 'directory'}.merge(options).to_query

        response = file_response(key, query, 'get', '', File.join(share, directory))

        ShareDirectory.new(response.headers)
      end

      # Get metadata for the specified +share+ or parent directory.
      #
      # The only supported option at this time is a "timeout" option.
      #
      def directory_metadata(share, directory, key = access_key, options = {})
        raise ArgumentError, "No access key specified" unless key

        query = {:restype => 'directory', :comp => 'metadata'}.merge(options).to_query

        response = file_response(key, query, 'head', '', File.join(share, directory))

        ShareDirectory.new(response.headers)
      end

      # Returns a list of files for the specified file-share. You may also
      # optionally specify a +directory+ in "share/directory" format.
      #
      # You may specify multiple +options+ to limit the result set. The
      # possible options are:
      #
      # * prefix
      # * marker
      # * maxresults
      # * timeout
      #
      def files(share, key = access_key, options = {})
        raise ArgumentError, "No access key specified" unless key

        query = {:restype => 'directory', :comp => 'list'}.merge(options).to_query

        response = file_response(key, query, 'get', nil, share)

        doc = Ox.parse(response.body)
        results = []

        doc.EnumerationResults.Entries.each do |element|
          hash = Hash.from_xml(Ox.to_xml(element))
          results << ShareDirectory.new(hash['Directory']) if hash['Directory']
          results << ShareFile.new(hash['File']) if hash['File']
        end

        results.concat(next_marker_results(doc, :files, key, options))

        results
      end

      # Returns the raw contents of the specified file.
      #
      # The only supported option at this time is a "timeout" option.
      #
      def file_content(share, file, key = access_key, options = {})
        raise ArgumentError, "No access key specified" unless key

        query = options.to_query

        response = file_response(key, query, 'get', '', File.join(share, file))
        response.body
      end

      # Returns the raw contents of the specified file.
      #
      # The only supported option at this time is a "timeout" option.
      #
      def file_properties(share, file, key = access_key, options = {})
        raise ArgumentError, "No access key specified" unless key

        query = options.to_query

        response = file_response(key, query, 'head', '', File.join(share, file))

        Azure::Armrest::ResponseHeaders.new(response.headers).tap do |rh|
          rh.response_code = response.code
        end
      end

      # Create the specified share file. You may specify any of the following
      # options:
      #
      # * cache_control
      # * content_disposition
      # * content_length (default: 0)
      # * content_encoding
      # * content_language
      # * content_md5
      # * content_type (default: application/octet-stream)
      # * meta_name
      # * timeout
      # * version
      #
      # Note that this does not set the content of the file, it only creates
      # in the file share.
      #
      def create_file(share, file, key = access_key, options = {})
        raise ArgumentError, "No access key specified" unless key

        timeout = options.delete(:timeout) # Part of request

        url = File.join(properties.primary_endpoints.file, share, file)
        url += "?timeout=#{timeout}" if timeout

        hash = options.transform_keys.each { |okey| 'x-ms-' + okey.to_s.tr('_', '-') }

        hash['verb'] = 'PUT'

        # Mandatory and/or sane defaults
        hash['x-ms-type'] = 'file'
        hash['x-ms-content-length'] ||= 0
        hash['x-ms-content-type'] ||= 'application/octet-stream'

        headers = build_headers(url, key, :file, hash)

        response = ArmrestService.send(
          :rest_put,
          :url         => url,
          :payload     => '',
          :headers     => headers,
          :proxy       => configuration.proxy,
          :ssl_version => configuration.ssl_version,
          :ssl_verify  => configuration.ssl_verify
        )

        Azure::Armrest::ResponseHeaders.new(response.headers).tap do |rh|
          rh.response_code = response.code
        end
      end

      # Delete the specified share file.
      #
      # The only supported option at this time is a "timeout" option.
      #
      def delete_file(share, file, key = access_key, options = {})
        raise ArgumentError, "No access key specified" unless key

        query = options.to_query

        response = file_response(key, query, 'delete', '', File.join(share, file))

        Azure::Armrest::ResponseHeaders.new(response.headers).tap do |rh|
          rh.response_code = response.code
        end
      end

      # Copy a +src_file+ to a destination +dst_file+ within the same storage account.
      #
      def copy_file(src_container, src_file, dst_container = src_container, dst_file = nil, key = access_key)
        raise ArgumentError, "No access key specified" unless key

        dst_file ||= File.basename(src_blob)

        dst_url = File.join(properties.primary_endpoints.file, dst_container, dst_file)
        src_url = File.join(properties.primary_endpoints.file, src_container, src_file)

        options = {'x-ms-copy-source' => src_url, :verb => 'PUT'}

        headers = build_headers(dst_url, key, :file, options)

        response = ArmrestService.send(
          :rest_put,
          :url         => dst_url,
          :payload     => '',
          :headers     => headers,
          :proxy       => configuration.proxy,
          :ssl_version => configuration.ssl_version,
          :ssl_verify  => configuration.ssl_verify
        )

        Azure::Armrest::ResponseHeaders.new(response.headers).tap do |rh|
          rh.response_code = response.code
        end
      end

      # Add content to +file+ on +share+. The +options+ hash supports
      # three options, :content, :timeout and :write.
      #
      # The :content option is just a string, i.e. the content you want
      # to add to the file. Azure allows you to add a maximum of 4mb worth
      # of content per request.
      #
      # The :timeout option is nil by default. The :write option defaults to
      # 'update'. If you want to clear a file, set it to 'clear'.
      #
      def add_file_content(share, file, key = access_key, options = {})
        raise ArgumentError, "No access key specified" unless key

        timeout = options.delete(:timeout)
        content = options.delete(:content)

        url = File.join(properties.primary_endpoints.file, share, file) + "?comp=range"
        url += "&timeout=#{timeout}" if timeout

        hash = options.transform_keys.each { |okey| 'x-ms-' + okey.to_s.tr('_', '-') }

        hash['verb'] = 'PUT'
        hash['x-ms-write'] ||= 'update'

        if hash['x-ms-write'] == 'clear'
          hash['content-length'] = 0
          hash['x-ms-range'] = "bytes=0-"
        else
          range = 0..(content.size - 1)
          hash['content-length'] = content.size
          hash['x-ms-range'] = "bytes=#{range.min}-#{range.max}"
        end

        headers = build_headers(url, key, :file, hash)

        response = ArmrestService.send(
          :rest_put,
          :url         => url,
          :payload     => content,
          :headers     => headers,
          :proxy       => configuration.proxy,
          :ssl_version => configuration.ssl_version,
          :ssl_verify  => configuration.ssl_verify
        )

        Azure::Armrest::ResponseHeaders.new(response.headers).tap do |rh|
          rh.response_code = response.code
        end
      end

      ### Containers

      # Return a list of container names for the given storage account +key+.
      # If no key is provided, it is assumed that the StorageAccount object
      # includes the access_key property.
      #
      # # The following options are supported:
      #
      # * prefix
      # * delimiter
      # * maxresults
      # * include
      # * timeout
      #
      # By default Azure uses a value of 5000 for :maxresults.
      #
      # If the :include option is specified, it should contain an array of
      # one element: metadata. More options may be added by Microsoft
      # at a later date.
      #
      # Example:
      #
      #   sas  = Azure::Armrest::StorageAccountService.new(conf)
      #   key  = sas.list_account_keys['key1']
      #   acct = sas.get('your_storage_account', 'your_resource_group')
      #
      #   p acct.containers(key)
      #   p acct.containers(key, :include => ['metadata'])
      #   p acct.containers(key, :maxresults => 1)
      #
      # In cases where a NextMarker element is found in the original response,
      # another call will automatically be made with the marker value included
      # in the URL so that you don't have to perform such a step manually.
      #
      def containers(key = access_key, options = {})
        raise ArgumentError, "No access key specified" unless key

        query = "comp=list"
        skip_defs = options[:skip_accessors_definition]

        options.each do |okey, ovalue|
          unless okey == :skip_accessors_definition
            query += "&#{okey}=#{[ovalue].flatten.join(',')}"
          end
        end

        response = blob_response(key, query)

        doc = Ox.parse(response.body)
        results = []

        doc.EnumerationResults.Containers.each do |container|
          hash = Hash.from_xml(Ox.to_xml(container))
          results << Container.new(hash['Container'], skip_defs)
        end

        results.concat(next_marker_results(doc, :containers, key, options))
      end

      # Returns the properties for the given container +name+ using account +key+.
      #
      def container_properties(name, key = access_key)
        raise ArgumentError, "No access key specified" unless key

        response = blob_response(key, "restype=container", name)

        ContainerProperty.new(response.headers)
      end

      # Returns the properties for the given container +name+ using account +key+.
      #
      # If the returned object does not contain x_ms_blob_public_access then
      # the container is private to the account owner. You can also use the
      # :private? method to determine if the account is public or private.
      #
      def container_acl(name, key = access_key)
        raise ArgumentError, "No access key specified" unless key

        response = blob_response(key, "restype=container&comp=acl", name)
        response.headers[:private?] = response.headers.include?(:x_ms_blob_public_access) ? false : true

        ContainerProperty.new(response.headers)
      end

      # Return the blob properties for the given +blob+ found in +container+. You may
      # optionally provide a date to get information for a snapshot.
      #
      def blob_properties(container, blob, key = access_key, options = {})
        raise ArgumentError, "No access key specified" unless key

        url = File.join(blob_endpoint_from_hash, container, blob)
        url += "?snapshot=" + options[:date] if options[:date]

        headers = build_headers(url, key, :blob, :verb => 'HEAD')

        response = ArmrestService.send(
          :rest_head,
          :url         => url,
          :headers     => headers,
          :proxy       => configuration.proxy,
          :ssl_version => configuration.ssl_version,
          :ssl_verify  => configuration.ssl_verify
        )

        BlobProperty.new(response.headers.merge(:container => container, :name => blob), options[:skip_accessors_definition])
      end

      # Update the given +blob+ in +container+ with the provided options. The
      # possible options are:
      #
      # cache_control
      # content_disposition
      # content_encoding
      # content_language
      # content_length
      # content_md5
      # content_type
      # lease_id
      # version
      #
      # The content_length option is only value for page blobs, and is used
      # to resize the blob.
      #
      def update_blob_properties(container, blob, key = access_key, options = {})
        raise ArgumentError, "No access key specified" unless key

        url = File.join(properties.primary_endpoints.blob, container, blob) + "?comp=properties"

        hash = options.transform_keys { |okey| "x-ms-blob-" + okey.to_s.tr('_', '-') }

        hash['verb'] = 'PUT'

        headers = build_headers(url, key, :blob, hash)

        response = ArmrestService.send(
          :rest_put,
          :url         => url,
          :headers     => headers,
          :proxy       => configuration.proxy,
          :ssl_version => configuration.ssl_version,
          :ssl_verify  => configuration.ssl_verify
        )

        BlobProperty.new(response.headers.merge(:container => container, :name => blob))
      end

      # Return a list of blobs for the given +container+ using the given +key+
      # or the access_key property of the StorageAccount object.
      #
      # The following options are supported:
      #
      # * prefix
      # * delimiter
      # * maxresults
      # * include
      # * timeout
      #
      # By default Azure uses a value of 5000 for :maxresults.
      #
      # If the :include option is specified, it should contain an array of
      # one or more of the following values: snapshots, metadata, copy or
      # uncommittedblobs.
      #
      # Example:
      #
      #   sas  = Azure::Armrest::StorageAccountService.new(conf)
      #   key  = sas.list_account_keys['key1']
      #   acct = sas.get('your_storage_account', 'your_resource_group')
      #
      #   p acct.blobs('vhds', key)
      #   p acct.blobs('vhds', key, :timeout => 30)
      #   p acct.blobs('vhds', key, :include => ['snapshots', 'metadata'])
      #
      # In cases where a NextMarker element is found in the original response,
      # another call will automatically be made with the marker value included
      # in the URL so that you don't have to perform such a step manually.
      #
      def blobs(container, key = access_key, options = {})
        raise ArgumentError, "No access key specified" unless key

        query = "restype=container&comp=list"
        skip_defs = options[:skip_accessors_definition]

        options.each do |okey, ovalue|
          unless okey == :skip_accessors_definition
            query += "&#{okey}=#{[ovalue].flatten.join(',')}"
          end
        end

        response = blob_response(key, query, container)

        doc = Ox.parse(response.body)
        results = []

        doc.EnumerationResults.Blobs.each do |blob|
          hash = Hash.from_xml(Ox.to_xml(blob))['Blob']
          hash[:container] = container
          object = hash.key?('Snapshot') ? BlobSnapshot.new(hash, skip_defs) : Blob.new(hash, skip_defs)
          results << object
        end

        results.concat(next_marker_results(doc, :blobs, container, key, options))
      end

      # Returns an array of all blobs for all containers. The +options+ hash
      # may contain the same arguments that a call to StorageAccount#blobs
      # would accept.
      #
      def all_blobs(key = access_key, max_threads = 10, options = {})
        raise ArgumentError, "No access key specified" unless key

        array = []
        mutex = Mutex.new
        opts = {
          :skip_accessors_definition => options[:skip_accessors_definition]
        }

        Parallel.each(containers(key, opts), :in_threads => max_threads) do |container|
          begin
            mutex.synchronize { array.concat(blobs(container.name_from_hash, key, options)) }
          rescue Errno::ECONNREFUSED, Azure::Armrest::TimeoutException => err
            msg = "Unable to gather blob information for #{container.name}: #{err}"
            Azure::Armrest::Configuration.log.try(:log, Logger::WARN, msg)
            next
          end
        end

        array
      end

      # Returns the blob service properties for the current storage account.
      #
      def blob_service_properties(key = access_key)
        raise ArgumentError, "No access key specified" unless key

        response = blob_response(key, "restype=service&comp=properties")

        element = Ox.parse(response.body).StorageServiceProperties
        hash = Hash.from_xml(Ox.to_xml(element))
        BlobServiceProperty.new(hash['StorageServiceProperties'])
      end

      # Return metadata for the given +blob+ within +container+. You may
      # specify a +date+ to retrieve metadata for a specific snapshot.
      #
      def blob_metadata(container, blob, key = access_key, options = {})
        raise ArgumentError, "No access key specified" unless key

        query = "comp=metadata"
        query << "&snapshot=" + options[:date] if options[:date]

        response = blob_response(key, query, container, blob)

        BlobMetadata.new(response.headers)
      end

      # Retrieves statistics related to replication for the Blob service. Only
      # available on the secondary location endpoint when read-access
      # geo-redundant replication is enabled for the storage account.
      #
      def blob_service_stats(key = access_key)
        raise ArgumentError, "No access key specified" unless key

        response = blob_response(key, "restype=service&comp=stats")

        element = Ox.parse(response.body).StorageServiceStats
        hash = Hash.from_xml(Ox.to_xml(element))
        BlobServiceStat.new(hash['StorageServiceStats'])
      end

      # Copy the blob from the source container/blob to the destination container/blob.
      # If no destination blob name is provided, it will use the same name as the source.
      #
      # Example:
      #
      #   source = "Microsoft.Compute/Images/your_container/your-img-osDisk.123xyz.vhd"
      #   storage_acct.copy_blob('system', source, 'vhds', nil, your_key)
      #
      def copy_blob(src_container, src_blob, dst_container, dst_blob = nil, key = access_key)
        raise ArgumentError, "No access key specified" unless key

        dst_blob ||= File.basename(src_blob)

        dst_url = File.join(properties.primary_endpoints.blob, dst_container, dst_blob)
        src_url = File.join(properties.primary_endpoints.blob, src_container, src_blob)

        options = {'x-ms-copy-source' => src_url, 'if-none-match' => '*', :verb => 'PUT'}

        headers = build_headers(dst_url, key, :blob, options)

        response = ArmrestService.send(
          :rest_put,
          :url         => dst_url,
          :payload     => '',
          :headers     => headers,
          :proxy       => configuration.proxy,
          :ssl_version => configuration.ssl_version,
          :ssl_verify  => configuration.ssl_verify
        )

        blob = blob_properties(dst_container, dst_blob, key)
        blob.response_headers = Azure::Armrest::ResponseHeaders.new(response.headers)
        blob.response_code = response.code

        blob
      end

      # Delete the given +blob+ found in +container+. Pass a :date option
      # if you wish to delete a snapshot.
      #
      def delete_blob(container, blob, key = access_key, options = {})
        raise ArgumentError, "No access key specified" unless key

        url = File.join(properties.primary_endpoints.blob, container, blob)
        url += "?snapshot=" + options[:date] if options[:date]

        headers = build_headers(url, key, :blob, :verb => 'DELETE')

        response = ArmrestService.send(
          :rest_delete,
          :url         => url,
          :headers     => headers,
          :proxy       => configuration.proxy,
          :ssl_version => configuration.ssl_version,
          :ssl_verify  => configuration.ssl_verify
        )

        headers = Azure::Armrest::ResponseHeaders.new(response.headers)
        headers.response_code = response.code

        headers
      end

      # Create new blob for a container.
      #
      # The options parameter is a hash that contains information used
      # when creating the blob:
      #
      # * type - "BlockBlob", "PageBlob" or "AppendBlob". Mandatory.
      #
      # * content_disposition
      # * content_encoding
      # * content_language
      # * content_md5
      # * content_type
      # * cache_control
      # * lease_id
      # * payload (block blobs only)
      # * sequence_number (page blobs only)
      # * timeout (part of the request)
      #
      # Returns a ResponseHeaders object since this method is asynchronous.
      #
      def create_blob(container, blob, key = access_key, options = {})
        raise ArgumentError, "No access key specified" unless key

        timeout = options.delete(:timeout)
        payload = options.delete(:payload) || ''

        url = File.join(properties.primary_endpoints.blob, container, blob)
        url += "&timeout=#{timeout}" if timeout

        hash = options.transform_keys do |okey|
          if okey.to_s =~ /^if/i
            okey.to_s.tr('_', '-')
          elsif %w[date meta_name lease_id version].include?(okey.to_s)
            'x-ms-' + okey.to_s.tr('_', '-')
          else
            'x-ms-blob-' + okey.to_s.tr('_', '-')
          end
        end

        unless hash['x-ms-blob-type']
          raise ArgumentError, "The :type option must be specified"
        end

        hash['x-ms-date'] ||= Time.now.httpdate
        hash['x-ms-version'] ||= storage_api_version
        hash['verb'] = 'PUT'

        # Content length must be 0 (blank) for Page or Append blobs
        if %w[pageblob appendblob].include?(hash['x-ms-blob-type'].downcase)
          hash['content-length'] = ''
        else
          hash['content-length'] ||= hash['x-ms-blob-content-length']
        end

        # Override the default empty string
        hash['content-type'] ||= hash['x-ms-blob-content-type'] || 'application/octet-stream'

        headers = build_headers(url, key, :blob, hash)

        response = ArmrestService.send(
          :rest_put,
          :url         => url,
          :payload     => payload,
          :headers     => headers,
          :proxy       => configuration.proxy,
          :ssl_version => configuration.ssl_version,
          :ssl_verify  => configuration.ssl_verify
        )

        resp_headers = Azure::Armrest::ResponseHeaders.new(response.headers)
        resp_headers.response_code = response.code

        resp_headers
      end

      # Create a read-only snapshot of a blob.
      #
      # Possible options are:
      #
      # * meta_name
      # * lease_id
      # * client_request_id
      # * if_modified_since
      # * if_unmodified_since
      # * if_match
      # * if_none_match
      # * timeout
      #
      # Returns a ResponseHeaders object since this is an asynchronous method.
      #
      def create_blob_snapshot(container, blob, key = access_key, options = {})
        raise ArgumentError, "No access key specified" unless key

        timeout = options.delete(:timeout) # Part of request

        url = File.join(properties.primary_endpoints.blob, container, blob) + "?comp=snapshot"
        url += "&timeout=#{timeout}" if timeout

        hash = options.transform_keys do |okey|
          if okey.to_s =~ /^if/i
            okey.to_s.tr('_', '-')
          else
            'x-ms-blob-' + okey.to_s.tr('_', '-')
          end
        end

        hash['verb'] = 'PUT'

        headers = build_headers(url, key, :blob, hash)

        response = ArmrestService.send(
          :rest_put,
          :url         => url,
          :payload     => '',
          :headers     => headers,
          :proxy       => configuration.proxy,
          :ssl_version => configuration.ssl_version,
          :ssl_verify  => configuration.ssl_verify
        )

        headers = Azure::Armrest::ResponseHeaders.new(response.headers)
        headers.response_code = response.code

        headers
      end

      # Get the contents of the given +blob+ found in +container+ using the
      # given +options+. This is a low level method to read a range of bytes
      # from the blob directly. The possible options are:
      #
      # * range        - A range of bytes to collect.
      # * start_byte   - The starting byte for collection.
      # * end_byte     - The end byte for collection. Use this or :length with :start_byte.
      # * length       - The number of bytes to collect starting at +start_byte+.
      # * entire_image - Read all bytes for the blob.
      # * md5          - If true, the response headers will include MD5 checksum information.
      # * date         - Get the blob snapshot for the given date.
      #
      # If you do not specify a :range or :start_byte, then an error will be
      # raised unless you explicitly set the :entire_image option to true.
      # However, that is not recommended because the blobs can be huge.
      #
      # Unlike other methods, this method returns a raw response object rather
      # than a wrapper model. Get the information you need using:
      #
      # * response.body    - blob data.
      # * response.headers - blob metadata.
      #
      # Example:
      #
      #   ret = @storage_acct.get_blob(@container, @blob, key, :start_byte => start_byte, :length => length)
      #   content_md5  = ret.headers[:content_md5].unpack("m0").first.unpack("H*").first
      #   returned_md5 = Digest::MD5.hexdigest(ret.body)
      #   raise "Checksum error: #{range_str}, blob: #{@container}/#{@blob}" unless content_md5 == returned_md5
      #   return ret.body
      #
      def get_blob_raw(container, blob, key = access_key, options = {})
        raise ArgumentError, "No access key specified" unless key

        url = File.join(properties.primary_endpoints.blob, container, blob)
        url += "?snapshot=" + options[:date] if options[:date]

        additional_headers = {
          'verb' => 'GET'
        }

        range_str = nil
        if options[:range]
          range_str = "bytes=#{options[:range].min}-#{options[:range].max}"
        elsif options[:start_byte]
          range_str = "bytes=#{options[:start_byte]}-"
          if options[:end_byte]
            range_str << options[:end_byte].to_s
          elsif options[:length]
            range_str << (options[:start_byte] + options[:length] - 1).to_s
          end
        end

        if range_str
          additional_headers['x-ms-range'] = range_str
          additional_headers['x-ms-range-get-content-md5'] = true if options[:md5]
        else
          raise ArgumentError, "must specify byte range or entire_image flag" unless options[:entire_image]
        end

        headers = build_headers(url, key, :blob, additional_headers)

        ArmrestService.send(
          :rest_get,
          :url         => url,
          :headers     => headers,
          :proxy       => configuration.proxy,
          :ssl_version => configuration.ssl_version,
          :ssl_verify  => configuration.ssl_verify
        )
      end

      private

      # Build a query string from a hash of options.
      #
      def build_query(options)
        array = []

        options.each do |key, value|
          next if key == :all
          if [:filter, :select, :top].include?(key)
            array << "$#{key}=#{value}" if value
          elsif key == :continuation_token
            value.each { |k, token| array << "#{k}=#{token}" if token }
          else
            array << "#{key}=#{value}" if value
          end
        end

        array.join('&')
      end

      # Get the continuation tokens from the response headers for paging results.
      #
      def parse_continuation_tokens(response)
        headers = response.headers

        token = {
          :NextPartitionKey => headers[:x_ms_continuation_nextpartitionkey],
          :NextRowKey       => headers[:x_ms_continuation_nextrowkey],
          :NextTableName    => headers[:x_ms_continuation_nexttablename]
        }

        # If there are no continuation values at all, then return nil
        token = nil if token.all? { |_key, value| value.nil? }

        token
      end

      # Using the blob primary endpoint as a base, join any arguments to the
      # the url and submit an http request.
      #
      def blob_response(key, query, *args)
        url = File.join(blob_endpoint_from_hash, *args) + "?#{query}"
        headers = build_headers(url, key, 'blob')

        ArmrestService.send(
          :rest_get,
          :url         => url,
          :headers     => headers,
          :proxy       => configuration.proxy,
          :ssl_version => configuration.ssl_version,
          :ssl_verify  => configuration.ssl_verify
        )
      end

      # Using the file primary endpoint as a base, join any arguments to the
      # the url and submit an http request.
      #
      def file_response(key, query, request_type = 'get', payload = '', *args)
        url = File.join(properties.primary_endpoints.file, *args)
        url += "?#{query}" if query && !query.empty?
        request_method = "rest_#{request_type}".to_sym

        headers = build_headers(url, key, :file, :verb => request_type.to_s.upcase)

        params = {
          :url         => url,
          :headers     => headers,
          :proxy       => configuration.proxy,
          :ssl_version => configuration.ssl_version,
          :ssl_verify  => configuration.ssl_verify
        }

        if %w[put post].include?(request_type.to_s.downcase)
          params[:payload] = payload
        end

        ArmrestService.send(request_method, params)
      end

      # Using the blob primary endpoint as a base, join any arguments to the
      # the url and submit an http request.
      def table_response(key, query = nil, *args)
        url = File.join(properties.primary_endpoints.table, *args)

        headers = build_headers(url, key, 'table')
        headers['Accept'] = 'application/json;odata=fullmetadata'

        # Must happen after headers are built
        unless query.nil? || query.empty?
          url << "?#{query}"
        end

        ArmrestService.send(
          :rest_get,
          :url         => url,
          :headers     => headers,
          :proxy       => configuration.proxy,
          :ssl_version => configuration.ssl_version,
          :ssl_verify  => configuration.ssl_verify
        )
      end

      # Set the headers needed, including the Authorization header.
      #
      def build_headers(url, key, sig_type = nil, additional_headers = {})
        sig = Signature.new(url, key)
        sig_type ||= 'blob'

        # RestClient will set the Content-Type to application/x-www-form-urlencoded.
        # We must override this setting or the request will fail in some cases.

        content_type = additional_headers['content-type'] || ''

        headers = {
          'content-type' => content_type,
          'x-ms-date'    => Time.now.httpdate,
          'x-ms-version' => storage_api_version,
          'auth_string'  => true
        }

        headers.merge!(additional_headers)
        headers['authorization'] = sig.signature(sig_type, headers)

        headers
      end

      # Generic method to handle NextMarker token. The +doc+ should be an
      # XML object that responds to .xpath, followed by a method name,
      # followed by any arguments to pass to that method.
      #
      def next_marker_results(doc, method_name, *args)
        xmarker = doc.EnumerationResults.NextMarker.text

        if xmarker.nil?
          return []
        else
          args = args.dup # Avoid modifying original argument
          args.last[:marker] = xmarker
          return send(method_name, *args)
        end
      end
    end
  end
end
