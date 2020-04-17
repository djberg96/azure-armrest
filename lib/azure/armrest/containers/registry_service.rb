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

        def available?(registry_name, resource_group)
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

