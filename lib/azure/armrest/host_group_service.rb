# Azure namespace
module Azure
  # Armrest namespace
  module Armrest
    # Base class for managing host groups.
    class HostGroupService < ResourceGroupBasedService
      def initialize(configuration, options = {})
        super(configuration, 'hostGroups', 'Microsoft.Compute', options)
      end
    end
  end
end
