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
          :body => {:content => string}.to_json,
          :headers => {
            "Authorization" => "Capability #{@capability}",
            "Accept" => @spire.mediaType("message"),
            "Content-Type" => @spire.mediaType("message")
          }
        }
      end

      def publish(string)
        response = request(:publish, string)
        unless response.status == 201
          raise "Error publishing to #{self.class.name}: (#{response.status}) #{response.body}"
        end
        message = API.deserialize(response.body)
      end

    end

  end
end
