# Azure namespace
module Azure
  # Armrest namespace
  module Armrest
    # Base class for managing virtual machines
    class VirtualMachineService < ResourceGroupBasedService
      # Create and return a new VirtualMachineService (VMM) instance. Most
      # methods for a VMM instance will return one or more VirtualMachine
      # instances.
      #
      # This subclass accepts the additional :provider option as well. The
      # default is 'Microsoft.ClassicCompute'. You may need to set this to
      # 'Microsoft.Compute' for your purposes.
      #
      def initialize(configuration, options = {})
        super(configuration, 'virtualMachines', 'Microsoft.Compute', options)
      end

      # Return a list of available VM series (aka sizes, flavors, etc), such
      # as "Basic_A1", though other information is included as well.
      #
      def series(location)
        namespace = 'microsoft.compute'
        version = configuration.provider_default_api_version(namespace, 'locations/vmsizes')

        unless version
          raise ArgumentError, "Unable to find resources for #{namespace}"
        end

        url = url_with_api_version(
          version, base_url, 'providers', provider, 'locations', location, 'vmSizes'
        )

        JSON.parse(rest_get(url))['value'].map{ |hash| VirtualMachineSize.new(hash) }
      end

      alias sizes series

      # Captures the +vmname+ and associated disks into a reusable CSM template.
      # The 3rd argument is a hash of options that supports the following keys:
      #
      # * vhdPrefix                - The prefix in the name of the blobs.
      # * destinationContainerName - The name of the container inside which the image will reside.
      # * overwriteVhds            - Boolean that indicates whether or not to overwrite any VHD's
      #                              with the same prefix. The default is false.
      #
      def capture(vmname, options, group = configuration.resource_group)
        vm_operate('capture', vmname, group, options)
      end

      # Stop the VM +vmname+ in +group+ and deallocate the tenant in Fabric.
      #
      def deallocate(vmname, group = configuration.resource_group)
        vm_operate('deallocate', vmname, group)
      end

      # Sets the OSState for the +vmname+ in +group+ to 'Generalized'.
      #
      def generalize(vmname, group = configuration.resource_group)
        vm_operate('generalize', vmname, group)
      end

      # Retrieves the settings of the VM named +vmname+ in resource group
      # +group+, which will default to the same as the name of the VM.
      #
      # By default this method will retrieve the model view. If the +model_view+
      # parameter is false, it will retrieve an instance view. The difference is
      # in the details of the information retrieved.
      #
      def get(vmname, group = configuration.resource_group, model_view = true)
        model_view ? super(vmname, group) : get_instance_view(vmname, group)
      end

      # Convenient wrapper around the get method that retrieves the model view
      # for +vmname+ in resource_group +group+.
      #
      def get_model_view(vmname, group = configuration.resource_group)
        get(vmname, group, true)
      end

      # Convenient wrapper around the get method that retrieves the instance view
      # for +vmname+ in resource_group +group+.
      #
      def get_instance_view(vmname, group = configuration.resource_group)
        raise ArgumentError, "must specify resource group" unless group
        raise ArgumentError, "must specify name of the resource" unless vmname

        url = build_url(group, vmname, 'instanceView')
        response = rest_get(url)
        VirtualMachineInstance.new(response)
      end

      # Restart the VM +vmname+ for the given +group+, which will default
      # to the same as the vmname.
      #
      # This is an asynchronous operation that returns a response object
      # which you can inspect, such as response.code or response.headers.
      #
      def restart(vmname, group = configuration.resource_group)
        vm_operate('restart', vmname, group)
      end

      # Start the VM +vmname+ for the given +group+, which will default
      # to the same as the vmname.
      #
      # This is an asynchronous operation that returns a response object
      # which you can inspect, such as response.code or response.headers.
      #
      def start(vmname, group = configuration.resource_group)
        vm_operate('start', vmname, group)
      end

      # Stop the VM +vmname+ for the given +group+ gracefully. However,
      # a forced shutdown will occur after 15 minutes.
      #
      # This is an asynchronous operation that returns a response object
      # which you can inspect, such as response.code or response.headers.
      #
      def stop(vmname, group = configuration.resource_group)
        vm_operate('powerOff', vmname, group)
      end

      # Delete the VM and associated resources. By default, this will
      # delete the VM, its NIC, the associated IP address, and the
      # image files (.vhd and .status) for the VM.
      #
      # If you want to delete other associated resources, such as any
      # attached disks, the VM's underlying storage account, or associated
      # network security groups you must explicitly specify them as an option.
      #
      # An attempt to delete a resource that cannot be deleted because it's
      # still associated with some other resource will be logged and skipped.
      #
      # If the :verbose option is set to true, then additional messages are
      # sent to your configuration log, or stdout if no log was specified.
      #
      # Note that if all of your related resources are in a self-contained
      # resource group, you do not necessarily need this method. You could
      # just delete the resource group itself, which would automatically
      # delete all of its resources.
      #
      def delete_associated_resources(vmname, vmgroup, options = {})
        options = {
          :network_interfaces      => true,
          :ip_addresses            => true,
          :os_disk                 => true,
          :network_security_groups => false,
          :storage_account         => false,
          :verbose                 => false
        }.merge(options)

        Azure::Armrest::Configuration.log ||= STDOUT if options[:verbose]

        vm = get(vmname, vmgroup)

        delete_and_wait(self, vmname, vmgroup, options)

        # Must delete network interfaces first if you want to delete
        # IP addresses or network security groups.
        if options[:network_interfaces] || options[:ip_addresses] || options[:network_security_groups]
          delete_associated_nics(vm, options)
        end

        if options[:os_disk] || options[:storage_account]
          delete_associated_disk(vm, options)
        end
      end

      # Clone an existing unmanaged VM. Here the +vm+ argument can be either a
      # VirtualMachine object or a string.
      #
      def clone(vm, resource_group, options = {})
        vm = vm.is_a?(String) ? get(vm, resource_group) : vm

        if vm.managed_disk?
          raise "The clone method is only valid for unmanaged disks."
        end

        current_vhd = vm.properties.storage_profile.os_disk.vhd.uri
        uri = Addressable::URI.parse(current_vhd)
        storage_acct_name = uri.host.split('.').first

        sas = Azure::Armrest::StorageAccountService.new(configuration)
        storage_account = sas.list_all.find { |s| s.name == storage_acct_name }

        if storage_account.nil?
          raise "Unable to find storage account for #{vm.name}"
        end

        keys = sas.list_account_keys(storage_account.name, storage_account.resource_group)
        key  = keys['key1'] || keys['key2']

        source_blob = storage_account.all_blobs(key).find { |b| b.name == File.basename(current_vhd) }
        dest_blob   = File.basename(source_blob, '.vhd') + '_clone.vhd'

        copy = storage_account.copy_blob(
          source_blob.container,
          source_blob.name,
          source_blob.container,
          dest_blob,
          key
        )

        wait(copy.response_headers)

        create(options[:name], vm.resource_group, options)
      end

      def model_class
        VirtualMachineModel
      end

      private

      # Deletes any NIC's associated with the VM, and optionally any public IP addresses
      # and network security groups.
      #
      def delete_associated_nics(vm, options)
        nis = Azure::Armrest::Network::NetworkInterfaceService.new(configuration)
        nics = vm.properties.network_profile.network_interfaces.map(&:id)

        if options[:ip_addresses]
          ips = Azure::Armrest::Network::IpAddressService.new(configuration)
        end

        if options[:network_security_groups]
          nsgs = Azure::Armrest::Network::NetworkSecurityGroupService.new(configuration)
        end

        nics.each do |nic_id_string|
          nic = get_by_id(nic_id_string)
          delete_and_wait(nis, nic.name, nic.resource_group, options)

          if options[:ip_addresses]
            nic.properties.ip_configurations.each do |ip|
              ip = get_by_id(ip.properties.public_ip_address.id)
              delete_and_wait(ips, ip.name, ip.resource_group, options)
            end
          end

          if options[:network_security_groups]
            if nic.properties.respond_to?(:network_security_group)
              nsg = get_by_id(nic.properties.network_security_group.id)
              delete_and_wait(nsgs, nsg.name, nsg.resource_group, options)
            end
          end
        end
      end

      # This deletes the OS disk from the storage account that's backing the
      # virtual machine, along with the .status file. This does NOT delete
      # copies of the disk.
      #
      # If the option to delete the entire storage account was selected, then
      # it will not bother with deleting invidual files from the storage
      # account first.
      #
      def delete_associated_disk(vm, options)
        sas = Azure::Armrest::StorageAccountService.new(configuration)

        storage_account = sas.get_from_vm(vm)

        # Deleting the storage account does not require deleting the disks
        # first, so skip that if deletion of the storage account was requested.
        if options[:storage_account]
          delete_and_wait(sas, storage_account.name, storage_account.resource_group, options)
        else
          keys = sas.list_account_keys(storage_account.name, storage_account.resource_group)
          key  = keys['key1'] || keys['key2']
          disk = sas.get_os_disk(vm)

          # There's a short delay between deleting the VM and unlocking the underlying
          # .vhd file by Azure. Therefore we sleep up to two minutes while checking.
          if disk.x_ms_lease_status.casecmp('unlocked') != 0
            sleep_time = 0

            while sleep_time < 120
              sleep 10
              sleep_time += 10
              disk = sas.get_os_disk(vm)
              break if disk.x_ms_lease_status.casecmp('unlocked') != 0
            end

            # In the unlikely event it did not unlock, just log and skip.
            if disk.x_ms_lease_status.casecmp('unlocked') != 0
              log('warn', "Unable to delete disk #{disk.container}/#{disk.name}")
              return
            end
          end

          storage_account.delete_blob(disk.container, disk.name, key)
          log("Deleted blob #{disk.container}/#{disk.name}") if options[:verbose]

          begin
            status_file = File.basename(disk.name, '.vhd') + '.status'
            storage_account.delete_blob(disk.container, status_file, key)
          rescue Azure::Armrest::NotFoundException
            # Ignore, does not always exist.
          else
            log("Deleted blob #{disk.container}/#{status_file}") if options[:verbose]
          end
        end
      end

      # Delete a +service+ type resource using its name and resource group,
      # and wait for the operation to complete before returning.
      #
      # If the operation fails because a dependent resource is still attached,
      # then the error is logged (in verbose mode) and ignored.
      #
      def delete_and_wait(service, name, group, options)
        resource_type = service.class.to_s.sub('Service', '').split('::').last

        log("Deleting #{resource_type} #{name}/#{group}") if options[:verbose]

        wait(service.delete(name, group), 0)

        log("Deleted #{resource_type} #{name}/#{group}") if options[:verbose]
      rescue Azure::Armrest::BadRequestException, Azure::Armrest::PreconditionFailedException => err
        if options[:verbose]
          msg = "Unable to delete #{resource_type} #{name}/#{group}, skipping. Message: #{err.message}"
          log('warn', msg)
        end
      end

      def vm_operate(action, vmname, group, options = {})
        raise ArgumentError, "must specify resource group" unless group
        raise ArgumentError, "must specify name of the vm" unless vmname

        url = build_url(group, vmname, action)
        rest_post(url)
        nil
      end
    end
  end
end
