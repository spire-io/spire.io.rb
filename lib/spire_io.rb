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
	
	def discover
		response = @client.get(@url, :headers => {"Accept" => "application/json"})
		raise "Error during discovery: #{response.status}" if response.status != 200
		@description = JSON.parse(response.body)
		self
	end
	
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
	
	def login(login,password)
		response = @client.post(
			@description["resources"]["sessions"]["url"],
			:body => { :email => login, :password => password }.to_json,
			:headers => {
				"Accept" => mediaType("session"),
				"Content-Type" => mediaType("account")
			})
		raise "Error attemping to login:  (#{response.status}) #{response.body}" if response.status != 201
		@session = JSON.parse(response.body)
		self
	end
	
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
	
	def delete_account
		@client.delete(
			@description["resources"]["accounts"]["url"],
			:headers => { 
				"Accept" => mediaType("account"),"Content-Type" => mediaType("account"),
				"Authorization" => "Capability #{@session["resources"]["account"]["capability"]}"
		})
	end

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
	alias :subscription :subscribe

	def key
		@session["resources"]["account"]["key"]
	end
	
	def mediaType(name)
		@description["schema"]["1.0"][name]["mediaType"]
	end
	
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

		def subscribe(subscription_name = nil)
			@spire.subscribe(subscription_name, self.name)
		end

		def publish(message)
			response = _publish({:content => message}.to_json)
			raise "Error publishing a message: (#{response.status}) #{response.body}" if response.status != 201
			JSON.parse(response.body)
		end

		def _publish(body)
			response = @spire.client.post(
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
	# You can get a subscription by calling subscribe on a spire object with the name of the channel or
	# by calling subscribe on a channel object
	# spire = Spire.new
	# spire.start("your api key")
	# subscription = spire.subscribe("channel1")
	# # OR #
	# channel = spire["channel1"]
	# subscription = channel.subscribe
	class Subscription
		attr_accessor :messages
		attr_reader :last
		
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

		def remove_listener(name, kill_current_threads = true)
			@listener_mutex.synchronize do
				@listeners.delete(name)
			end
			kill_listening_threads(name) if kill_current_threads
		end

		def remove_all_listeners(kill_current_threads = true)
			@listener_mutex.synchronize do
				@listeners = {}
			end
			kill_listening_threads if kill_current_threads
		end

		def current_listeners
			@listener_mutex.synchronize do #To prevent synch problems adding a new listener while looping
				@listeners.dup
			end
		end

		def start_listening
			raise "Already listening" if @listening_thread
			@listening_thread = Thread.new {
				while true
					new_messages = self.listen
					next unless new_messages.size > 0
					self.current_listeners.each do |name, listener|
						new_messages.each do |m|
							thread = Thread.new { listener.call(m) }
							@listener_thread_mutex.synchronize do
								@listening_threads[name] ||= []
								@listening_threads[name] << thread
							end
						end
					end
				end
			}
		end

		def stop_listening(kill_current_threads = true)
			@listener_thread_mutex.synchronize do
				@listening_thread.kill if @listening_thread
				@listening_thread = nil
			end
			kill_listening_threads if kill_current_threads
		end

		def kill_listening_threads(name_to_kill = nil)
			@listener_thread_mutex.synchronize do
				@listening_threads.each do |name, threads|
					next if name_to_kill and name_to_kill != name
					threads.each {|t| t.kill }
					@listening_threads[name] = []
				end
			end
		end

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
	
	end
end
