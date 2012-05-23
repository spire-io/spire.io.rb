class Spire
  class API

    # Object representing a Spire channel
    #
    # You can get a channel object by calling [] on a Spire object
    # * spire = Spire.new
    # * spire.start("your api secret")
    # * channel = spire["channel name"]
    class Channel < Resource

      attr_reader :resources

      def initialize(spire, data)
        super
        @resources = data["resources"]
      end

      def resource_name
        "channel"
      end

      define_request(:subscriptions) do
        collection = @resources["subscriptions"]
        capability = collection["capabilities"]["get_subscriptions"]
        url = collection["url"]
        {
          :method => :get,
          :url => url,
          :headers => {
            "Authorization" => "Capability #{capability}",
            "Accept" => @api.mediaType("subscriptions"),
          }
        }
      end

      define_request(:publish) do |string|
        {
          :method => :post,
          :url => @url,
          :body => string,
          :headers => {
            "Authorization" => "Capability #{@capabilities["publish"]}",
            "Accept" => @api.mediaType("message"),
            "Content-Type" => @api.mediaType("message")
          }
        }
      end

      define_request(:subscribe) do |name|
        collection = @resources["subscriptions"]
        capability = collection["capabilities"]["create"]
        url = collection["url"]
        {
          :method => :post,
          :url => url,
          :body => {:name => name}.to_json,
          :headers => {
            "Authorization" => "Capability #{capability}",
            "Accept" => @api.mediaType("subscription"),
            "Content-Type" => @api.mediaType("subscription")
          }
        }
      end

      def subscriptions
        @subscriptions ||= subscriptions!
      end

      def subscriptions!
        response = request(:subscriptions)
        unless response.status == 200
          raise "Error getting subscriptions to #{self.class.name}: (#{response.status}) #{response.body}"
        end
        @subscriptions = {}
        response.data.each do |name, properties|
          @subscriptions[name] = API::Subscription.new(@api, properties)
        end
        @subscriptions
      end

      def publish(content)
        body = {:content => content}.to_json
        response = request(:publish, body)
        unless response.status == 201
          raise "Error publishing to #{self.class.name}: (#{response.status}) #{response.body}"
        end
        API::Message.new(@api, response.data)
      end

      def subscribe(name = nil)
        response = request(:subscribe, name)
        unless response.status == 201
          raise "Error creating subscription for #{self.name}: (#{response.status}) #{response.body}"
        end
        API::Subscription.new(@api, response.data)
      end
    end
  end
end
