module Azure
  module Armrest
    class ConsumptionService < ArmrestService
      def initialize(configuration, options = {})
        super(configuration, 'usageDetails', 'Microsoft.Consumption', options)
        @api_version = '2017-04-24-preview'
      end

      # Lists the usage details for a scope by billing period. Possible
      # options are:
      #
      # * scope   (Microsoft.Billing/billingperiods/date)
      # * expand  (meterDetails and/or additionalProperties)
      # * filter
      # * top
      #
      def list(options = {})
        url = build_url(options)
        response = rest_get(url)
        Azure::Armrest::ArmrestCollection.create_from_response(response, Azure::Armrest::Consumption)
      end

      private

      def build_url(options = {})
        if options[:scope]
          url = File.join(base_url, options[:scope], 'providers', provider, service_name)
        else
          url = File.join(base_url, 'providers', provider, service_name)
        end

        url << "?api-version=#{api_version}"

        options.each do |key,value|
          if ['top', 'expand', 'filter'].include?(key.to_s.downcase)
            url << "&$#{key}=#{value}"
          end
        end

        url
      end
    end
  end
end
