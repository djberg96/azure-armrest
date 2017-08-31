module Azure
  module Armrest
    class Configuration
      # Clear all class level caches. Typically used for testing only.
      def self.clear_caches
        token_cache.clear
      end

      # Used to store unique token information.
      def self.token_cache
        @token_cache ||= Hash.new { |h, k| h[k] = [] }
      end

      # Retrieve the cached token for a configuration.
      # Return both the token and its expiration date, or nil if not cached
      def self.retrieve_token(configuration)
        token_cache[configuration.hash]
      end

      # Cache the token for a configuration that a token has been fetched from Azure
      def self.cache_token(configuration)
        raise ArgumentError, "Configuration does not have a token" if configuration.token.nil?
        token_cache[configuration.hash] = [configuration.token, configuration.token_expiration]
      end

      # The api-version string
      attr_accessor :api_version

      # The client ID used to gather token information.
      attr_accessor :client_id

      # The client key used to gather token information.
      attr_accessor :client_key

      # The tenant ID used to gather token information.
      attr_accessor :tenant_id

      # The subscription ID used for each http request.
      attr_reader :subscription_id

      # The resource group used for http requests.
      attr_accessor :resource_group

      # Namespace providers, their resource types, locations and supported api-version strings.
      attr_reader :providers

      # Maximum number of threads to use within methods that use Parallel for thread pooling.
      attr_accessor :max_threads

      # The environment object which determines various endpoint URL's. The
      # default is Azure::Armrest::Environment::Public.
      attr_accessor :environment

      # A hash of HTTP options to be used with each request, such as proxy information.
      attr_accessor :connection_options

      # A hash of SSL options passed along with each HTTP request.
      attr_accessor :ssl_options

      # The adapter used by Faraday under the hood for requests. The default
      # is :net_http_persistent.
      attr_accessor :adapter

      # Yields a new Azure::Armrest::Configuration objects. Note that you must
      # specify a client_id, client_key, tenant_id. All other parameters are optional.
      #
      # Note that the subscription_id should be set before attempting to perform
      # any operations.
      #
      # Example:
      #
      #   config = Azure::Armrest::Configuration.new(
      #     client_id:  'xxxx',
      #     client_key: 'yyyy',
      #     tenant_id:  'zzzz'
      #   )
      #
      #   config.subscription_id = 'abc'
      #
      # If you specify a :resource_group, that group will be used for resource
      # group based service class requests. Otherwise, you will need to specify
      # a resource group for most service methods.
      #
      # Although you can specify an :api_version, it is typically overridden
      # by individual service classes.
      #
      # The constructor will also validate that the subscription ID is valid
      # if present.
      #
      def initialize(**kwargs)
        # Use defaults, and override with provided arguments
        options = {
          :api_version => '2017-05-10',
          :max_threads => 10,
          :adapter     => :net_http_persistent,
          :environment => Azure::Armrest::Environment::Public
          :ssl_options => {
            :version => 'TLSv1'
          },
          :connection_options => {
            :proxy => ENV['http_proxy'],
          }
        }.merge(args.symbolize_keys)

        if options[:subscription_id]
          msg = "Cannot set subscription ID until after configuration object is created"
          raise ArgumentError, msg
        end

        unless options[:client_id] && options[:client_key] && options[:tenant_id]
          raise ArgumentError, "client_id, client_key, and tenant_id must all be specified"
        end

        Faraday.default_adapter = options[:adapter]

        # Avoid thread safety issues for VCR testing.
        options[:max_threads] = 1 if defined?(VCR)

        # Then set the remaining options automatically
        options.each { |key, value| send("#{key}=", value) }
      end

      def hash
        [environment.name, tenant_id, client_id, client_key].join('_').hash
      end

      # Allow for strings or URI objects when assigning a proxy.
      #
      def proxy=(value)
        @proxy = value ? value.to_s : value
      end

      # Set the subscription ID, and validate the value. This also sets
      # provider information.
      #
      def subscription_id=(value)
        @subscription_id = value
        return if value.nil? || value.empty?
        validate_subscription
        @providers = fetch_providers
        set_provider_api_versions
        value
      end

      def eql?(other)
        return true if equal?(other)
        return false unless self.class == other.class
        tenant_id == other.tenant_id && client_id == other.client_id && client_key == other.client_key
      end

      # Returns the token for the current cache key, or sets it if it does not
      # exist or it has expired.
      #
      def token
        ensure_token
        @token
      end

      # Set the token value and expiration time.
      #
      def set_token(token, token_expiration)
        validate_token_time(token_expiration)

        @token, @token_expiration = token, token_expiration.utc
        self.class.cache_token(self)
      end

      # Returns the expiration datetime of the current token
      #
      def token_expiration
        ensure_token
        @token_expiration
      end

      # Return the default api version for the given provider and service
      def provider_default_api_version(provider, service)
        if @provider_api_versions
          @provider_api_versions[provider.downcase][service.downcase]
        else
          nil # Typically only for the fetch_providers method.
        end
      end

      # The logging object that logs http requests.
      #
      def log
        @log
      end

      # Set the log for Faraday http requests. The argument may be a Logger object, or a
      # path to a file that will become a logger object.
      #
      # It is generally recommended that you set the logger.level to 1 or higher unless
      # you're in debug mode. If it's set at 0 (the default for a Logger object) then
      # you will get verbose output.
      #
      def log=(string_or_logger)
        @log = string_or_logger.kind_of?(Logger) ? string_or_logger : Logger.new(string_or_logger)
        @log.datetime_format = '%Y-%m-%d %H:%M:%S'

        formatter ||= proc do |severity, datetime, progname, msg|
          msg = msg.sub /Bearer(.*?)\"/, 'Bearer [FILTERED]"'
          "\n[#{datetime}] - #{severity} -- : #{msg}"
        end

        @log.formatter = formatter

        @log
      end

      # Returns a list of subscriptions for the current configuration object.
      #
      def subscriptions
        Azure::Armrest::SubscriptionService.new(self).list
      end

      private

      # Validate the subscription ID for the given credentials. Returns the
      # subscription ID if valid.
      #
      # If the subscription ID that was provided in the constructor cannot
      # be found within the list of valid subscriptions, then an error is
      # raised.
      #
      # If the subscription ID that was provided is found but disabled
      # then a warning will be issued, but no error will be raised.
      #
      def validate_subscription
        found = subscriptions.find { |sub| sub.subscription_id == subscription_id }

        unless found
          raise ArgumentError, "Subscription ID '#{subscription_id}' not found"
        end

        if found.state.casecmp('enabled') != 0
          warn "Subscription '#{found.subscription_id}' found but not enabled."
        end
      end

      def ensure_token
        @token, @token_expiration = self.class.retrieve_token(self) if @token.nil?
        fetch_token if @token.nil? || Time.now.utc > @token_expiration
      end

      # Don't allow tokens from the past to be set.
      #
      def validate_token_time(time)
        if time.utc < Time.now.utc
          raise ArgumentError, 'token_expiration date invalid'
        end
      end

      # Build a one-time lookup hash that sets the appropriate api-version
      # string for a given provider and resource type. If possible, select
      # a non-preview version that is not set in the future. Otherwise, just
      # just the most recent one.
      #
      def set_provider_api_versions
        # A lookup table for getting api-version strings per provider and service.
        @provider_api_versions = Hash.new { |hash, key| hash[key] = {} }

        providers.each do |rp|
          rp.resource_types.each do |rt|
            if rt.api_versions.any? { |v| v !~ /preview/i && Time.parse(v).utc <= Time.now.utc }
              api_version = rt.api_versions.reject do |version|
                version =~ /preview/i || Time.parse(version).utc > Time.now.utc
              end.first
            else
              api_version = rt.api_versions.first
            end

            namespace     = rp['namespace'].downcase # Avoid name collision
            resource_type = rt.resource_type.downcase

            @provider_api_versions[namespace][resource_type] = api_version
          end
        end
      end

      def fetch_providers
        Azure::Armrest::ResourceProviderService.new(self).list
      end

      def fetch_token
        token_url = File.join(environment.authority_url, tenant_id, 'oauth2', 'token')

        response = JSON.parse(
          ArmrestService.send(
            :rest_post,
            :url         => token_url,
            :proxy       => proxy,
            :ssl_version => ssl_version,
            :ssl_verify  => ssl_verify,
            :payload     => {
              :grant_type    => grant_type,
              :client_id     => client_id,
              :client_secret => client_key,
              :resource      => environment.resource_url
            }
          )
        )

        @token = 'Bearer ' + response['access_token']
        @token_expiration = Time.now.utc + response['expires_in'].to_i

        self.class.cache_token(self)
      end
    end
  end
end
