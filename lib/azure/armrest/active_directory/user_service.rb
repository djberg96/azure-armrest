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

        def get_user(user, links = false, property = nil, filter={})
          url = build_url(user, links, property, filter)
        end

        def users(links = false, property = nil, filter={})
          url = build_url(nil, links, property, filter)
          response = rest_get(url)
          Azure::Armrest::ArmrestCollection.create_from_response(response, Azure::Armrest::ActiveDirectory::User)
        end
      end
    end
  end
end
