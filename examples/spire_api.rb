require "pp"
require "rubygems"
require "spire/api"


puts; puts;

#$timestamp = (Time.now.to_f * 1000).to_i
#$email = "getting_started_#{$timestamp}@mailinator.com"

api = Spire::API.new "http://localhost:1337/"
api.discover

pp api.billing.plans

session = api.create_account(
  :email => "getting_started@mailinator.com",
  :password => "spire.io.rb",
  :domain => "smurf.com"
)

new_session = api.login("getting_started@mailinator.com", "spire.io.rb")

anonymous_session = api.create_session(session.account.key)
pp anonymous_session.resources.keys

account = session.account


account.update(:domain => "monkey.com")
print "domain after update: "
pp account.properties["domain"]



channel1 = session.create_channel("smurfy channel")
channel2 = session.create_channel("unsmurfy channel")
channel1.publish("message #1")
channel1.publish("message #2")

subscription = session.create_subscription("sub", ["smurfy channel", "unsmurfy channel"])
subscription = session.subscriptions["sub"]

subscription.add_listener do |message|
  Thread.new do
    puts "\tsubscription listener worked: #{message["content"]}"
  end
end

pp messages = subscription.poll

thread = Thread.new do
  messages = subscription.long_poll
  print "long poll got: "
  pp messages
  messages = subscription.long_poll
  print "long poll got: "
  pp messages
end

channel2.publish("you waited 1")
sleep 0.1
channel2.publish("you waited 2")
sleep 0.1

thread.join

puts

condition = true
thread = Thread.new do
  # listen loops until the return value of the block is false
  subscription.listen({:timeout => 1}) do |message|
    print "messages from listen: "
    pp message
    condition
  end
end


sleep 0.3
channel1.publish "listen 1"
sleep 0.3
channel2.publish "listen 2"

condition = false
thread.join

puts


print "session.channels: "
pp session.channels
#pp session.channels["smurf"].properties
print "session.subscriptions: "
pp session.subscriptions.map { |name, sub| name }

puts "Deleted subscription" if subscription.delete
puts "Deleted channel 1" if channel1.delete
puts "Deleted channel 2" if channel2.delete
puts "Deleted account" if session.account!.delete





#account.properties.each do |key, data|
  #puts "#{key}:\t#{account.schema["properties"][key].inspect}"
#end
#pp account.media_type, account.url, account.schema.keys
#pp account.properties

