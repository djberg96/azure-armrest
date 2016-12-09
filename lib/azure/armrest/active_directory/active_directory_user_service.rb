module Azure
  module Armrest
    module ActiveDirectory
      class UserService < ArmrestService
        include Azure::Armrest::ActiveDirectory

        def initialize(configuration, options = {})
          @armrest_configuration = configuration
          @api_version = options[:api_version] || '1.6'
          @service_name = 'users'
        end

        def get_user(user, filter=nil)
          url = File.join(graph_url, 'users', user) + api_version_string
        end

        def users(filter=nil)
          url = File.join(graph_url, 'users') + api_version_string
          response = rest_get(url)
          Azure::Armrest::ArmrestCollection.create_from_response(response, Azure::Armrest::ActiveDirectory::User)
        end
      end
    end
  end
end
