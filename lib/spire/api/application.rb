require 'base64'
class Spire
  class API

    class Application < Resource
      attr_reader :resources

      def resource_name
        "application"
      end

      def initialize(spire, data)
        super
        @resources = data["resources"]
      end

      #Channels
      define_request(:create_channel) do |name, message_limit, message_ttl|
        collection = @resources["channels"]
        capability = collection["capabilities"]["create"]
        url = collection["url"]

        body = {
          :name => name,
          :message_limit => message_limit,
          :message_ttl => message_ttl
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

      define_request(:channels) do
        collection = @resources["channels"]
        capability = collection["capabilities"]["all"]
        url = collection["url"]
        {
          :method => :get,
          :url => url,
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

      #Subscriptions
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

      #Members
      define_request(:create_member) do |data|
        collection = @resources["members"]
        capability = collection["capabilities"]["create"]
        url = collection["url"]
        {
          :method => :post,
          :url => url,
          :body => data.to_json,
          :headers => {
            "Authorization" => "Capability #{capability}",
            "Accept" => @spire.mediaType("member"),
            "Content-Type" => @spire.mediaType("member")
          }
        }
      end

      define_request(:members) do
        collection = @resources["members"]
        capability = collection["capabilities"]["all"]
        url = collection["url"]
        {
          :method => :get,
          :url => url,
          :headers => {
            "Authorization" => "Capability #{capability}",
            "Accept" => @spire.mediaType("members"),
          }
        }
      end

      define_request(:member_by_email) do |email|
        collection = @resources["members"]
        capability = collection["capabilities"]["get_by_email"]
        url = collection["url"]
        request = {
          :method => :get,
          :url => url,
          :query => {:email => email},
          :headers => {
            "Authorization" => "Capability #{capability}",
            "Accept" => @spire.mediaType("member"),
          }
        }
      end

      define_request(:authenticate_with_post) do |data|
        collection = @resources["authentication"]
        url = collection["url"]
        request = {
          :method => :post,
          :url => url,
          :body => data.to_json,
          :headers => {
            "Accept" => @spire.mediaType("member"),
          }
        }
      end

      define_request(:authenticate) do |data|
        collection = @resources["members"]
        url = "#{collection["url"]}?email=#{data[:email]}"
        auth = Base64.encode64("#{data[:email]}:#{data[:password]}").gsub("\n", '')
        request = {
          :method => :get,
          :url => url,
          :headers => {
            "Accept" => @spire.mediaType("member"),
            "Authorization" => "Basic #{auth}"
          }
        }
      end

      #Authenticates with the application using basic auth
      def authenticate(email, password)
        response = request(:authenticate, {:email => email, :password => password})
        unless response.status == 200
          raise "Error authenticating for application #{self.name}: (#{response.status}) #{response.body}"
        end
        API::Member.new(@spire, response.data)
      end

      #Alternative application authentication, without using basic auth
      def authenticate_with_post(email, password)
        response = request(:authenticate_with_post, {:email => email, :password => password})
        unless response.status == 201
          raise "Error authenticating for application #{self.name}: (#{response.status}) #{response.body}"
        end
        API::Member.new(@spire, response.data)
      end

      def create_member(member_data)
        response = request(:create_member, member_data)
        unless response.status == 201
          raise "Error creating member for application #{self.name}: (#{response.status}) #{response.body}"
        end
        API::Member.new(@spire, response.data)
      end
      
      def members
        @members || members!
      end

      def members!
        response = request(:members)
        unless response.status == 200
          raise "Error getting members for application #{self.name}: (#{response.status}) #{response.body}"
        end
        @members = {}
        response.data.each do |email, properties|
          @members[email] = API::Member.new(@spire, properties)
        end
        @members
      end

      def get_member(member_email)
        response = request(:member_by_email, member_email)
        unless response.status == 200
          raise "Error finding member with email #{member_email}: (#{response.status}) #{response.body}"
        end
        properties = response.data[member_email]
        member = API::Member.new(@spire, properties)
        @members[member_email] = member if @members.is_a?(Hash)
        member
      end
      
      def create_channel(name, options={})
        message_limit = options[:message_limit]
        message_ttl = options[:message_ttl]
        response = request(:create_channel, name, message_limit, message_ttl)
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
      
      def get_channel(name)
        response = request(:channel_by_name, name)
        unless response.status == 200
          raise "Error finding channel with name #{name}: (#{response.status}) #{response.body}"
        end
        properties = response.data[name]
        channel = API::Channel.new(@spire, properties)
        @channels[name] = channel if @channels.is_a?(Hash)
        channel
      end
      
      def get_subscription(name)
        response = request(:subscription_by_name, name)
        unless response.status == 200
          raise "Error finding subscription with name #{name}: (#{response.status}) #{response.body}"
        end
        properties = response.data[name]
        sub = API::Subscription.new(@spire, properties)
        @subscriptions[name] = sub if @subscriptions.is_a?(Hash)
        sub
      end
    end
  end
end
