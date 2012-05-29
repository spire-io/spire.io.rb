require 'base64'
class Spire
  class API

    class Application < Resource
      attr_reader :resources

      def resource_name
        "application"
      end

      def initialize(api, data)
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
            "Accept" => @api.mediaType("channel"),
            "Content-Type" => @api.mediaType("channel")
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
            "Accept" => @api.mediaType("channels"),
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
            "Accept" => @api.mediaType("channels"),
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
            "Accept" => @api.mediaType("subscriptions"),
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
            "Accept" => @api.mediaType("subscription"),
            "Content-Type" => @api.mediaType("subscription")
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
            "Accept" => @api.mediaType("subscriptions"),
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
            "Accept" => @api.mediaType("member"),
            "Content-Type" => @api.mediaType("member")
          }
        }
      end

      define_request(:members) do |options|
        options ||= {}
        collection = @resources["members"]
        capability = collection["capabilities"]["all"]
        url = collection["url"]
        {
          :method => :get,
          :url => url,
          :query => options,
          :headers => {
            "Authorization" => "Capability #{capability}",
            "Accept" => @api.mediaType("members"),
          }
        }
      end

      define_request(:member_by_login) do |login|
        collection = @resources["members"]
        capability = collection["capabilities"]["get_by_login"]
        url = collection["url"]
        request = {
          :method => :get,
          :url => url,
          :query => {:login => login},
          :headers => {
            "Authorization" => "Capability #{capability}",
            "Accept" => @api.mediaType("member"),
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
            "Accept" => @api.mediaType("member"),
          }
        }
      end

      define_request(:authenticate) do |data|
        collection = @resources["members"]
        url = "#{collection["url"]}?login=#{data[:login]}"
        auth = Base64.encode64("#{data[:login]}:#{data[:password]}").gsub("\n", '')
        request = {
          :method => :get,
          :url => url,
          :headers => {
            "Accept" => @api.mediaType("member"),
            "Authorization" => "Basic #{auth}"
          }
        }
      end

      define_request(:reset_member_password) do |email|
        url = @resources["members"]["url"]
        {
          :method => :post,
          :url => url,
          :query => { :email => email },
          :body => ""
        }
      end

      #Authenticates with the application using basic auth
      def authenticate(login, password)
        response = request(:authenticate, {:login => login, :password => password})
        unless response.status == 200
          raise "Error authenticating for application #{self.name}: (#{response.status}) #{response.body}"
        end
        API::Member.new(@api, response.data)
      end

      #Alternative application authentication, without using basic auth
      def authenticate_with_post(login, password)
        response = request(:authenticate_with_post, {:login => login, :password => password})
        unless response.status == 201
          raise "Error authenticating for application #{self.name}: (#{response.status}) #{response.body}"
        end
        API::Member.new(@api, response.data)
      end

      #If you do not give a new password, you will get back an authenticated member but have to change
      #the password at a later time (using the returned capability)
      def reset_password(reset_key, new_password = nil)
        hsh = {:reset_key => reset_key}
        hsh[:password] = new_password if new_password
        response = request(:authenticate_with_post, hsh)
        unless response.status == 201
          raise "Error reseting password for application #{self.name}: (#{response.status}) #{response.body}"
        end
        API::Member.new(@api, response.data)
      end

      def create_member(member_data)
        response = request(:create_member, member_data)
        unless response.status == 201
          raise "Error creating member for application #{self.name}: (#{response.status}) #{response.body}"
        end
        API::Member.new(@api, response.data)
      end
      
      #Resets a members password based on email
      def request_member_password_reset(email)
        response = request(:reset_member_password, email)
        unless response.status == 202
          raise "Error reseting password for email #{email} in app #{self.name}: (#{response.status}) #{response.body}"
        end
        true
      end

      def members(options = {})
        @members ||= {}
        @members[options.hash] || members!(options)
      end

      def members!(options = {})
        response = request(:members, options)
        unless response.status == 200
          raise "Error getting members for application #{self.name}: (#{response.status}) #{response.body}"
        end
        @members ||= {}
        hsh_key = options.hash
        @members[hsh_key] ||= {}
        response.data.each do |login, properties|
          @members[hsh_key][login] = API::Member.new(@api, properties)
        end
        @members[hsh_key]
      end

      def get_member(member_login)
        response = request(:member_by_login, member_login)
        unless response.status == 200
          raise "Error finding member with login #{member_login}: (#{response.status}) #{response.body}"
        end
        properties = response.data[member_login]
        member = API::Member.new(@api, properties)
        @members[member_login] = member if @members.is_a?(Hash)
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
        channels[name] = API::Channel.new(@api, properties)
      end

      def create_subscription(subscription_name, channel_names)
        channel_urls = channel_names.flatten.map { |name| self.channels[name].url rescue nil }.compact
        response = request(:create_subscription, subscription_name, channel_urls)
        unless response.status == 201
          raise "Error creating Subscription: (#{response.status}) #{response.body}"
        end
        data = response.data
        subscription = API::Subscription.new(@api, data) 
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
          @channels[name] = API::Channel.new(@api, properties)
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
          @subscriptions[name] = API::Subscription.new(@api, properties)
        end
        @subscriptions
      end
      
      def get_channel(name)
        response = request(:channel_by_name, name)
        unless response.status == 200
          raise "Error finding channel with name #{name}: (#{response.status}) #{response.body}"
        end
        properties = response.data[name]
        channel = API::Channel.new(@api, properties)
        @channels[name] = channel if @channels.is_a?(Hash)
        channel
      end
      
      def get_subscription(name)
        response = request(:subscription_by_name, name)
        unless response.status == 200
          raise "Error finding subscription with name #{name}: (#{response.status}) #{response.body}"
        end
        properties = response.data[name]
        sub = API::Subscription.new(@api, properties)
        @subscriptions[name] = sub if @subscriptions.is_a?(Hash)
        sub
      end
    end
  end
end
