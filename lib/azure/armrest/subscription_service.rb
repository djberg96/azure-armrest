module Azure
  module Armrest
    class SubscriptionService < ArmrestService
      # This overrides the typical constructor for an ArmrestService subclass
      # because it does not have a service name or a provider.
      def initialize(configuration, options = {})
        @armrest_configuration = configuration
        @api_version = options[:api_version] || '2016-06-01'
      end

      # Returns a list of Subscription objects for the current tenant, one for
      # each subscription ID.
      #
      def list(query_options = {})
        query = build_query_hash
        response = configuration.connection.get(:path => '/subscriptions', :query => query)
        Azure::Armrest::ArmrestCollection.create_from_response(response, Azure::Armrest::Subscription)
      end

      # Returns a Subscription object for the given +subscription_id+.
      #
      def get(subscription_id, query_options = {})
        query = build_query_hash
        response = configuration.connection.get(:path => "/subscriptions/#{subscription_id}", :query => query)
        Azure::Armrest::Subscription.new(response)
      end
    end
  end
end
