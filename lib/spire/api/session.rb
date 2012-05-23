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
            "Accept" => @api.mediaType("channel"),
            "Content-Type" => @api.mediaType("channel")
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
            "Accept" => @api.mediaType("subscriptions"),
          }
        }
      end

      define_request(:create_subscription) do |options|
        name = options[:name]
        channel_urls = options[:channel_urls]
        expiration = options[:expiration]
        device_token = options[:device_token]
        notification_name = options[:notification_name]

        collection = @resources["subscriptions"]
        capability = collection["capabilities"]["create"]
        url = collection["url"]
        {
          :method => :post,
          :url => url,
          :body => {
            :channels => channel_urls,
            :name => name,
            :expiration => expiration,
            :device_token => device_token,
            :notification_name => notification_name
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
      
      define_request(:create_notification) do |options|
        collection = @resources["notifications"]
        capability = collection["capabilities"]["create"]
        url = collection["url"]
        {
          :method => :post,
          :url => url,
          :body => {
            :name => options[:name],
            :mode => options[:mode]
          }.to_json,
          :headers => {
            "Authorization" => "Capability #{capability}",
            "Accept" => @api.mediaType("notification"),
            "Content-Type" => @api.mediaType("notification")
          }
        }
      end
      
      define_request(:notifications) do
        collection = @resources["notifications"]
        capability = collection["capabilities"]["all"]
        url = collection["url"]
        {
          :method => :get,
          :url => url,
          :headers => {
            "Authorization" => "Capability #{capability}",
            "Accept" => @api.mediaType("notifications"),
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
            "Accept" => @api.mediaType("applications"),
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
            "Accept" => @api.mediaType("applications"),
          }
        }
      end

      define_request(:create_application) do |data|
        collection = @resources["applications"]
        {
          :method => :post,
          :url => collection["url"],
          :body => data.to_json,
          :headers => {
            "Authorization" => "Capability #{collection["capabilities"]["create"]}",
            "Accept" => @api.mediaType("application"),
            "Content-Type" => @api.mediaType("application")
          }
        }
      end

      attr_reader :url, :resources, :schema, :capabilities, :capability

      def initialize(api, data)
        @api = api
        @client = api.client
        @schema = api.schema["session"]
        @url = data["url"]
        @capabilities = data["capabilities"]
        @resources = data["resources"]

        @channel_error_counts = {}
        @application_error_counts = {}
        @subscription_error_counts = {}
        @notification_error_counts = {}
      end

      # Returns a channel object for the named channel
      # @param [String] name Name of channel returned
      # @return [Channel]
      def [](name)
        API::Channel.new(@api, channels[name] || find_or_create_channel(name))
      end

      def account
        @account ||= account!
      end

      def account!
        @account = API::Account.new(@api, @resources["account"]).get
      end

      def create_channel(name, options={})
        limit = options[:limit]
        ttl = options[:ttl]
        response = request(:create_channel, name, limit, ttl)
        unless response.status == 201
          raise "Error creating Channel: (#{response.status}) #{response.body}"
        end
        properties = response.data
        channels[name] = API::Channel.new(@api, properties)
      end

      # Creates a channel on spire.  Returns a Channel object.  Note that this will
      # fail with a 409 if a channel with the same name exists.
      def find_or_create_channel(name)
        @channel_error_counts[name] ||= 0

        begin
          return create_channel(name)
        # TODO custom error class for Conflict, which we can
        # then match here, instead of testing for error message
        rescue => error
          if error.message =~ /409/

            # Dear retry, I love you.  Affectionately, Matthew.
            if channel = channels![name]
              return channel
            else
              @channel_error_counts[name] += 1
              retry unless @channel_error_counts[name] >= RETRY_CREATION_LIMIT
            end

          else
            raise error
          end
        end
      end

      def create_subscription(subscription_name, channel_names, expiration=nil, device_token=nil, notification_name=nil, second_try=false)
        channel_urls = channel_names.flatten.map { |name| self.channels[name].url rescue nil }
        if channel_urls.size != channel_urls.compact.size
          if !second_try
            self.channels!
            return create_subscription(subscription_name, channel_names, expiration, device_token, notification_name, true)
          else
            channel_urls = channel_urls.compact
          end
        end
        response = request(:create_subscription, {
          :name => subscription_name,
          :channel_urls => channel_urls,
          :expiration => expiration,
          :device_token => device_token,
          :notification_name => notification_name
        })

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

      def get_application(name)
        response = request(:application_by_name, name)
        unless response.status == 200
          raise "Error finding application with name #{name}: (#{response.status}) #{response.body}"
        end
        properties = response.data[name]
        app = API::Application.new(@api, properties)
        @applications[name] = app if @applications.is_a?(Hash)
        app
      end

      def create_application(name, data = {})
        data[:name] = name
        response = request(:create_application, data)
        unless response.status == 201
          raise "Error creating Application (#{response.status}) #{response.body}"
        end
        properties = response.data
        applications[name] = API::Application.new(@api, properties)
      end

      def applications!
        response = request(:applications)
        unless response.status == 200
          raise "Error retrieving Applications (#{response.status}) #{response.body}"
        end
        applications_data = response.data
        @applications = {}
        applications_data.each do |name, properties|
          @applications[name] = API::Application.new(@api, properties)
        end
        @applications
      end

      def applications
        @applications ||= applications!
      end

      def create_notification(options={})
        response = request(:create_notification, options)
        unless response.status == 201
          raise "Error creating Notification: (#{response.status}) #{response.body}"
        end
        data = response.data
        notification = API::Notification.new(@api, data) 
        if options[:name]
          notifications[data["name"]] = notification
        end
        notification
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
      
      # Returns a subscription object for the given channels
      # @param [String] subscription_name Name for the subscription
      # @param [String] channels One or more channel names for the subscription to listen on
      # @return [Subscription]
      def subscribe(name, *channels)
        channels.each { |channel| self.find_or_create_channel(channel) }
        API::Subscription.new(@api,
          subscriptions[name] || find_or_create_subscription(name, *channels)
        )
      end
      
      def find_or_create_subscription(subscription_name, *channels)
        @subscription_error_counts[subscription_name] ||= 0
        begin
          return create_subscription(subscription_name, channels)
        rescue => error
          if error.message =~ /409/

            if subscription = subscriptions![subscription_name]
              return subscription
            else
              @subscription_error_counts[subscription_name] += 1
              retry unless @subscription_error_counts >= RETRY_CREATION_LIMIT
            end

          else
            raise error
          end
        end
      end

      alias :subscription :subscribe #For compatibility with other clients

      def notifications
        @notifications ||= notifications!
      end
      
      def notifications!
        response = request(:notifications)
        unless response.status == 200
          raise "Error retrieving Notifications: (#{response.status}) #{response.body}"
        end
        @notifications = {}
        response.data.each do |name, properties|
          @notifications[name] = API::Notification.new(@api, properties)
        end
        @notifications
      end

      def notification(name, mode="development")
        Notification.new(@api,
          @notifications[name] || find_or_create_notification(name, ssl_cert)
        )
      end
      
      def find_or_create_notification(notification_name, mode)
        @notification_error_counts[notification_name] ||= 0
        begin
          return create_notification(
              :name => notification_name,
              :mode => mode
            )
        rescue => error
          if error.message =~ /409/
          
            if notification = notification![notification_name]
              return notification
            else
              @notification_error_counts[notification_name] += 1
              retry unless @notification_error_counts >= RETRY_CREATION_LIMIT
            end
          
          else
            raise error
          end
        end
      end

      # Creates an application on spire.  Returns an Application object.  Will retry on a 409.
      # @param [String] Name of the application to find/create
      def find_or_create_application(name)
        @application_error_counts[name] ||= 0
        begin
          return create_application(name)
        # TODO custom error class for Conflict, which we can
        # then match here, instead of testing for error message
        rescue => error
          if error.message =~ /409/
            # Dear retry, I love you.  Affectionately, Matthew.
            if application = applications![name]
              return application
            else
              @application_error_counts[name] += 1
              retry unless @application_error_counts[name] >= RETRY_CREATION_LIMIT
            end
          else
            raise error
          end
        end
      end
    end
  end
end
