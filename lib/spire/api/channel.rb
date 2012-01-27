class Spire
  class API

    class Channel < Resource
      def resource_name
        "channel"
      end

      define_request(:publish) do |string|
        {
          :method => :post,
          :url => @url,
          :body => string,
          :headers => {
            "Authorization" => "Capability #{@capability}",
            "Accept" => @spire.mediaType("message"),
            "Content-Type" => @spire.mediaType("message")
          }
        }
      end

      def publish(content)
        body = {:content => content}.to_json
        response = request(:publish, body)
        unless response.status == 201
          raise "Error publishing to #{self.class.name}: (#{response.status}) #{response.body}"
        end
        message = response.data
      end

    end

  end
end
