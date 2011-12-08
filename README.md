# Ruby `spire.io` Client

This is a Ruby client for using the spire.io service. Here's an example using the message service.

    spire = Spire.new
    spire.start(key) # key is your account key
    spire["foo"].publish("Hello World!")
    
Let's create a second session and get our messages.

    spire2 = Spire.new
    spire2.start(key)
    subscription = spire2.subscription("dan","foo")
    puts subscription.listen.first # => "Hello World!"
    
You can also assign listener blocks to a subscription which will be called with each message received:

    spire3 = Spire.new
    spire3.start(key)
    subscription = spire3.subscription("dan","bar")
    subscription.add_listener {|m| puts "Got a message: #{m}"}
    subscription.start_listening
    
The subscription object will continue to monitor the channel until you call #stop_listening on it.

You can add as many listeners as you want.  They can be removed by name:

    subscription_name = subscription.add_listener {|m| puts "Got a message: #{m}"}
    subscription.remove_listener(subscription_name)

You can also assign your own name when you add the listener as well:

    subscription.add_listener("Listener1") {|m| puts "Got a message: #{m}"}
    subscription.remove_listener("Listener1")
    
*Note* Listener blocks will be executed in a separate thread, so please be careful when accessing shared resources.