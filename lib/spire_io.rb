require 'excon'
gem 'json'
require 'json'

class Spire
	
	attr_accessor :client
	
	def initialize(url="https://api.spire.io")
		@client = Excon
		@url = url
		# @headers = { "User-Agent" => "Ruby spire.io client" }
		# @timeout = 1
		discover
	end

	# Authenticates a session using a Spire API key
	# @param [String] key API key
	def start(key)
		response = @client.post(
			@description["resources"]["sessions"]["url"],
			:body => { :key => key }.to_json,
			:headers => {
				"Accept" => mediaType("session"),
				"Content-Type" => mediaType("account")
			})
		raise "Error starting a key-based session" if response.status != 201
		@session = JSON.parse(response.body)	
		self
	end
	
	# Authenticates a session using a login and password
	def login(login,password)
    response = _login(login, password)
		raise "Error attemping to login:  (#{response.status}) #{response.body}" if response.status != 201
		@session = JSON.parse(response.body)
		self
	end

  def _login(email, password)
		@client.post(
			@description["resources"]["sessions"]["url"],
			:body => { :email => email, :password => password }.to_json,
			:headers => {
				"Accept" => mediaType("session"),
				"Content-Type" => mediaType("account")
			}
    )
  end
	
	# Register for a new spire account, and authenticates as the newly created account
	# @param [String] :email Email address of new account
	# @param [String] :password Password of new account
	def register(info)
		response = @client.post(
			@description["resources"]["accounts"]["url"],
			:body => { :email => info[:email], :password => info[:password] }.to_json,
			:headers => { 
				"Accept" => mediaType("session"),
				"Content-Type" => mediaType("account")
			})
		raise "Error attempting to register: (#{response.status}) #{response.body}" if response.status != 201
		@session = JSON.parse(response.body)	
		self
	end
	
	# Deletes the currently authenticated account
	def delete_account
		@client.delete(
			@session["resources"]["account"]["url"],
			:headers => { 
				"Accept" => mediaType("account"),"Content-Type" => mediaType("account"),
				"Authorization" => "Capability #{@session["resources"]["account"]["capability"]}"
		})
	end

	# Updates the current account with the new account information
	# See Spire docs for available settings
	def update(info)
		response = @client.put(
			@session["resources"]["account"]["url"],
			:body => info.to_json,
			:headers => {
				"Accept" => mediaType("account"),"Content-Type" => mediaType("account"),
				"Authorization" => "Capability #{@session["resources"]["account"]["capability"]}"	
			})
		raise "Error attempting to update account: (#{response.status}) #{response.body}" if response.status != 200
		@session["resources"]["account"] = JSON.parse(response.body)
		self
	end
	
	# Returns a channel object for the named channel
	# @param [String] name Name of channel returned
	# @return [Channel]
	def [](name)
		response = @client.post(
			@session["resources"]["channels"]["url"],
			:body => { :name => name }.to_json,
			:headers => {
				"Authorization" => "Capability #{@session["resources"]["channels"]["capability"]}",
				"Accept" => mediaType("channel"),
				"Content-Type" => mediaType("channel")
			})
		raise "Error creating or accessing a channel: (#{response.status}) #{response.body}" if !(response.status == 201 || response.status == 200)
		Channel.new(self,JSON.parse(response.body))
	end
	
	# Returns a subscription object for the given channels
	# @param [String] subscription_name Name for the subscription
	# @param [String] channels One or more channel names for the subscription to listen on
	# @return [Subscription]
	def subscribe(subscription_name, *channels)
		response = @client.post(
			@session["resources"]["subscriptions"]["url"],
			:body => { :channels => channels.flatten.map { |name| self[name].url } }.to_json,
			:headers => {
				"Authorization" => "Capability #{@session["resources"]["subscriptions"]["capability"]}",
				"Accept" => mediaType("subscription"),
				"Content-Type" => mediaType("subscription")
			})
		raise "Error creating a subscription: (#{response.status}) #{response.body}" if !(response.status == 201 || response.status == 200)
		Subscription.new(self,JSON.parse(response.body))
	end
	alias :subscription :subscribe #For compatibility with other clients

	# Returns a billing object than contains a list of all the plans available
	# @param [String] info optional object description
	# @return [Billing]
	def billing(info=nil)
		response = @client.get(
			@description["resources"]["billing"]["url"],
			:headers => {
				"Accept" => "application/json"
			})
		raise "Error getting billing plans: #{response.status}" if response.status != 200
		Billing.new(self,JSON.parse(response.body))
	end
	
	# Updates and subscribe the account to a billing plan
	# @param [Object] info data containing billing description
	# @return [Account]
	def billing_subscription(info)
		response = _billing_subscription(info)
		raise "Error attempting to update account billing: (#{response.status}) #{response.body}" if response.status != 200
		@session["resources"]["account"] = JSON.parse(response.body)
		self
	end

	def _billing_subscription(info)
		@client.put(
			@session["resources"]["account"]["billing"]["url"],
			:body => info.to_json,
			:headers => {
				"Accept" => mediaType("account"),"Content-Type" => mediaType("account"),
				"Authorization" => "Capability #{@session["resources"]["account"]["capability"]}"
			})
	end
	

	def key
		@session["resources"]["account"]["key"]
	end
	
	def mediaType(name)
		@description["schema"]["1.0"][name]["mediaType"]
	end
	
	private
	def discover
		response = @client.get(@url, :headers => {"Accept" => "application/json"})
		raise "Error during discovery: #{response.status}" if response.status != 200
		@description = JSON.parse(response.body)
		self
	end
	
	public
	
	# Object representing a Spire channel
	#
	# You can get a channel object by calling [] on a Spire object
	# * spire = Spire.new
	# * spire.start("your api key")
	# * channel = spire["channel name"]
	class Channel

		def initialize(spire,properties)
			@spire = spire
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
			response = _publish({:content => message}.to_json)
			raise "Error publishing a message: (#{response.status}) #{response.body}" if response.status != 201
			JSON.parse(response.body)
		end

		# @private
		def _publish(body)
			@spire.client.post(
				@properties["url"],
				:body => body,
				:headers => {
					"Authorization" => "Capability #{@properties["capability"]}",
					"Accept" => mediaType("message"),
					"Content-Type" => mediaType("message")
				}
			)
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
		attr_accessor :messages, :last
		
		def initialize(spire,properties)
			@spire = spire
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

		def capability
			@properties["capability"]
		end

		def url
			@properties["url"]
		end

		# Adds a listener (ruby block) to be called each time a message is received on the channel
		#
		# You must call #start_listening to actually start listening for messages
		# @note Listeners are executed in their own thread, so practice proper thread safety!
		# @param [String] name Name for the listener.  One will be generated if not provided
		# @return [String] Name of the listener
		def add_listener(name = nil, &block)
			@listener_mutex.synchronize do
				while !name
					new_name = "Listener-#{rand(9999999)}"
					name = new_name unless @listeners.has_key?(new_name)
				end
				@listeners[name] = block
			end
			name
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
		# @param [Integer] timeout Max time to wait for a new message before returning
		# @return [Array] An array of messages received
		def listen(timeout=30)
			response = @spire.client.get(
				@properties["url"],
				:query => {
					"timeout" => timeout,
					"last-message" => @last||'0'
				},
				:headers => {
					"Authorization" => "Capability #{@properties["capability"]}",
					"Accept" => mediaType("events")
				})
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
