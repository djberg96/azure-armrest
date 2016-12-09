module Azure
  module Armrest
    module ActiveDirectory
      # Builds a standard URL for use with the ActiveDirectory related Service
      # classes. The URL is modified depending on the presence of +object_id+
      # (which could be a user ID, group ID, etc).
      #
      # The +links+ argument will append a "$links" string to the URL, and any
      # +property+ will be appended as well.
      #
      # Lastly, any +filter+ options will be appended as part of the query
      # string. The api-version option is automatically appended.
      #
      def build_url(object_id = nil, links = false, property = nil, filter = {})
        url = File.join(Azure::Armrest::GRAPH_RESOURCE, configuration.tenant_id, service_name)
        url = File.join(url, object_id) if object_id

        if property
          if links
            url = File.join(url, "$links", property)
          else
            url = File.join(url, property)
          end
        end

        uri = Addressable::URI.parse(url)
        filter['api-version'] = api_version
        uri.query_values = filter

        uri.to_s
      end
    end
  end
end
