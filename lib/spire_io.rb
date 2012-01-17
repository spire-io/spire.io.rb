gem "excon"
require "excon"
gem "json"
require "json"

require "requestable"

class Spire

	#How many times we will try to create a channel or subscription after getting a 409
  RETRY_CREATION_LIMIT = 3

  include Requestable

  define_request(:discover) do
    {
      :method => :get,
      :url => @url,
      :headers => {"Accept" => "application/json"}
    }
  end

  define_request(:start) do |key|
    {
      :method => :post,
      :url => @description["resources"]["sessions"]["url"],
      :body => {:key => key}.to_json,
      :headers => {
        "Accept" => mediaType("session"),
        "Content-Type" => mediaType("account")
      }
    }
  end

  define_request(:login) do |email, password|
    {
      :method => :post,
      :url => @description["resources"]["sessions"]["url"],
      :body => { :email => email, :password => password }.to_json,
      :headers => {
        "Accept" => mediaType("session"),
        "Content-Type" => mediaType("account")
      }
    }
  end

  define_request(:register) do |info|
    {
      :method => :post,
      :url => @description["resources"]["accounts"]["url"],
      :body => {
        :email => info[:email],
        :password => info[:password],
        :password_confirmation => info[:password_confirmation]
      }.to_json,
      :headers => { 
        "Accept" => mediaType("session"),
        "Content-Type" => mediaType("account")
      }
    }
  end

  define_request(:session) do
    {
      :method => :get,
      :url => @session["url"],
      :headers => {
        "Accept" => mediaType("session"),
        "Authorization" => "Capability #{@session["capability"]}"
      }
    }
  end

  define_request(:password_reset) do |email|
    {
      :method => :post,
      :url => @description["resources"]["accounts"]["url"],
      :body => ""
    }
  end

  define_request(:delete_account) do
    {
      :method => :delete,
      :url => @resources["account"]["url"],
      :headers => { 
        "Accept" => mediaType("account"),"Content-Type" => mediaType("account"),
        "Authorization" =>
          "Capability #{@resources["account"]["capability"]}"
      }
    }
  end
  
  define_request(:update_account) do |info|
    {
      :method => :put,
      :url => @resources["account"]["url"],
      :body => info.to_json,
      :headers => {
        "Accept" => mediaType("account"),"Content-Type" => mediaType("account"),
        "Authorization" => "Capability #{@resources["account"]["capability"]}" 
      }
    }
  end

  define_request(:create_channel) do |name|
    {
      :method => :post,
      :url => @resources["channels"]["url"],
      :body => { :name => name }.to_json,
      :headers => {
        "Authorization" =>
          "Capability #{@resources["channels"]["capability"]}",
        "Accept" => mediaType("channel"),
        "Content-Type" => mediaType("channel")
      }
    }
  end

  define_request(:channels) do
    {
      :method => :get,
      :url => @resources["channels"]["url"],
      :headers => {
        "Authorization" =>
          "Capability #{@resources["channels"]["capability"]}",
        "Accept" => mediaType("channels"),
      }
    }
  end

  define_request(:subscribe) do |subscription_name, channels|
    {
      :method => :post,
      :url => @resources["subscriptions"]["url"],
      :body => {
        :channels => channels.flatten.map { |name| self[name].url },
        :name => subscription_name
      }.to_json,
      :headers => {
        "Authorization" => "Capability #{@resources["subscriptions"]["capability"]}",
        "Accept" => mediaType("subscription"),
        "Content-Type" => mediaType("subscription")
      }
    }
  end

  define_request(:billing) do
    {
      :method => :get,
      :url => @description["resources"]["billing"]["url"],
      :headers => {
        "Accept" => "application/json"
      }
    }
  end

  define_request(:billing_subscription) do |info|
    {
      :method => :put,
      :url => @resources["account"]["billing"]["url"],
      :body => info.to_json,
      :headers => {
        "Accept" => mediaType("account"),"Content-Type" => mediaType("account"),
        "Authorization" => "Capability #{@resources["account"]["billing"]["capability"]}"
      }
    }
  end

  define_request(:billing_invoices) do
    {
      :method => :get,
      :url => @resources["account"]["billing"]["invoices"]["url"],
      :headers => {
        "Accept" => "application/json",
        "Authorization" => "Capability #{@resources["account"]["billing"]["invoices"]["capability"]}"
      }
    }
  end

  define_request(:billing_invoices_upcoming) do
    {
      :method => :get,
      :url => @resources["account"]["billing"]["invoices"]["upcoming"]["url"],
      :headers => {
        "Accept" => "application/json",
        "Authorization" => "Capability #{@resources["account"]["billing"]["invoices"]["upcoming"]["capability"]}"
      }
    }
  end

  attr_accessor :client, :channels, :session, :resources
  
  def initialize(url="https://api.spire.io")
    @client = Excon
    @url = url
    @channels = {}
    @subscriptions = {}
    @channel_error_counts = {}
    @subscription_error_counts = {}
    # @headers = { "User-Agent" => "Ruby spire.io client" }
    # @timeout = 1
    discover
  end

  def key
    @resources["account"]["key"]
  end
  
  def mediaType(name)
    @description["schema"]["1.0"][name]["mediaType"]
  end
  
  def discover
    response = request(:discover)
    raise "Error during discovery: #{response.status}" if response.status != 200
    @description = JSON.parse(response.body)
    #pp @description["schema"]["1.0"]
    self
  end
 
  def start(key)
    response = request(:start, key)
    raise "Error starting a key-based session" if response.status != 201
    cache_session(JSON.parse(response.body))
    self
  end

  # Authenticates a session using a login and password
  def login(login, password)
    response = request(:login, login, password)
    raise "Error attemping to login:  (#{response.status}) #{response.body}" if response.status != 201
    cache_session(JSON.parse(response.body))
    self
  end

  # Register for a new spire account, and authenticates as the newly created account
  # @param [String] :email Email address of new account
  # @param [String] :password Password of new account
  # @param [String] :password_confirmation Password confirmation (optional)
  def register(info)
    response = request(:register, info)
    raise "Error attempting to register: (#{response.status}) #{response.body}" if response.status != 201
    cache_session(JSON.parse(response.body))
    self
  end

  def password_reset_request(email)
    response = request(:password_reset)
    unless response.status == 202
      raise "Error requesting password reset: (#{response.status}) #{response.body}"
    end
    response
  end


  # Deletes the currently authenticated account
  def delete_account
    request(:delete_account)
  end

  # Updates the current account with the new account information
  # See Spire docs for available settings
  def update(info)
    response = request(:update_account, info)
    raise "Error attempting to update account: (#{response.status}) #{response.body}" if response.status != 200
    @resources["account"] = JSON.parse(response.body)
    self
  end

	def retrieve_session
    response = request(:session)
    cache_session(JSON.parse(response.body))
    raise "Error reloading session: #{response.status}" if response.status != 200
    self
	end

  def cache_session(data)
    @session = data
    @resources = @session["resources"]
    retrieve_channels
  end

  def retrieve_channels
    response = request(:channels)
    unless response.status == 200
      raise "Error retrieving channels: (#{response.status}) #{response.body}"
    end
    cache_channels(JSON.parse(response.body))
  end
 
  def cache_channels(data)
    @channels = {}
    data.each do |name, properties|
      @channels[name] = Channel.new(self, properties)
      cache_channel_subscriptions(properties["subscriptions"])
    end
    @channels
  end

	def cache_channel_subscriptions(data)
		data.each do |name, properties|
			@subscriptions[name] = Subscription.new(self, properties)
		end
	end

  # Returns a channel object for the named channel
  # @param [String] name Name of channel returned
  # @return [Channel]
  def [](name)
    return @channels[name] if @channels[name]
    create_channel(name)
  end

  # Creates a channel on spire.  Returns a Channel object.  Note that this will
  # fail with a 409 if a channel with the same name exists.
  def create_channel(name)
  	@channel_error_counts[name] ||= 0
    response = request(:create_channel, name)
    return find_existing_channel(name) if response.status == 409 and @channel_error_counts[name] < RETRY_CREATION_LIMIT
    if !(response.status == 201 || response.status == 200)
      raise "Error creating or accessing a channel: (#{response.status}) #{response.body}" 
    end
    new_channel = Channel.new(self,JSON.parse(response.body))
    @channels[name] = new_channel
    new_channel
  end

	def find_existing_channel(name)
		@channel_error_counts[name] += 1
		retrieve_session
		self[name]
	end

  # Returns a subscription object for the given channels
  # @param [String] subscription_name Name for the subscription
  # @param [String] channels One or more channel names for the subscription to listen on
  # @return [Subscription]
  def subscribe(subscription_name, *channels)
  	@subscription_error_counts[subscription_name] ||= 0
  	return @subscriptions[subscription_name] if subscription_name and @subscriptions[subscription_name]
    response = request(:subscribe, subscription_name, channels)
    return find_existing_subscription(subscription_name, channels) if response.status == 409 and
    	@subscription_error_counts[subscription_name] < RETRY_CREATION_LIMIT
    raise "Error creating a subscription: (#{response.status}) #{response.body}" if !(response.status == 201 || response.status == 200)
    s = Subscription.new(self,JSON.parse(response.body))
    @subscriptions[s.name] = s
    s
  end
  alias :subscription :subscribe #For compatibility with other clients

	def find_existing_subscription(name, channels)
		@subscription_error_counts[name] += 1
		retrieve_session
		self.subscribe(name, *channels)
	end

  # Returns a billing object than contains a list of all the plans available
  # @param [String] info optional object description
  # @return [Billing]
  def billing(info=nil)
    response = request(:billing)
    raise "Error getting billing plans: #{response.status}" if response.status != 200
    Billing.new(self,JSON.parse(response.body))
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

  
  # Object representing a Spire channel
  #
  # You can get a channel object by calling [] on a Spire object
  # * spire = Spire.new
  # * spire.start("your api key")
  # * channel = spire["channel name"]
  class Channel
    include Requestable

    define_request(:publish) do |body|
      {
        :method => :post,
        :url => url,
        :body => body,
        :headers => {
          "Authorization" => "Capability #{@properties["capability"]}",
          "Accept" => mediaType("message"),
          "Content-Type" => mediaType("message")
        }
      }
    end

    define_request(:delete) do
      {
        :method => :delete,
        :url => url,
        :headers => {
          "Authorization" => "Capability #{capability}"
        }
      }
    end

    def initialize(spire, properties)
      @spire = spire
      @client = spire.client
      @properties = properties
    end
    
    def url
      @properties["url"]
    end
    
    def key
      @properties["key"]
    end

    def name
      @properties["name"]
    end

    def capability
      @properties["capability"]
    end

    def delete
      response = request(:delete)
      raise "Error deleting a channel" if response.status != 204
    end

    # Obtain a subscription for the channel
    # @param [String] subscription_name Name of the subscription
    # @return [Subscription]
    def subscribe(subscription_name = nil)
      @spire.subscribe(subscription_name, self.name)
    end

    #Publishes a message to the channel
    # @param [String] message Message to be posted
    # @return [Hash] response from the server
    def publish(message)
      response = request(:publish, {:content => message}.to_json)
      raise "Error publishing a message: (#{response.status}) #{response.body}" if response.status != 201
      JSON.parse(response.body)
    end

    def mediaType(name)
      @spire.mediaType(name)
    end
  
  end
  
  # The subscription class represents a read connection to a Spire channel
  #
  # You can get a subscription by calling subscribe on a spire object with the name of the channel or
  # by calling subscribe on a channel object
  #
  # * spire = Spire.new
  # * spire.start("your api key")
  # *THEN*
  # * subscription = spire.subscribe("subscription name", "channel name")
  # *OR*
  # * channel = spire["channel name"]
  # * subscription = channel.subscribe("subscription name")
  class Subscription
    include Requestable

    define_request(:listen) do |options|
      timeout = options[:timeout]||30
      delay = options[:delay]||0
      order_by = options[:order_by]||'desc'
      {
        :method => :get,
        :url => @properties["url"],
        :query => {
          "timeout" => timeout,
          "last-message" => @last||'0',
          "order-by" => order_by,
          "delay" => delay
        },
        :headers => {
          "Authorization" => "Capability #{@properties["capability"]}",
          "Accept" => mediaType("events")
        }
      }
    end

    define_request(:delete) do
      {
        :method => :delete,
        :url => url,
        :headers => {
          "Authorization" => "Capability #{capability}"
        }
      }
    end

    attr_accessor :messages, :last
    
    def initialize(spire,properties)
      @spire = spire
      @client = spire.client
      @properties = properties
      @messages = []
      @listening_thread = nil
      @listeners = {}
      @listening_threads = {}
      @listener_mutex = Mutex.new
      @listener_thread_mutex = Mutex.new
    end

    def key
      @properties["key"]
    end

    def name
      @properties["name"]
    end

    def capability
      @properties["capability"]
    end

    def url
      @properties["url"]
    end

    def delete
      response = request(:delete)
      raise "Error deleting a subscription" if response.status != 204
    end

    # Adds a listener (ruby block) to be called each time a message is received on the channel
    #
    # You must call #start_listening to actually start listening for messages
    # @note Listeners are executed in their own thread, so practice proper thread safety!
    # @param [String] name Name for the listener.  One will be generated if not provided
    # @return [String] Name of the listener
    def add_listener(listener_name = nil, &block)
      @listener_mutex.synchronize do
        while !listener_name
          new_name = "Listener-#{rand(9999999)}"
          listener_name = new_name unless @listeners.has_key?(new_name)
        end
        @listeners[listener_name] = block
      end
      listener_name
    end

    # Removes a listener by name
    #
    # @param [String] name Name of the listener to remove
    # @param [Boolean] kill_current_threads Kill any currently running threads of the removed listener
    # @return [Proc] Listener that was removed
    def remove_listener(name, kill_current_threads = true)
      l = nil #scope
      @listener_mutex.synchronize do
        l = @listeners.delete(name)
      end
      kill_listening_threads(name) if kill_current_threads
      l
    end

    # Removes all current listeners
    # @param [Boolean] kill_current_threads Kill any currently running threads of the removed listener.
    def remove_all_listeners(kill_current_threads = true)
      @listener_mutex.synchronize do
        @listeners = {}
      end
      kill_listening_threads if kill_current_threads
      true
    end

    # Starts the listening thread.  This must be called to enable any listeners you have added.
    #
    # You can continue to add more listeners after starting the listening process
    # @note Will raise an exception if listening has already been started
    def start_listening
      raise "Already listening" if @listening_thread
      @listening_thread = Thread.new {
        while true
          new_messages = self.listen
          next unless new_messages.size > 0
          current_listeners.each do |name, listener|
            new_messages.each do |m|
              thread = Thread.new {
                begin
                  listener.call(m)
                rescue
                  puts "Error while running listener #{name}: #{$!.inspect}"
                  puts $!.backtrace.join("\n")
                end
              }
              @listener_thread_mutex.synchronize do
                @listening_threads[name] ||= []
                @listening_threads[name] << thread
              end
            end
          end
        end
      }
    end

    # Stops the listening process
    # @param [Boolean] kill_current_threads Kills any currently running listener threads
    def stop_listening(kill_current_threads = true)
      @listener_thread_mutex.synchronize do
        @listening_thread.kill if @listening_thread
        @listening_thread = nil
      end
      kill_listening_threads if kill_current_threads
    end

    # Kills any currently executing listeners
    # @param [String] name_to_kill Kill only currently executing listeners that have this name
    def kill_listening_threads(name_to_kill = nil)
      @listener_thread_mutex.synchronize do
        @listening_threads.each do |name, threads|
          next if name_to_kill and name_to_kill != name
          threads.each {|t| t.kill }
          @listening_threads[name] = []
        end
      end
    end

    # Listen (and block) for any new incoming messages.
    # @params [Hash] A hash of containing:
    #   [Integer] timeout Max time to wait for a new message before returning
    #   [String] order_by Either "desc" or "asc"
    # @return [Array] An array of messages received
    def listen(options={})
      response = request(:listen, options)
      raise "Error listening for messages: (#{response.status}) #{response.body}" if response.status != 200
      new_messages = JSON.parse(response.body)["messages"]
      @listener_mutex.synchronize do
        @last = new_messages.last["timestamp"] unless new_messages.empty?
        new_messages.map! { |m| m["content"] }
        @messages += new_messages
      end
      new_messages
    end

    def mediaType(name)
      @spire.mediaType(name)
    end

    private
    def current_listeners
      @listener_mutex.synchronize do #To prevent synch problems adding a new listener while looping
        @listeners.dup
      end
    end
  end

  # Object representing a Spire billing
  #
  # You can get all the billing plans by calling the method billing in Spire object
  # * spire = Spire.new
  # * billing = spire.billing()
  # * plans = billing.plans
  class Billing
    def initialize(spire,properties)
      @spire = spire
      @properties = properties
    end
    
    def url
      @properties["url"]
    end
    
    def plans
      @properties["plans"]
    end
  end
end
