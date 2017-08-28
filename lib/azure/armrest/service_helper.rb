module Azure
  module Armrest
    module ServiceHelper
      private

      # Our custom error handler for Faraday that will convert a Faraday
      # using the exception map that we defined. The Faraday library does
      # not raise exceptions automatically by default.
      #
      class ErrorHandler < Faraday::Response::Middleware
        def on_complete(env)
          case env.status
          when 400..600
            klass = Azure::Armrest::EXCEPTION_MAP[env.status]
            klass ||= Azure::Armrest::Exception

            message = Nokogiri::XML.parse(env.body).xpath("//Code/text()")[0].to_s
            message = env.body if message.empty?

            raise klass.new(env.status, message, env.reason_phrase)
          end
        end

        def response_values(env)
          {:status => env.status, :headers => env.response_headers, :body => env.body}
        end
      end

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
            f.use ErrorHandler
            f.adapter Faraday.default_adapter
            f.response :detailed_logger, configuration.log if configuration.log
          end

          response = connection.send(http_method) do |req|
            req.body = body
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
