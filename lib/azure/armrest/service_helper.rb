module Azure
  module Armrest
    module ServiceHelper
      private

      def rest_execute(url, body = nil, http_method = :get, encode = true)
        url = encode ? Addressable::URI.encode(url) : url
        headers = {:accept => 'application/json', :content_type => 'application/json'}
        configuration.token.request(http_method, url, :body => body, :headers => headers).response
      end

      def rest_get(url)
        rest_execute(url)
      end

      def rest_get_without_encoding(url)
        rest_execute(url, nil, :get, false)
      end

      def rest_put(url, body = '')
        rest_execute(url, body, :put)
      end

      def rest_post(url, body = '')
        rest_execute(url, body, :post)
      end

      def rest_patch(url, body = '')
        rest_execute(url, body, :patch)
      end

      def rest_delete(url)
        rest_execute(url, nil, :delete)
      end

      def rest_head(url)
        rest_execute(url, nil, :head)
      end
    end
  end
end
