require "pp"
require "rubygems"
require "spire_io"

timestamp = (Time.now.to_f * 1000).to_i
email = "getting_started_#{timestamp}@mailinator.com"

# Setup

@spire = Spire.new "http://build.spire.io/"

#Register

@spire.register(:email => email, :password => "spire.io.rb")

#Get session by logging in

@spire = Spire.new "http://build.spire.io/"
@spire.login email, "spire.io.rb"

#Get session using account key

account_key = @spire.session["resources"]["account"]["key"]
@spire = Spire.new "http://build.spire.io/"
@spire.start(account_key)

#Create a channel

@smurf = @spire["smurf"]
@monkey = @spire["monkey"]

#List channels

pp @spire.channels.map { |name, info| name }

#Publish to a channel

message = @smurf.publish("some message")

#Create a subscription

@sub = @spire.subscribe "mysub", "smurf"

#List subscriptions

pp @spire.subscriptions.map {|s| s.name }

#Wait for a single message to be published

@monkey_sub = @monkey.subscribe
listen_thread = Thread.new { messages = @monkey_sub.listen; pp messages}
@monkey.publish("Monkey message!")
listen_thread.join

#Continuous listener

@monkey_sub.add_listener {|m| puts "Received monkey message: #{m}"}
@monkey_sub.start_listening
@monkey.publish("Monkey Message 1")
@monkey.publish("Monkey Message 2")

#Updating account information
@spire.update("name" => "Spire", "company" => "spire.io")