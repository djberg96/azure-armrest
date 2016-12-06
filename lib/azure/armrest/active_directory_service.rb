module Azure
  module Armrest
    class ActiveDirectoryService < ArmrestService
      def initialize(configuration, options = {})
        @armrest_configuration = configuration
        @api_version = options[:api_version] || '1.6'
      end

      def get_user(user)
      end

      def users
        url = File.join(graph_url, 'users') + "?api-version=#{api_version}"
        response = rest_get(url)
        Azure::Armrest::ArmrestCollection.create_from_response(response, Azure::Armrest::ActiveDirectory::User)
      end

      private

      def graph_url
        File.join(Azure::Armrest::GRAPH, configuration.tenant_id)
      end
    end
  end
end
