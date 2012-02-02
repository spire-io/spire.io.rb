require "pp"
require "rubygems"
require "spire_io"

service_url = ARGV[0] || "http://build.spire.io/"

timestamp = (Time.now.to_f * 1000).to_i
email = "getting_started_#{timestamp}@mailinator.com"

# Setup

@spire = Spire.new service_url


#Register

@spire.register(:email => email, :password => "spire.io.rb")

#Get session by logging in

@spire = Spire.new service_url
@spire.login email, "spire.io.rb"

#Get session using account key

account_key = @spire.key
@spire = Spire.new service_url
@spire.start(account_key)

#Create (or use existing) channel

@smurf = @spire["smurf"]
@smurf_dupe = @spire["smurf"]
@monkey = @spire["monkey"]

#List channels

pp @spire.channels.map { |name, info| name }

#Publish to a channel

message = @smurf.publish("some message")

#Create a subscription

@sub = @spire.subscribe "mysub", "smurf"

#List subscriptions

print "Subscriptions: "
pp @spire.subscriptions.map {|s| s.name }

#Wait for a single message to be published

@monkey_sub = @monkey.subscribe
listen_thread = Thread.new { messages = @monkey_sub.listen; pp messages}
@monkey.publish("Monkey message!")
listen_thread.join

#Continuous listener

@monkey_sub.add_listener {|m| puts "Received monkey message: #{m}"}
extra_listener = @monkey_sub.add_listener {|m| puts "extraneous listener #{m}"}
thread = @monkey_sub.start_listening
@monkey.publish("Monkey Message 1")
sleep 0.1
@monkey_sub.remove_listener(extra_listener)
@monkey.publish("Monkey Message 2")
sleep 0.1
@monkey_sub.stop_listening
@monkey.publish("No Monkey Message")
sleep 0.1


#Updating account information
@spire = Spire.new service_url
@spire.login email, "spire.io.rb"
@spire.update(:name => "Spire")
