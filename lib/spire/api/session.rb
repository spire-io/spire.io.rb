class Spire
  class API

    class Session
      include Requestable

      define_request(:account) do
        resource = @resources["account"]
        {
          :method => :get,
          :url => resource["url"],
          :headers => {
            "Authorization" => "Capability #{resource["capability"]}",
            "Accept" => @spire.mediaType("account")
          }
        }
      end

      define_request(:channels) do
        collection = @resources["channels"]
        {
          :method => :get,
          :url => collection["url"],
          :headers => {
            "Authorization" => "Capability #{collection["capability"]}",
            "Accept" => @spire.mediaType("channels"),
          }
        }
      end

      define_request(:create_channel) do |name|
        collection = @resources["channels"]
        {
          :method => :post,
          :url => collection["url"],
          :body => { :name => name }.to_json,
          :headers => {
            "Authorization" => "Capability #{collection["capability"]}",
            "Accept" => @spire.mediaType("channel"),
            "Content-Type" => @spire.mediaType("channel")
          }
        }
      end

      define_request(:create_subscription) do |subscription_name, channel_urls|
        collection = @resources["subscriptions"]
        {
          :method => :post,
          :url => collection["url"],
          :body => {
            :channels => channel_urls,
            :name => subscription_name
          }.to_json,
          :headers => {
            "Authorization" => "Capability #{collection["capability"]}",
            "Accept" => @spire.mediaType("subscription"),
            "Content-Type" => @spire.mediaType("subscription")
          }
        }
      end

      attr_reader :url, :resources, :schema, :capability

      def initialize(spire, data)
        @spire = spire
        @client = spire.client
        @schema = spire.schema["session"]
        @url = data["url"]
        @capability = data["capability"]
        @resources = data["resources"]
      end

      def account
        @account ||= account!
      end

      def account!
        @account = API::Account.new(@spire, @resources["account"]).get
      end

      def create_channel(name)
        response = request(:create_channel, name)
        unless response.status == 201
          raise "Error creating Channel: (#{response.status}) #{response.body}"
        end
        properties = response.data
        channels[name] = API::Channel.new(@spire, properties)
      end

      def create_subscription(subscription_name, channel_names)
        channel_urls = channel_names.flatten.map { |name| self.channels[name].url rescue nil }.compact
        response = request(:create_subscription, subscription_name, channel_urls)
        unless response.status == 201
          raise "Error creating Subscription: (#{response.status}) #{response.body}"
        end
        data = response.data
        subscriptions[data["name"]] = API::Subscription.new(@spire, data)
      end

      def channels!
        response = request(:channels)
        unless response.status == 200
          raise "Error retrieving Channels: (#{response.status}) #{response.body}"
        end
        channels_data = response.data
        @channels = {}
        channels_data.each do |name, properties|
          @channels[name] = API::Channel.new(@spire, properties)
        end
        @channels
      end

      def channels
        @channels ||= channels!
      end

       # Not yet in Spire API
      #define_request(:subscriptions) do
        #{
          #:method => :get,
          #:url => @resources["subscriptions"]["url"],
          #:headers => {
            #"Authorization" => "Capability #{@resources["subscriptions"]["capability"]}",
            #"Accept" => @spire.mediaType("subscription"),
          #}
        #}
      #end

     def subscriptions
        if @subscriptions
          @subscriptions
        else
          # TODO Fix this to use an API call once Spire supports it
          @subscriptions = {}
          channels.each do |name, channel|
            if subs = channel.properties["subscriptions"]
              subs.each do |key, sub|
                @subscriptions[key] = API::Subscription.new(@spire, sub)
              end
            end
          end
          @subscriptions
        end
      end

     def subscriptions!
       raise "unimplemented"
     end

    end

  end
end
