# Azure namespace
module Azure
  # Armrest namespace
  module Armrest
    # Base class for managing hosts.
    class HostService < ResourceGroupBasedSubservice
      def initialize(configuration, options = {})
        super(configuration, 'hostGroups', 'hosts', 'Microsoft.Compute', options)
      end
    end
  end
end
