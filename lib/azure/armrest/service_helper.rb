module Azure
  module Armrest
    module ServiceHelper
      private

      def rest_execute(url:, body: nil, http_method: :get, encode: true, use_token: true, headers: {})
        url = encode ? Addressable::URI.encode(url) : url

        headers = headers.transform_keys { |key| key.to_s.tr('-', '_').downcase.to_sym }
        headers = headers.transform_values{ |value| value.to_s }

        headers[:accept] ||= 'application/json'
        headers[:content_type] ||= 'application/json'

        # For some requests we don't want to use the client token, and instead
        # want to make a plain request. This is typically done for storage account
        # requests. In these cases, we still want to retain the configuration
        # options, such as proxy information.

        if use_token
          configuration.token.request(http_method.to_sym, url, :body => body, :headers => headers).response
        else
          options = configuration.token.client.options[:connection_opts]
          options.merge!(:headers => headers)

          connection = Faraday.new(url, options) do |f|
            f.response :detailed_logger, configuration.log if configuration.log
            f.adapter Faraday.default_adapter
          end

          response = connection.send(http_method) do |req|
            req.body = body
          end

          unless response.success?
            message = Nokogiri::XML.parse(response.body).xpath("//Code/text()")[0].to_s
            message = response.body if message.empty?
            error_class = Azure::Armrest::EXCEPTION_MAP[response.status]
            error_class ||= Azure::Armrest::ApiException
            raise error_class.new(response.status, message, response.reason_phrase)
          end

          response
        end
      end

      def rest_get(url, headers = {})
        rest_execute(url: url, headers: headers)
      end

      def rest_get_without_encoding(url, headers = {})
        rest_execute(url: url, encode: false, headers: headers)
      end

      def rest_put(url, body = '', headers = {})
        rest_execute(url: url, body: body, http_method: :put, headers: headers)
      end

      def rest_post(url, body = '', headers = {})
        rest_execute(url: url, body: body, http_method: :post, headers: headers)
      end

      def rest_patch(url, body = '', headers = {})
        rest_execute(url: url, body: body, http_method: :patch, headers: headers)
      end

      def rest_delete(url, headers = {})
        rest_execute(url: url, http_method: :delete, headers: headers)
      end

      def rest_head(url, headers = {})
        rest_execute(url: url, http_method: :head, headers: headers)
      end
    end
  end
end
