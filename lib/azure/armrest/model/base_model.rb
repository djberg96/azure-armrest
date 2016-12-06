require 'active_support/core_ext/string/inflections'
require 'pp'

module Azure
  module Armrest
    # Base class for JSON wrapper classes. Each Service class should have
    # a corresponding class that wraps the JSON it collects, and each of
    # them should subclass this base class.
    class BaseModel
      # Initially inherit the exclusion list from parent class or create an empty Set.
      def self.excl_list
        @excl_list ||= superclass.respond_to?(:excl_list, true) ? superclass.send(:excl_list) : Set.new
      end

      private_class_method :excl_list

      # Merge the declared exclusive attributes to the existing list.
      def self.attr_hash(*attrs)
        @excl_list = excl_list | Set.new(attrs.map(&:to_s))
      end

      private_class_method :attr_hash

      attr_hash :tags

      attr_accessor :response_headers
      attr_accessor :response_code

      # Constructs and returns a new JSON wrapper class. Pass in a plain
      # JSON string and it will automatically give you accessor methods
      # that make it behave like a typical Ruby object. You may also pass
      # in a hash.
      #
      # Example:
      #   class Person < Azure::ArmRest::BaseModel; end
      #
      #   json_string = '{"firstname":"jeff", "lastname":"durand",
      #     "address": { "street":"22 charlotte rd", "zipcode":"01013"}
      #   }'
      #
      #   # Or whatever your subclass happens to be.
      #   person = Person.new(json_string)
      #
      #   # The JSON properties are now available as methods.
      #   person.firstname        # => 'jeff'
      #   person.address.zipcode  # => '01013'
      #
      #   # Or you can get back the original JSON if necessary.
      #   person.to_json # => Returns original JSON
      #
      def initialize(json)
        # Find the exclusion list for the model of next level (@embed_model)
        # '#' is the separator between levels. Remove attributes
        # before the first separator.
        @child_excl_list = self.class.send(:excl_list).map do |e|
          e.index('#') ? e[e.index('#') + 1..-1] : ''
        end

        if json.kind_of?(Hash)
          @hash = json
          @json = json.to_json
        else
          @hash = JSON.parse(json)
          @json = json
        end

        __setobj__(@hash.dup)
      end

      def resource_group
        @resource_group ||= id[/resourceGroups\/(.+?)\//i, 1] rescue nil
      end

      attr_writer :resource_group

      def to_h
        @hash
      end

      def to_hash
        @hash
      end

      def to_json
        @json
      end

      def to_s
        @json
      end

      def to_str
        @json
      end

      def pretty_print(q)
        inspect_method_list = methods(false).reject { |m| m.to_s.end_with?('=') }

        q.object_address_group(self) {
          q.seplist(inspect_method_list, lambda { q.text ',' }) {|v|
            q.breakable
            q.text v.to_s
            q.text '='
            q.group(1) {
              q.breakable ''
              q.pp(send(v))
            }
          }
        }
      end

      alias_method :inspect, :pretty_print_inspect

      def ==(other)
        return false unless other.kind_of?(BaseModel)
        __getobj__ == other.__getobj__
      end

      def eql?(other)
        return false unless other.kind_of?(BaseModel)
        __getobj__.eql?(other.__getobj__)
      end

      # Support hash style accessors
      def [](key)
        __getobj__[key]
      end

      def []=(key, val)
        key_exists = __getobj__.include?(key)
        __getobj__[key] = val

        return if key_exists
        add_accessor_methods(key.to_s.underscore, key)
      end

      protected

      # Do not use this method directly.
      def __getobj__
        @hashobj
      end

      # Create snake_case accessor methods for all hash attributes
      # Use _alias if an accessor conflicts with existing methods
      def __setobj__(obj)
        @hashobj = obj
        excl_list = self.class.send(:excl_list)
        obj.each do |key, value|
          snake = key.to_s.underscore

          unless excl_list.include?(snake) # Must deal with nested models
            if value.kind_of?(Array)
              newval = value.map { |elem| elem.kind_of?(Hash) ? nested_object(snake.camelize.singularize, elem) : elem }
              obj[key] = newval
            elsif value.kind_of?(Hash)
              obj[key] = nested_object(snake.camelize, value)
            end
          end

          add_accessor_methods(snake, key)
        end
      end

      def nested_object(klass_name, value)
        unless self.class.const_defined?(klass_name, false)
          child_excl_list = @child_excl_list
          self.class.const_set(klass_name, Class.new(BaseModel) { attr_hash(*child_excl_list) })
        end
        self.class.const_get(klass_name).new(value)
      end

      def add_accessor_methods(method, key)
        method = "_#{method}" if methods.include?(method.to_sym)
        instance_eval { define_singleton_method(method) { __getobj__[key] } }
        instance_eval { define_singleton_method("#{method}=") { |val| __getobj__[key] = val } }
      end
    end

    # Initial class definitions. Reopen these classes as needed.

    class AvailabilitySet < BaseModel; end
    class DeploymentTemplate < BaseModel; end
    class Event < BaseModel; end
    class ImageVersion < BaseModel; end
    class Offer < BaseModel; end
    class Publisher < BaseModel; end
    class Resource < BaseModel; end
    class ResourceGroup < BaseModel; end
    class ResourceProvider < BaseModel; end
    class Sku < BaseModel; end

    module Billing
      class Usage < BaseModel; end
    end

    class ResponseHeaders < BaseModel
      undef_method :response_headers
    end

    class StorageAccount < BaseModel; end
    class StorageAccountKey < StorageAccount
      def key1; key_name == 'key1' ? value : nil; end
      def key2; key_name == 'key2' ? value : nil; end
      def key; key1 || key2; end
    end

    class Subscription < BaseModel; end
    class Tag < BaseModel; end
    class TemplateDeployment < BaseModel
      attr_hash 'properties#parameters', 'properties#outputs'
    end
    class TemplateDeploymentOperation < TemplateDeployment; end
    class Tenant < BaseModel; end
    class VirtualMachine < BaseModel; end
    class VirtualMachineInstance < VirtualMachine; end
    class VirtualMachineModel < VirtualMachine; end
    class VirtualMachineExtension < BaseModel; end
    class VirtualMachineImage < BaseModel; end
    class VirtualMachineSize < BaseModel; end

    module Insights
      class Alert < BaseModel; end
      class Diagnostic < BaseModel; end
      class Event < BaseModel; end
      class Metric < BaseModel; end
    end

    module Network
      class LoadBalancer < BaseModel; end
      class InboundNat < LoadBalancer; end
      class IpAddress < BaseModel; end
      class NetworkInterface < BaseModel; end
      class NetworkSecurityGroup < BaseModel; end
      class NetworkSecurityRule < NetworkSecurityGroup; end
      class RouteTable < BaseModel; end
      class Route < RouteTable; end
      class VirtualNetwork < BaseModel; end
      class Subnet < VirtualNetwork; end
    end

    module Role
      class Assignment < BaseModel; end
      class Definition < BaseModel; end
    end

    module Sql
      class SqlServer < BaseModel; end
      class SqlDatabase < BaseModel; end
    end

    module ActiveDirectory
      class User < BaseModel; end
      class Group < BaseModel; end
    end
  end
end

require_relative 'storage_account'
