class Spire
  class API

    class Resource
      include Requestable

      define_request(:get) do
        {
          :method => :get,
          :url => @url,
          :headers => {
            "Authorization" => "Capability #{@capability}",
            "Accept" => media_type
          }
        }
      end

      define_request(:update) do |properties|
        {
          :method => :put,
          :url => @url,
          :body => properties.to_json,
          :headers => {
            "Authorization" => "Capability #{@capability}",
            "Accept" => media_type,
            "Content-Type" => media_type
          }
        }
      end

      define_request(:delete) do
        {
          :method => :delete,
          :url => @url,
          :headers => { 
            "Authorization" => "Capability #{@capability}",
            "Accept" => media_type,
            "Content-Type" => media_type,
          }
        }
      end
  
      attr_reader :url, :capability, :properties

      def initialize(spire, data)
        @spire = spire
        @client = spire.client
        @url = data["url"]
        @capability = data["capability"]
        @properties = data
      end

      def method_missing(name, *args)
        if description = schema["properties"][name.to_s]
          if description["url"]
            # if the schema for this property has a url,
            # then we don't want magic behavior
            super
          else
            properties[name.to_s]
          end
        else
          super
        end
      end

      def inspect
        "#<#{self.class.name}:0x#{object_id.to_s(16)}>"
      end

      def get
        response = request(:get)
        unless response.status == 200
          raise "Error retrieving #{self.class.name}: (#{response.status}) #{response.body}"
        end
        @properties = API.deserialize(response.body)
        self
      end

      def update(properties)
        response = request(:update, properties)
        unless response.status == 200
          raise "Error updating #{self.class.name}: (#{response.status}) #{response.body}"
        end
        @properties = API.deserialize(response.body)
      end

      def delete
        response = request(:delete)
        unless response.status == 204
          raise "Error deleting #{self.class.name}: (#{response.status}) #{response.body}"
        end
        true
      end

      def schema
        @spire.schema[resource_name]
      end

      def media_type
        schema["mediaType"]
      end
    end


    class Account < Resource
      def resource_name
        "account"
      end


      define_request(:billing_subscription) do |info|
        billing = properties["billing"]
        {
          :method => :put,
          :url => billing["url"],
          :body => info.to_json,
          :headers => {
            "Accept" => mediaType("account"),"Content-Type" => mediaType("account"),
            "Authorization" => "Capability #{billing["capability"]}"
          }
        }
      end

      define_request(:billing_invoices) do
        invoices = properties["billing"]["invoices"]
        {
          :method => :get,
          :url => invoices["url"],
          :headers => {
            "Accept" => "application/json",
            "Authorization" => "Capability #{invoices["capability"]}"
          }
        }
      end

      define_request(:billing_invoices_upcoming) do
        upcoming = properties["billing"]["invoices"]["upcoming"]
        {
          :method => :get,
          :url => upcoming["url"],
          :headers => {
            "Accept" => "application/json",
            "Authorization" => "Capability #{upcoming["capability"]}"
          }
        }
      end

      # Updates and subscribe the account to a billing plan
      # @param [Object] info data containing billing description
      # @return [Account]
      def billing_subscription(info)
        response = request(:billing_subscription)
        raise "Error attempting to update account billing: (#{response.status}) #{response.body}" if response.status != 200
        @resources["account"] = JSON.parse(response.body)
        self
      end


    end

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

    class Subscription < Resource
      attr_reader :last
      def resource_name
        "subscription"
      end

      define_request(:messages) do |options|
        {
          :method => :get,
          :url => @url,
          :query => {
            "timeout" => options[:timeout],
            "last-message" => options[:last],
            "order-by" => options[:order_by],
            "delay" => options[:delay]
          },
          :headers => {
            "Authorization" => "Capability #{@capability}",
            "Accept" => @spire.mediaType("events")
          }
        }
      end

      def retrieve_messages(options={})
        options[:last] ||= "0"
        options[:delay] ||= 0
        options[:order_by] ||= "desc"

        response = request(:messages, options)
        message_data = API.deserialize(response.body)
        unless response.status == 200
          raise "Error retrieving messages from #{self.class.name}: (#{response.status}) #{response.body}"
        end
        messages = message_data["messages"]
        unless messages.empty?
          @last = messages.last["timestamp"]
        end
        messages
      end

      def poll(options={})
        # timeout option of 0 means no long poll,
        # so we force it here.
        options[:timeout] = 0
        retrieve_messages(options)
      end

      def long_poll(options={})
        options[:timeout] ||= 30
        options[:last] = @last
        retrieve_messages(options)
      end

      def listen(options={})
        loop do
          break unless yield(long_poll(options))
        end
      end

    end

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

      def create_channel(name)
        response = request(:create_channel, name)
        properties = API.deserialize(response.body)
        API::Channel.new(@spire, properties)
      end

      def create_subscription(name, channel_names)
        channel_urls = channel_names.flatten.map { |name| self.channels[name].url }
        response = request(:create_subscription, name, channel_urls)
        unless response.status == 201
          raise "Error creating Subscription: (#{response.status}) #{response.body}"
        end
        data = API.deserialize(response.body)
        API::Subscription.new(@spire, data)
      end

      def channels!
        response = request(:channels)
        unless response.status == 200
          raise "Error retrieving Channels: (#{response.status}) #{response.body}"
        end
        channels_data = API.deserialize(response.body)
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

    end

  end
end
