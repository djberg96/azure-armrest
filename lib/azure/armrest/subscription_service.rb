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
      def list
        url = subscriptions_url + "?api-version=#{api_version}"
        response = rest_get(url)
        Azure::Armrest::ArmrestCollection.create_from_response(response, Azure::Armrest::Subscription)
      end

      # Returns a Subscription object for the given +subscription_id+.
      #
      def get(subscription_id)
        url = File.join(subscriptions_url, subscription_id) + "?api-version=#{api_version}"
        response = rest_get(url)
        Azure::Armrest::Subscription.new(response)
      end

      private

      def subscriptions_url
        File.join(Azure::Armrest::RESOURCE, 'subscriptions')
      end
    end
  end
end
