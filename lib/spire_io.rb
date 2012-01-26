gem "excon"
require "excon"
gem "json"
require "json"

require "spire/api"
require "requestable"

class Spire

	#How many times we will try to create a channel or subscription after getting a 409
  RETRY_CREATION_LIMIT = 3

  attr_accessor :api, :session, :resources
  
  def initialize(url="https://api.spire.io")
    @api = Spire::API.new(url)
    @url = url
    @channels = {}
    @subscriptions = {}
    @channel_error_counts = {}
    @subscription_error_counts = {}
    discover
  end

  def key
    @resources["account"]["key"]
  end
  
  def mediaType(name)
    @description["schema"]["1.0"][name]["mediaType"]
  end
  
  def discover
    @api.discover
    self
  end
 
  def start(key)
    @session = @api.create_session(key)
    self
  end

  # Authenticates a session using a login and password
  def login(login, password)
    @session = @api.login(login, password)
    self
  end

  # Register for a new spire account, and authenticates as the newly created account
  # @param [String] :email Email address of new account
  # @param [String] :password Password of new account
  # @param [String] :password_confirmation Password confirmation (optional)
  def register(info)
    @session = @api.create_account(info)
    self
  end

  def key
    @session.resources["account"]["key"]
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
    @session.account.delete
  end

  # Updates the current account with the new account information
  # See Spire docs for available settings
  def update(info)
    @session.account.update(info)
    #response = request(:update_account, info)
    #raise "Error attempting to update account: (#{response.status}) #{response.body}" if response.status != 200
    #@resources["account"] = JSON.parse(response.body)
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
    Channel.new(self, channels[name] || find_or_create_channel(name))
  end

  def channels
    @session.channels
  end

  # Creates a channel on spire.  Returns a Channel object.  Note that this will
  # fail with a 409 if a channel with the same name exists.
  def find_or_create_channel(name)
  	@channel_error_counts[name] ||= 0

    begin
      return @session.create_channel(name)
    # TODO custom error class for Conflict, which we can
    # then match here, instead of testing for error message
    rescue => error
      if error.message =~ /409/

        # Dear retry, I love you.  Affectionately, Matthew.
        if channel = @session.channels![name]
          return channel
        else
          @channel_error_counts[name] += 1
          retry unless @channel_error_counts >= RETRY_CREATION_LIMIT
        end

      else
        raise error
      end
    end
  end

  # Returns a subscription object for the given channels
  # @param [String] subscription_name Name for the subscription
  # @param [String] channels One or more channel names for the subscription to listen on
  # @return [Subscription]
  def subscribe(name, *channels)
    channels.each { |channel| self.find_or_create_channel(channel) }
    Subscription.new(
      @session.subscriptions[name] || find_or_create_subscription(name, *channels)
    )
  end

  def find_or_create_subscription(subscription_name, *channels)
  	@subscription_error_counts[subscription_name] ||= 0
    begin
      return @session.create_subscription(subscription_name, channels)
    rescue => error
      if error.message =~ /409/

        if subscription = @session.subscriptions![subscription_name]
          return subscription
        else
          retry unless @subscription_error_counts >= RETRY_CREATION_LIMIT
        end

      else
        raise error
      end
    end
  end

  alias :subscription :subscribe #For compatibility with other clients

	#Returns an array of subscription objects for all of this account's subscriptions
	#@return [Array]
	def subscriptions
		@session.subscriptions.values
	end

  # Returns a billing object than contains a list of all the plans available
  # @param [String] info optional object description
  # @return [Billing]
  def billing
    @api.billing
  end
  
  # Updates and subscribe the account to a billing plan
  # @param [Object] info data containing billing description
  # @return [Account]
  def billing_subscription(info)
    @session.account.billing_subscription(info)
    #response = request(:billing_subscription)
    #raise "Error attempting to update account billing: (#{response.status}) #{response.body}" if response.status != 200
    #@resources["account"] = JSON.parse(response.body)
    #self
  end


  require "delegate"
  # Object representing a Spire channel
  #
  # You can get a channel object by calling [] on a Spire object
  # * spire = Spire.new
  # * spire.start("your api key")
  # * channel = spire["channel name"]
  class Channel < SimpleDelegator
    def initialize(spire, channel)
      super(channel)
      @spire = spire
    end
    # Obtain a subscription for the channel
    # @param [String] subscription_name Name of the subscription
    # @return [Subscription]
    def subscribe(subscription_name = nil)
      @spire.subscribe(subscription_name, properties["name"])
    end

    # this is required because Delegator's method_missing relies
    # on the object having a method defined, but in this case
    # the API::Channel is also using method_missing
    def name
      __getobj__.name
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
  class Subscription < SimpleDelegator

    # this is required because Delegator's method_missing relies
    # on the object having a method defined, but in this case
    # the API::Subscription is also using method_missing
    def name
      __getobj__.name
    end

    # misnamed method, here for backompat.  Should be something like #get_messages,
    # because it only makes one request.
    def listen(options={})
      long_poll(options).map {|message| message["content"] }
    end

    # wraps the underlying Subscription#add_listener to
    # provided named listeners, threading, and a
    # stop_listening method.
    def add_listener(name=nil, &block)
      raise ArgumentError unless block_given?
      name ||= generate_listener_name
      listener = wrap_listener(&block)
      listeners[name] = listener
      __getobj__.add_listener(&listener)
    end

    def remove_listener(listener)
      if listener.is_a? String
        listener = listeners[listener]
      end
      __getobj__.listeners.delete(listener)
    end

    def wrap_listener(&block)
      lambda do |message|
        Thread.new do
          # Messages received after a call to stop_listening
          # will not be processed.
          yield message["content"] if @listening
        end
      end
    end

    def listeners
      @listeners ||= {}
    end

    def generate_listener_name
      listener_name = nil
      while !listener_name
        new_name = "Listener-#{rand(9999999)}"
        listener_name = new_name unless listeners.has_key?(new_name)
      end
      listener_name
    end

    def start_listening(options={})
      @listening = true
      Thread.new do
        long_poll(options) while @listening
      end
    end

    def stop_listening
      @listening = false
    end

  end


  ## Object representing a Spire billing
  ##
  ## You can get all the billing plans by calling the method billing in Spire object
  ## * spire = Spire.new
  ## * billing = spire.billing()
  ## * plans = billing.plans
  #class Billing
    #def initialize(spire,properties)
      #@spire = spire
      #@properties = properties
    #end
    
    #def url
      #@properties["url"]
    #end
    
    #def plans
      #@properties["plans"]
    #end
  #end
end
