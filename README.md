
# Synopsis

`spire.io.rb` is a Ruby client for the [spire.io API](http://www.spire.io/).

## Basic usage

The `Spire` class provides a simplified spire.io client with a high level interface.  Users of this class do not have to pay attention to details of the REST API.
Here's an example using the message service.  It assumes you have an account key, which you can get by registering at [www.spire.io](http://www.spire.io/register.html)

    require "spire_io"

    spire = Spire.new
    spire.start(key) # key is your account key
    channel = spire.session["arbitrary channel name"]
    channel.publish("Hello World!")
    
Let's create a second session and get our messages.

    spire2 = Spire.new
    spire2.start(key)
    subscription = spire2.session.subscribe("my subscription", "arbitrary channel name")
    puts subscription.listen.first # => "Hello World!"
    
You can also assign listener blocks to a subscription which will be called with each message received:

    spire3 = Spire.new
    spire3.start(key)
    subscription = spire3.session.subscribe("another subscription", "arbitrary channel name")
    subscription.add_listener {|m| puts "Got a message: #{m}"}
    subscription.start_listening
    
The subscription object will continue to monitor the channel until you call `#stop_listening` on it.

You can add as many listeners as you want.  They can be removed by name:

    listener_name = subscription.add_listener {|m| puts "Got a message: #{m}"}
    subscription.remove_listener(listener_name)

You can also assign your own name when you add the listener as well:

    subscription.add_listener("Listener1") {|m| puts "Got a message: #{m}"}
    subscription.remove_listener("Listener1")
    
**Note:** Listener blocks are executed in separate threads, so please be careful when accessing shared resources.

## Low level interface

The `Spire::API` class provides a low level spire.io client that allows you to work directly with the REST API.  The higher level `Spire` class is a wrapper around this foundation.  Where `Spire` hides the underlying HTTP traffic from the developer, sometimes making multiple requests within a single method call, `Spire::API` typically makes one request per method and expects the developer to deal with the consequences.  It also (optionally) exposes the actual HTTP requests used to interact with spire.io.

Usage:

    require "spire/api"

    api = Spire::API.new
    api.discover
    session = api.create_session(account_key)
    # session.channels is a memoizing method.
    # If the session has already retrieved the channels
    # collection, the cached version is returned.
    unless channel = session.channels["foo"]
      begin
        channel = session.create_channel("foo")
      # if the channel named "foo" already exists,
      # Spire::API raises an error.
      rescue
        # session.channels! always requests the channels
        # collection, ovewriting the cached version. 
        channel = session.channels!["foo"]
      end
    end

    subscription = session.create_subscription("sub.name", ["foo"])
    channel.publish("message content")
    events = subscription.retrieve_events
    last_timestamp = events[:last]

    channel.publish("another message")
    more_events = subscription.retrieve_events(:last => last_timestamp)

## CLI usage

You can also use the client from your shell

    # Get help and a list of all the commands supported:
    > spire -h

i.e.
    # Open up an IRB session with an open spire session.
    > spire console (-k KEY | -e EMAIL)

    # once in IRB you get an authenticated Spire object
    >> $spire.api.discover      // get the API description
    >> $spire.session.channels      // get a list of Channels

You can also add a YAML '~/.spirerc' file with a hash entry 'key' containing your account key

## What is spire.io?

[spire.io](http://spire.io) is a platform as service API.

## Working with this library

* [source code](https://github.com/spire-io/spire.io.rb)
* [inline documentation](http://spire-io.github.com/spire.io.rb/) (via [yardoc](https://github.com/lsegal/yard))
* [issues](https://github.com/spire-io/spire.io.rb/issues)
* [contact spire.io](http://spire.io/contact.html)

# Installation

To install the latest release from rubygems.org:

    gem install spire_io --pre

If you're managing dependencies with Bundler, you can refer to this repo in your Gemfile, optionally specifying a branch or tag:

    gem "spire_io",
      :git => "git://github.com/spire-io/spire.io.rb.git",
      :branch => "master"

You can also clone the repo and manage your load path in the old fashioned way. E.g.:

    irb -I /path/to/spire_io/lib

Or clone, build, and install the gem:

    rake install

# Development

## Tests

The test suite can be run via:

    rake test

# Contributing

Fork and send pull requests via github, also any [issues](https://github.com/spire-io/spire.io.rb/issues) are always welcome

# License

Open Source Initiative OSI - The MIT License (MIT):Licensing

MIT LICENSE
Copyright (c) 2011 spire.io

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in
all copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN
THE SOFTWARE.
