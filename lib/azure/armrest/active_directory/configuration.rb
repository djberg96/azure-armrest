module Azure
  module Armrest
    class ActiveDirectoryConfiguration < Azure::Armrest::Configuration
      def initialize(args)
        options = args.symbolize_keys

        @tenant_id       = options.delete(:tenant_id)        
        @client_id       = options.delete(:client_id)
        @client_key      = options.delete(:client_key)
        @subscription_id = options.delete(:subscription_id)

        fetch_token
        options[:token] = @token
        options[:token_expiration] = @token_expiration

        super(options) 
      end

      private

      def fetch_token
        token_url = File.join(Azure::Armrest::GRAPH_AUTHORITY, tenant_id, 'oauth2/token')
        get_token(token_url, Azure::Armrest::GRAPH_RESOURCE)
      end
    end
  end
end
