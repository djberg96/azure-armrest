module Azure
  module Armrest
    module Containers
      # Class for managing public IP addresss.
      class RegistryService < ResourceGroupBasedService

        # Creates and returns a new Container::RegistryService instance.
        #
        def initialize(armrest_configuration, options = {})
          super(armrest_configuration, 'registries', 'Microsoft.ContainerRegistry', options)
        end

        # Check to see if the +registry_name+ is available for the subscription and return
        # a Registry object. If true, the Registry object will contain a single property
        # called +name_available+. If false, the resulting object will also contain a +reason+
        # and a +message+ property.
        #
        def check_availability(registry_name)
          url = url_with_api_version(
            api_version,
            base_url,
            'providers',
            provider,
            'checkNameAvailability'
          )

          options = {
            :name => registry_name,
            :type => 'Microsoft.ContainerRegistry/registries'
          }

          response = rest_post(url, options.to_json)
          Azure::Armrest::Containers::Registry.new(response)
        end

        def import_image(registry_name, resource_group, options)
        end

        def list_credentials(registry_name, resource_group)
        end

        def list_usages(registry_name, resource_group)
        end

        def regenerate_credentials(registry_name, resource_group)
        end
      end
    end # Network
  end # Armrest
end # Azure

