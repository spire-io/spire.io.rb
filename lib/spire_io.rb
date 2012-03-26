require "delegate"

require "spire/api"

class Spire

  # How many times we will try to fetch a channel or subscription after
  # getting a 409 Conflict.
  RETRY_CREATION_LIMIT = 3

  attr_accessor :api, :session, :resources
  
  def initialize(url="https://api.spire.io")
    @api = Spire::API.new(url)
    @url = url
    @channel_error_counts = {}
    @application_error_counts = {}
    @subscription_error_counts = {}
    discover
  end

  def secret
    @session.resources["account"]["secret"]
  end
  
  def discover
    @api.discover
    self
  end
 
  def start(secret)
    @session = @api.create_session(secret)
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

  def password_reset_request(email)
    @api.password_reset_request(email)
  end


  # Deletes the currently authenticated account
  def delete_account
    @session.account.delete
  end

  # Updates the current account with the new account information
  # See Spire docs for available settings
  def update(info)
    @session.account.update(info)
    self
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

  def channels!
    @session.channels!
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
          retry unless @channel_error_counts[name] >= RETRY_CREATION_LIMIT
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
        	@subscription_error_counts[subscription_name] += 1
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

  def applications
    @session.applications
  end

  def applications!
    @session.applications!
  end

  # Creates an application on spire.  Returns an Application object.  Will retry on a 409.
  # @param [String] Name of the application to find/create
  def find_or_create_application(name)
    @application_error_counts[name] ||= 0
    begin
      return @session.create_application(name)
    # TODO custom error class for Conflict, which we can
    # then match here, instead of testing for error message
    rescue => error
      if error.message =~ /409/
        # Dear retry, I love you.  Affectionately, Matthew.
        if application = @session.applications![name]
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
    self
  end


  # Object representing a Spire channel
  #
  # You can get a channel object by calling [] on a Spire object
  # * spire = Spire.new
  # * spire.start("your api secret")
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
  # * spire.start("your api secret")
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
      long_poll(options)
    end

    # wraps the underlying Subscription#add_listener to
    # provided named listeners, threading, and a
    # stop_listening method.
    def add_listener(listener_name = nil, &block)
      raise ArgumentError unless block_given?
      listener_name ||= generate_listener_name
      listener = wrap_listener(&block)
      listeners[listener_name] = listener
      __getobj__.add_listener("message", &listener)
    end

    def remove_listener(arg)
      if arg.is_a? String
        listener = listeners.delete(arg)
      else
        listener_name, _listener = listeners.detect {|k,v| v == arg }
        listener = listeners.delete(listener_name)
      end

      if listener
        __getobj__.listeners["message"].delete(listener)
      end
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

end
