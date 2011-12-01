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
	
	def subscription(nick,*channels)
		response = @client.post(
			@session["resources"]["subscriptions"]["url"],
			:body => { :channels => channels.map(&:url) }.to_json,
			:headers => {
				"Authorization" => "Capability #{@session["resources"]["subscriptions"]["capability"]}",
				"Accept" => mediaType("subscription"),
				"Content-Type" => mediaType("subscription")
			})
		raise "Error creating a subscription: (#{response.status}) #{response.body}" if !(response.status == 201 || response.status == 200)
		Subscription.new(self,JSON.parse(response.body))
	end
	
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

		def publish(message)
			response = @spire.client.post(
				@properties["url"],
				:body => { :content => message }.to_json,
				:headers => {
					"Authorization" => "Capability #{@properties["capability"]}",
					"Accept" => mediaType("message"),
					"Content-Type" => mediaType("message")
				})
			raise "Error publishing a message: (#{response.status}) #{response.body}" if response.status != 201
			JSON.parse(response.body)
		end

		def mediaType(name)
			@spire.mediaType(name)
		end
	
	end
	
	class Subscription
		
		
		def initialize(spire,properties)
			@spire = spire
			@properties = properties
		end

		def listen(timeout=30)
			response = @spire.client.get(
				@properties["url"],
				:query => {
					"timeout" => timeout,
					"last" => @last||'0'
				},
				:headers => {
					"Authorization" => "Capability #{@properties["capability"]}",
					"Accept" => mediaType("events")
				})
			raise "Error listening for messages: (#{response.status}) #{response.body}" if response.status != 200
			messages = JSON.parse(response.body)["messages"]
			@last = messages[0]["timestamp"] unless messages.empty?
			messages.map { |m| m["content"] }
		end
		
		def mediaType(name)
			@spire.mediaType(name)
		end
	
	end
	
end
	