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
    
    