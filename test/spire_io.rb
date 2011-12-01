require 'rubygems'
require 'rspec'
$:<<"src/shark/client/ruby"
require 'spire'

RSpec::Matchers.define :be_a_resource do
	match do |actual|
		actual["url"] =~ /^http/
	end
end

RSpec::Matchers.define :be_a_privileged_resource do
	match do |actual|
		actual["url"] =~ /^http/ and
			not actual["capability"].nil?
	end
end

def spire
	Spire.new("http://api.spire.io/")
end

$email = "test+#{Time.now.to_i}@spire.io"

describe "The spire.io API" do
	
	describe "Accounts and Sessions" do
		
		describe "Registration and Authentication" do

			describe "Register with a valid email and password" do

				before(:all) do
					@spire = spire
					@session = @spire.register(:email => $email, :password => "foobarbaz").instance_eval { @session }
					$key = @spire.key
				end
			
				specify "Returns a privileged session resource" do
					@session.should be_a_privileged_resource
				end

				specify "Returns a privileged account resource" do
					@session["resources"]["account"].should be_a_privileged_resource
				end
			
				describe "Registering another account with the same email" do

					specify "Returns an error" do
						lambda do 
							spire.register(:email => "foo@bar.com", :password => "foobarbaz") 
						end.should raise_error
					end

				end
			
				describe "Log in using the given email and password" do

					before(:all) do
						@spire = spire
						@session = @spire.login("foo@bar.com","foobarbaz").instance_eval { @session }
					end
				
					specify "Returns a privileged session resource" do
						@session.should be_a_privileged_resource
					end

					specify "Returns a privileged account resource" do
						@session["resources"]["account"].should be_a_privileged_resource
					end
				
					describe "Change your password" do
						
						before(:all) do
							@account = @spire.update(:email => "foo@bar.com", :password => "bazbarfoo").instance_eval { @session["resources"]["account"] }
						end
						
						specify "Returns the updated account" do
							@account.should be_a_privileged_resource
						end

						describe "Log in with the new password" do
							
							before(:all) do
								@session = spire.login("foo@bar.com","bazbarfoo").instance_eval { @session }
							end
							
							specify "Returns a privileged session resource" do
								@session.should be_a_privileged_resource
							end

							specify "Returns a privileged account resource" do
								@session["resources"]["account"].should be_a_privileged_resource
							end
							
						end
						
					end
					
					describe "Change your account settings" do
						specify "Returns the updated account"
						specify "The account settings reflect the changes"
					end

				end
			
				describe "Log in using the account key" do

					before(:all) do
						@session = spire.start($key).instance_eval { @session }
					end
				
					specify "Returns a privileged session resource" do
						@session.should be_a_privileged_resource
					end

					specify "Does not return a privileged account resource" do
						@session["resources"]["account"].should == nil
					end
				
				end
				
				describe "Reset your account key" do
					specify "Invalidates existing sessions"
					specify "Invalidates the original account key"
					specify "Allows you to log in using the new account key"
				end
				
				describe "Close a session" do
					specify "Invalidates the session that was closed"
				end
				
				describe "Delete your account" do
					specify "Invalidates existing sessions"
					specify "Invalidates the original account key"
					specify "Invalidates email and password"
				end
				
			end
			
		end

	end
	
	describe "Channels" do

		before(:all) do
			@spire = spire.start($key)
		end
		
		describe "Create a channel" do
			
			before(:all) do
				@channel = @spire["foo"]
			end
			
			specify "Returns a privileged channel resource" do
				@channel.instance_eval { @properties }.should be_a_privileged_resource
			end
			
			describe "Creating a channel with the same name" do

				before(:all) do
					# This relies on the fact that client doesn't keep a hash of channels 
					@channel2 = spire.start($key)["foo"]
				end
				
				specify "Will simply return the existing channel" do
					@channel.key.should == @channel2.key
				end

			end
			
			describe "Publish to a channel" do
				
				before(:all) do
					@message = @channel.publish("Hello World!")
				end
				
				specify "Returns the message we sent" do
					@message["content"].should == "Hello World!"
				end
				
				describe "Create a subscription for a channel" do

					before(:all) do
						@subscription = spire.start($key).subscription("dan",@channel)
					end
					
					describe "Listen for the message we sent" do

						before(:all) do
							@messages = @subscription.listen
						end
						
						specify "We should get back an array of messages" do
							@messages.should be_an(Array)
						end
						
						specify "We should get back the message we sent" do
							@messages.first.should == "Hello World!"
						end
						
						specify "And ONLY the message we sent" do					
							@messages.length.should == 1
						end
						
					end
					
				end

			end
			
			describe "Long-polling on a channel" do

				before(:all) do
					@channel = spire.start($key)["bar"]
					@subscription = spire.start($key).subscription("dan",@channel)
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
							@messages = @subscription.listen(2)
						end
						
						specify "We should get back an array of messages" do
							@messages.should be_an(Array)
						end
						
						specify "We should get back the message we sent" do
							@messages.first.should == "Goodbye!"
						end
						
						specify "And ONLY the message we sent" do					
							@messages.length.should == 1
						end
						
					end
					
				end

			end
			
			describe "Delete a channel" do
				specify "Returns not found if you try to publish to the channel"
			end
			
		end

	end
	
end