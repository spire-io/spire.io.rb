require 'rubygems'
require 'rspec'
require 'spire_io'

RSpec::Matchers.define :be_a_resource do
  match do |actual|
    actual.url =~ /^http/
  end
end

RSpec::Matchers.define :be_a_privileged_resource do
  match do |actual|
    actual.url =~ /^http/ and
      not actual.capability.nil?
  end
end

def create_spire
  Spire.new("http://build.spire.io")
end

$email = "test+#{Time.now.to_i}@spire.io"

describe "The spire.io API" do
  before(:all) do
    @spire = create_spire
    @session = @spire.register(:email => $email, :password => "foobarbaz").instance_eval { @session }
    $secret = @spire.session.account.secret
  end

  describe "Accounts and Sessions" do

    describe "Registration and Authentication" do

      describe "Register with a valid email and password" do

        specify "has a session" do
          @spire.session.should be_a_kind_of Spire::API::Session
        end

        specify "session has an account resource" do
          @session.resources["account"].should_not be_nil
        end


# TODO: This is having a problem due to shark currently, should reenable later
#       describe "Registering another account with the same email" do
#
#         specify "Returns an error" do
#           lambda do
#             spire.register(:email => $email, :password => "foobarbaz")
#           end.should raise_error
#         end
#
#       end

        describe "Log in using the given email and password" do

          before(:all) do
            @spire = create_spire
            @spire.login($email,"foobarbaz")
            @session = @spire.session
          end

          specify "has a session" do
            @spire.session.should be_a_kind_of Spire::API::Session
          end

          specify "session has an account resource" do
            @session.resources["account"].should_not be_nil
          end

          describe "Change your password" do

            before(:all) do
              @spire.session.account.update(:email => $email, :password => "bazbarfoo")
              @account = @spire.session.account
            end

            #pending "Returns the updated account" do
              #@account.should be_a_privileged_resource
            #end

            describe "Log in with the new password" do

              before(:all) do
                @spire = create_spire.login($email, "bazbarfoo")
              end

              specify "has authenticated session" do
                @spire.session.resources["account"].should_not be_nil
              end

              #pending "Returns a privileged session resource" do
                #@session.should be_a_privileged_resource
              #end

              #pending "Returns a privileged account resource" do
                #@session.resources["account"].should be_a_privileged_resource
              #end

            end

          end

          describe "Change your account settings" do
            specify "Returns the updated account"
            specify "The account settings reflect the changes"
          end

        end

        describe "Log in using the account secret" do

          before(:all) do
            @spire = create_spire.start($secret)
          end

          specify "has an anonymous session" do
            @spire.session.resources["account"].should be_nil
          end

        end

        describe "Reset your account secret" do
          specify "Invalidates existing sessions"
          specify "Invalidates the original account secret"
          specify "Allows you to log in using the new account secret"
        end

        describe "Close a session" do
          specify "Invalidates the session that was closed"
        end

        describe "Delete your account" do
          specify "Invalidates existing sessions"
          specify "Invalidates the original account secret"
          specify "Invalidates email and password"
        end

      end

    end

  end

  describe "Channels" do

    before(:all) do
      @spire = create_spire.start($secret)
    end

    describe "Create a channel" do

      before(:all) do
        @channel = @spire.session["foo"]
      end

      #specify "Returns a privileged channel resource" do
        #@channel.instance_eval { @properties }.should be_a_privileged_resource
      #end

      describe "Creating a channel with the same name" do

        before(:all) do
          # This relies on the fact that client doesn't keep a hash of channels
          @channel2 = create_spire.start($secret).session["foo"]
        end

        specify "Will simply return the existing channel" do
          @channel.url.should == @channel2.url
        end

        specify "Will return an existing channel even if created by another client" do
          spire2 = create_spire.start($secret)
          channel1 = @spire.session["channel1"]
          channel1_copy = spire2.session["channel1"]
          channel1_copy.url.should == channel1.url
        end
      end #describe "Creating a channel with the same name" do

      describe "Publish to a channel" do

        before(:all) do
          @message = @channel.publish("Hello World!")
        end

        specify "Returns the message we sent" do
          @message["content"].should == "Hello World!"
        end

        describe "Create a subscription for a channel" do

          before(:all) do
            @subscription = @spire.session.subscribe('sub_name', "foo")
          end

          describe "Creating subscriptions with the same name" do

            specify "Should return the previously created subscription" do
              sub2 = @spire.session.subscribe('sub_name', "foo")
              sub2.url.should == @subscription.url
            end

            specify "Should return the previously created subscription even from a different client" do
              spire2 = create_spire.start($secret)
              sub1 = @spire.session.subscribe('sub1', "foo")
              sub2 = spire2.session.subscribe('sub1', "foo")
              sub1.url.should == sub2.url
            end
          end #describe "Creating subscriptions with the same name" do

          describe "Getting all subscriptions for a channel" do

            before(:all) do
              @subscriptions = @spire.session['foo'].subscriptions!
            end

            specify "Should return an hash of subscriptions with sub1" do
              @subscriptions['sub1'].should_not be_nil
            end
          end

          describe "Listen for the message we sent" do

            before(:all) do
              @messages = @subscription.long_poll[:messages]
            end

            specify "We should get back an array of messages" do
              @messages.should be_an(Array)
            end

            specify "We should get back the message we sent" do
              @messages.first['content'].should == "Hello World!"
            end

            specify "And ONLY the message we sent" do
              @messages.length.should == 1
            end

          end #describe "Listen for the message we sent" do

        end #describe "Create a subscription for a channel" do

      end #describe "Publish to a channel" do

      describe "Event listening on a channel" do

        before(:all) do
          @channel = create_spire.start($secret).session["event_channel"]
          @subscription = create_spire.start($secret).session.subscribe('new_sub', "event_channel")
          @subscription.start_listening
        end

        specify "A listener is called each time a message is received" do
          @subscription.add_listener("message", "test1") {|m| @last_message = m}
          @channel.publish("Message1")
          sleep 1
          @last_message.content.should == "Message1"
          @subscription.remove_listener("message", "test1")
        end

        specify "You can have multiple listeners on a subscription" do
          @subscription.add_listener("message", "test2") {|m| @last_message2 = m}
          @subscription.add_listener("message", "test3") {|m| @last_message3 = m}
          @channel.publish("Message2")
          sleep 1
          @last_message2.content.should == "Message2"
          @last_message3.content.should == "Message2"
          @subscription.remove_listener("message", "test2")
          @subscription.remove_listener("message", "test3")
        end

        specify "You can have remove a listener on a subscription" do
          @subscription.add_listener("message", "test4") {|m| @last_message4 = m}
          @subscription.add_listener("message", "test5") {|m| @last_message5 = m}
          @channel.publish("Message3")
          sleep 1
          @last_message4.content.should == "Message3"
          @last_message5.content.should == "Message3"
          @last_message4 = nil
          @last_message5 = nil
          @subscription.remove_listener("message", "test4")
          @channel.publish("Message4")
          sleep 1
          @last_message4.should be_nil
          @last_message5.content.should == "Message4"
          @subscription.remove_listener("message", "test5")
        end

        specify "A listener will be assigned a name if none is given" do
          @last_message6 = nil
          name = @subscription.add_listener("message") {|m| @last_message6 = m}
          @subscription.remove_listener("message", name)
          @channel.publish("Message5")
          sleep 1
          @last_message6.should == nil
        end
      end #describe "Event listening on a channel" do

      describe "Long-polling on a channel" do

        before(:all) do
          @channel = create_spire.start($secret).session["bar"]
          @subscription = create_spire.start($secret).session.subscribe('new_sub1', "bar")
        end

        specify "Will only return a single message once" do
          channel = create_spire.start($secret).session["multiple"]
          subscription = create_spire.start($secret).session.subscribe('new_sub2', "multiple")
          subscription.long_poll
          channel.publish("Message 1")
          channel.publish("Message 2")
          messages = subscription.long_poll[:messages]
          messages.first['content'].should == "Message 1"
          messages[1]['content'].should == "Message 2"
          channel.publish("Message 3")
          messages = subscription.long_poll[:messages]
          messages.first['content'].should == "Message 3"
        end

        describe "Waits for a message to be published" do

          # This test will fail until we switch to an http client
          # library that uses a different socket per instance
          before(:all) do
            Thread.new do
              sleep 1
              @channel.publish("Goodbye!")
            end
          end

          describe "Listen for the message we sent" do

            before(:all) do
              @subscription.long_poll
              @messages = @subscription.long_poll(:timeout => 2)[:messages]
            end

            specify "We should get back an array of messages" do
              @messages.should be_an(Array)
            end

            specify "We should get back the message we sent" do
              @messages.first['content'].should == "Goodbye!"
            end

            specify "And ONLY the message we sent" do
              @messages.length.should == 1
            end

          end #describe "Listen for the message we sent"

        end #describe "Waits for a message to be published"

      end #describe "Long-polling on a channel" do

      describe "Delete a channel" do
        specify "Returns not found if you try to publish to the channel"
      end

    end #describe "Create a channel" do

  end #describe "Channels" do

end #describe "The spire.io API" do
