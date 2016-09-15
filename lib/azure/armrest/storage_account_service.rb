require 'azure-signature'

module Azure
  module Armrest
    # Class for managing storage accounts.
    class StorageAccountService < ResourceGroupBasedService

      # Valid account types for the create or update method.
      VALID_ACCOUNT_TYPES = %w[
        Standard_LRS
        Standard_ZRS
        Standard_GRS
        Standard_RAGRS
      ]

      # Creates and returns a new StorageAccountService (SAS) instance.
      #
      def initialize(configuration, options = {})
        super(configuration, 'storageAccounts', 'Microsoft.Storage', options)
      end

      # Same as other resource based get methods, but also sets the proxy on the model object.
      #
      def get(name, resource_group = configuration.resource_group)
        super.tap do |m|
          m.proxy       = configuration.proxy
          m.ssl_version = configuration.ssl_version
          m.ssl_verify  = configuration.ssl_verify
        end
      end

      # Same as other resource based list methods, but also sets the proxy on each model object.
      #
      def list(resource_group = configuration.resource_group)
        super.each do |m|
          m.proxy       = configuration.proxy
          m.ssl_version = configuration.ssl_version
          m.ssl_verify  = configuration.ssl_verify
        end
      end

      # Same as other resource based list_all methods, but also sets the proxy on each model object.
      #
      def list_all
        super.each do |m|
          m.proxy       = configuration.proxy
          m.ssl_version = configuration.ssl_version
          m.ssl_verify  = configuration.ssl_verify
        end
      end

      # Creates a new storage account, or updates an existing account with the
      # specified parameters.
      #
      # Note that the name of the storage account within the specified
      # must be 3-24 alphanumeric lowercase characters.
      #
      # The options available are as follows:
      #
      # - :validating
      #   Optional. Set to 'nameAvailability' to indicate that the account
      #   name must be checked for global availability.
      #
      # - :properties
      #   - :accountType
      #     The type of storage account, e.g. "Standard_GRS".
      #
      # - :location
      #   Required: One of the Azure geo regions, e.g. 'West US'.
      #
      # - :tags
      #   A hash of tags to describe the resource. You may have a maximum of
      #   10 tags, and each key has a max size of 128 characters, and each
      #   value has a max size of 256 characters. These are optional.
      #
      # Example:
      #
      #   sas = Azure::Armrest::StorageAccountService(config)
      #
      #   sas.create(
      #     "your_storage_account",
      #     "your_resource_group",
      #     {
      #       :location   => "West US",
      #       :properties => {:accountType => "Standard_ZRS"},
      #       :tags       => {:YourCompany => true}
      #     }
      #   )
      #
      def create(account_name, rgroup = configuration.resource_group, options)
        validating = options.delete(:validating)
        validate_account_type(options[:properties][:accountType])
        validate_account_name(account_name)

        acct = super(account_name, rgroup, options) do |url|
          url << "&validating=" << validating if validating
        end

        # An initial create call will return nil because the response body is
        # empty. In that case, make another call to get the object properties.
        acct = get(account_name, rgroup) unless acct

        acct.proxy       = configuration.proxy
        acct.ssl_version = configuration.ssl_version
        acct.ssl_verify  = configuration.ssl_verify

        acct
      end

      # Returns the primary and secondary access keys for the given storage
      # account. This method will return a hash with 'key1' and 'key2' as its
      # keys.
      #
      # If you want a list of StorageAccountKey objects, then use the
      # list_account_key_objects method instead.
      #
      def list_account_keys(account_name, group = configuration.resource_group)
        validate_resource_group(group)

        url = build_url(group, account_name, 'listKeys')
        response = rest_post(url)
        hash = JSON.parse(response.body)

        parse_account_keys_from_hash(hash)
      end

      alias list_storage_account_keys list_account_keys

      # Returns a list of StorageAccountKey objects consisting of information
      # the primary and secondary keys. This method requires an api-version
      # string of 2016-01-01 or later, or an error is raised.
      #
      # If you want a plain hash, use the list_account_keys method instead.
      #
      def list_account_key_objects(account_name, group = configuration.resource_group)
        validate_resource_group(group)

        unless recent_api_version?
          raise ArgumentError, "unsupported api-version string '#{api_version}'"
        end

        url = build_url(group, account_name, 'listKeys')
        response = rest_post(url)
        JSON.parse(response.body)['keys'].map { |hash| StorageAccountKey.new(hash) }
      end

      alias list_storage_account_key_objects list_account_key_objects

      # Regenerates the primary or secondary access keys for the given storage
      # account. The +key_name+ may be either 'key1' or 'key2'. If no key name
      # is provided, then it defaults to 'key1'.
      #
      def regenerate_account_keys(account_name, group = configuration.resource_group, key_name = 'key1')
        validate_resource_group(group)

        options = {'keyName' => key_name}

        url = build_url(group, account_name, 'regenerateKey')
        response = rest_post(url, options.to_json)
        hash = JSON.parse(response.body)

        parse_account_keys_from_hash(hash)
      end

      alias regenerate_storage_account_keys regenerate_account_keys

      # Same as regenerate_account_keys, but returns an array of
      # StorageAccountKey objects instead.
      #
      # This method requires an api-version string of 2016-01-01 or later
      # or an ArgumentError is raised.
      #
      def regenerate_account_key_objects(account_name, group = configuration.resource_group, key_name = 'key1')
        validate_resource_group(group)

        unless recent_api_version?
          raise ArgumentError, "unsupported api-version string '#{api_version}'"
        end

        options = {'keyName' => key_name}

        url = build_url(group, account_name, 'regenerateKey')
        response = rest_post(url, options.to_json)
        JSON.parse(response.body)['keys'].map { |hash| StorageAccountKey.new(hash) }
      end

      alias regenerate_storage_account_key_objects regenerate_account_key_objects

      # Returns a list of PrivateImage objects that are available for
      # provisioning for all storage accounts in the current subscription.
      #
      # You may optionally reduce the set of storage accounts that will
      # be scanned by providing a filter, where the keys are StorageAccount
      # properties.
      #
      # Example:
      #
      #   sas.list_all_private_images(:location => 'eastus', resource_group => 'some_group')
      #
      def list_all_private_images(filter = {})
        storage_accounts = list_all.select { |acct| filter.all? { |k, v| acct.public_send(k) == v } }
        get_private_images(storage_accounts)
      end

      # Returns a list of PrivateImage objects that are available for
      # provisioning for all storage accounts in the provided resource group.
      #
      # The custom keys :uri and :operating_system have been added to the
      # resulting PrivateImage objects for convenience.
      #
      # Example:
      #
      #   sas.list_private_images(your_resource_group)
      #
      def list_private_images(group = configuration.resource_group)
        storage_accounts = list(group)
        get_private_images(storage_accounts)
      end

      def accounts_by_name
        @accounts_by_name ||= list_all.each_with_object({}) { |sa, sah| sah[sa.name] = sa }
      end

      def parse_uri(uri)
        uri = URI.parse(uri)
        host_components = uri.host.split('.')

        rh = {
          :scheme        => uri.scheme,
          :account_name  => host_components[0],
          :service_name  => host_components[1],
          :resource_path => uri.path
        }

        # TODO: support other service types.
        return rh unless rh[:service_name] == "blob"

        blob_components = uri.path.split('/', 3)
        if blob_components[2]
          rh[:container] = blob_components[1]
          rh[:blob]      = blob_components[2]
        else
          rh[:container] = '$root'
          rh[:blob]      = blob_components[1]
        end

        return rh unless uri.query && uri.query.start_with?("snapshot=")
        rh[:snapshot] = uri.query.split('=', 2)[1]
        rh
      end

      private

      # Given a list of StorageAccount objects, returns all private images
      # within those accounts.
      #
      def get_private_images(storage_accounts)
        results = []
        threads = []
        mutex = Mutex.new

        storage_accounts.each do |lstorage_account|
          threads << Thread.new(lstorage_account) do |storage_account|
            begin
              key = get_account_key(storage_account)
            rescue Azure::Armrest::ApiException => err
              # Most likely because the storage account isn't completely provisioned
              # yet or provisioning of the account was not successful
              next
            end

            storage_account.all_blobs(key).each do |blob|
              next unless File.extname(blob.name).casecmp('.vhd') == 0
              next unless blob.properties.lease_state.casecmp('available') == 0

              blob_properties = storage_account.blob_properties(blob.container, blob.name, key)
              next unless blob_properties.respond_to?(:x_ms_meta_microsoftazurecompute_osstate)
              next unless blob_properties.x_ms_meta_microsoftazurecompute_osstate.casecmp('generalized') == 0

              mutex.synchronize do
                results << blob_to_private_image_object(storage_account, blob, blob_properties)
              end
            end
          end
        end

        threads.each(&:join)

        results
      end

      # Converts a StorageAccount::Blob object into a StorageAccount::PrivateImage
      # object, which is a mix of Blob and StorageAccount properties.
      #
      def blob_to_private_image_object(storage_account, blob, blob_properties)
        hash = blob.to_h.merge(
          :storage_account  => storage_account.to_h,
          :blob_properties  => blob_properties.to_h,
          :operating_system => blob_properties.try(:x_ms_meta_microsoftazurecompute_ostype),
          :uri              => File.join(
            storage_account.properties.primary_endpoints.blob,
            blob.container,
            blob.name
          )
        )

        StorageAccount::PrivateImage.new(hash)
      end

      # Get the key for the given +storage_acct+ using the appropriate method
      # depending on the api-version.
      #
      def get_account_key(storage_acct)
        if recent_api_version?
          list_account_key_objects(storage_acct.name, storage_acct.resource_group).first.key
        else
          list_account_keys(storage_acct.name, storage_acct.resource_group).fetch('key1')
        end
      end

      # Check to see if the api-version string is 2016-01-01 or later.
      def recent_api_version?
        Time.parse(api_version).utc >= Time.parse('2016-01-01').utc
      end

      # As of api-version 2016-01-01, the format returned for listing and
      # regenerating hash keys has changed.
      #
      def parse_account_keys_from_hash(hash)
        if recent_api_version?
          key1 = hash['keys'].find { |h| h['keyName'] == 'key1' }['value']
          key2 = hash['keys'].find { |h| h['keyName'] == 'key2' }['value']
          hash = {'key1' => key1, 'key2' => key2}
        end

        hash
      end

      def validate_account_type(account_type)
        unless VALID_ACCOUNT_TYPES.include?(account_type)
          raise ArgumentError, "invalid account type '#{account_type}'"
        end
      end

      def validate_account_name(name)
        if name.size < 3 || name.size > 24 || name[/\W+/]
          raise ArgumentError, "name must be 3-24 alpha-numeric characters only"
        end
      end
    end
  end
end
