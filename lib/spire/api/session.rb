class Spire
  class API

    class Session
      include Requestable

      define_request(:channels) do
        collection = @resources["channels"]
        capability = collection["capabilities"]["all"]
        url = collection["url"]
        request = {
          :method => :get,
          :url => collection["url"],
          :headers => {
            "Authorization" => "Capability #{capability}",
            "Accept" => @spire.mediaType("channels"),
          }
        }
      end

      define_request(:channel_by_name) do |name|
        collection = @resources["channels"]
        capability = collection["capabilities"]["get_by_name"]
        url = collection["url"]
        request = {
          :method => :get,
          :url => url,
          :query => {:name => name},
          :headers => {
            "Authorization" => "Capability #{capability}",
            "Accept" => @spire.mediaType("channels"),
          }
        }
      end

      define_request(:create_channel) do |name, limit, ttl|
        collection = @resources["channels"]
        capability = collection["capabilities"]["create"]
        url = collection["url"]

        body = {
          :name => name,
          :limit => limit,
          :ttl => ttl
        }.to_json
        {
          :method => :post,
          :url => url,
          :body => body,
          :headers => {
            "Authorization" => "Capability #{capability}",
            "Accept" => @spire.mediaType("channel"),
            "Content-Type" => @spire.mediaType("channel")
          }
        }
      end

      define_request(:subscriptions) do
        collection = @resources["subscriptions"]
        capability = collection["capabilities"]["all"]
        url = collection["url"]
        {
          :method => :get,
          :url => url,
          :headers => {
            "Authorization" => "Capability #{capability}",
            "Accept" => @spire.mediaType("subscriptions"),
          }
        }
      end

      define_request(:create_subscription) do |subscription_name, channel_urls|
        collection = @resources["subscriptions"]
        capability = collection["capabilities"]["create"]
        url = collection["url"]
        {
          :method => :post,
          :url => url,
          :body => {
            :channels => channel_urls,
            :name => subscription_name
          }.to_json,
          :headers => {
            "Authorization" => "Capability #{capability}",
            "Accept" => @spire.mediaType("subscription"),
            "Content-Type" => @spire.mediaType("subscription")
          }
        }
      end

      define_request(:subscription_by_name) do |name|
        collection = @resources["subscriptions"]
        capability = collection["capabilities"]["get_by_name"]
        url = collection["url"]
        request = {
          :method => :get,
          :url => url,
          :query => {:name => name},
          :headers => {
            "Authorization" => "Capability #{capability}",
            "Accept" => @spire.mediaType("subscriptions"),
          }
        }
      end

      define_request(:applications) do
        collection = @resources["applications"]
        capability = collection["capabilities"]["all"]
        request = {
          :method => :get,
          :url => collection["url"],
          :headers => {
            "Authorization" => "Capability #{capability}",
            "Accept" => @spire.mediaType("applications"),
          }
        }
      end

      define_request(:application_by_name) do |name|
        collection = @resources["applications"]
        capability = collection["capabilities"]["get_by_name"]
        url = collection["url"]
        request = {
          :method => :get,
          :url => url,
          :query => {:name => name},
          :headers => {
            "Authorization" => "Capability #{capability}",
            "Accept" => @spire.mediaType("applications"),
          }
        }
      end

      define_request(:create_application) do |name|
        collection = @resources["applications"]
        {
          :method => :post,
          :url => collection["url"],
          :body => {
            :name => name,
          }.to_json,
          :headers => {
            "Authorization" => "Capability #{collection["capabilities"]["create"]}",
            "Accept" => @spire.mediaType("application"),
            "Content-Type" => @spire.mediaType("application")
          }
        }
      end

      attr_reader :url, :resources, :schema, :capabilities, :capability

      def initialize(spire, data)
        @spire = spire
        @client = spire.client
        @schema = spire.schema["session"]
        @url = data["url"]
        @capabilities = data["capabilities"]
        @resources = data["resources"]
      end

      def account
        @account ||= account!
      end

      def account!
        @account = API::Account.new(@spire, @resources["account"]).get
      end

      def create_channel(name, options={})
        limit = options[:limit]
        ttl = options[:ttl]
        response = request(:create_channel, name, limit, ttl)
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
        subscription = API::Subscription.new(@spire, data) 
        if subscription_name
          subscriptions[data["name"]] = subscription
        end
        subscription
      end

      def get_application(name)
        response = request(:application_by_name, name)
        unless response.status == 200
          raise "Error finding application with name #{name}: (#{response.status}) #{response.body}"
        end
        properties = response.data[name]
        app = API::Application.new(@spire, properties)
        @applications[name] = app if @applications.is_a?(Hash)
        app
      end

      def create_application(name)
        response = request(:create_application, name)
        unless response.status == 201
          raise "Error creating Application (#{response.status}) #{response.body}"
        end
        properties = response.data
        applications[name] = API::Application.new(@spire, properties)
      end

      def applications!
        response = request(:applications)
        unless response.status == 200
          raise "Error retrieving Applications (#{response.status}) #{response.body}"
        end
        applications_data = response.data
        @applications = {}
        applications_data.each do |name, properties|
          @applications[name] = API::Application.new(@spire, properties)
        end
        @applications
      end

      def applications
        @applications ||= applications!
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

      def subscriptions
        @subscriptions ||= subscriptions!
      end

      def subscriptions!
        response = request(:subscriptions)
        unless response.status == 200
          raise "Error retrieving Subscriptions: (#{response.status}) #{response.body}"
        end
        @subscriptions = {}
        response.data.each do |name, properties|
          @subscriptions[name] = API::Subscription.new(@spire, properties)
        end
        @subscriptions
      end

    end

  end
end
