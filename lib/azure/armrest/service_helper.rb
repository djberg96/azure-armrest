module Azure
  module Armrest
    module ServiceHelper
      private

      def rest_execute(url:, body: nil, http_method: :get, encode: true, headers: {})
        url = encode ? Addressable::URI.encode(url) : url
        headers[:accept] ||= 'application/json'
        headers[:content_type] ||= 'application/json'
        configuration.token.request(http_method, url, :body => body, :headers => headers).response
      end

      def rest_get(url, headers = {})
        rest_execute(url: url, headers: headers)
      end

      def rest_get_without_encoding(url, headers = {})
        rest_execute(url: url, encoding: false, headers: headers)
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
