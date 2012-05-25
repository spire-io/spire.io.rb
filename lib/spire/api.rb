require "rubygems"
require "bundler/setup"

require "excon"
require "json"

require "spire/api/requestable"
require "spire/api/resource"
require "spire/api/session"
require "spire/api/account"
require "spire/api/channel"
require "spire/api/subscription"
require "spire/api/event"
require "spire/api/application"
require "spire/api/member"
require "spire/api/notification"

class Spire

  class API
    include Requestable

    def self.deserialize(string)
      JSON.parse(string, :symbolize_names => false)
    end

    # @!attribute [r] client
    #   HTTP client.
    # @!attribute [r] description
    #   Description of the Spire.io API from discovery.
    # @!attribute [r] schema
    #   The Spire.io API schema.
    attr_reader :client, :description, :schema

    def initialize(url="https://api.spire.io", spire=nil, options={})
      @version = options[:version] || "1.0"
      @client = Excon
      @url = url
      @spire = spire
    end

    define_request(:discover) do
      {
        :method => :get,
        :url => @url,
        :headers => {"Accept" => "application/json"}
      }
    end

    define_request(:create_session) do |secret|
      {
        :method => :post,
        :url => @description["resources"]["sessions"]["url"],
        :body => {:secret => secret}.to_json,
        :headers => {
          "Accept" => mediaType("session"),
          "Content-Type" => mediaType("account")
        }
      }
    end

    define_request(:login) do |email, password|
      {
        :method => :post,
        :url => @description["resources"]["sessions"]["url"],
        :body => { :email => email, :password => password }.to_json,
        :headers => {
          "Accept" => mediaType("session"),
          "Content-Type" => mediaType("account")
        }
      }
    end

    define_request(:create_account) do |info|
      {
        :method => :post,
        :url => @description["resources"]["accounts"]["url"],
        :body => {
          :email => info[:email],
          :password => info[:password],
          :password_confirmation => info[:password_confirmation],
          :email_opt_in => info[:email_opt_in]
        }.to_json,
        :headers => { 
          "Accept" => mediaType("session"),
          "Content-Type" => mediaType("account")
        }
      }
    end

    define_request(:password_reset) do |email|
      {
        :method => :post,
        :url => @description["resources"]["accounts"]["url"],
        :query => { :email => email },
        :body => ""
      }
    end

    define_request(:billing) do
      {
        :method => :get,
        :url => @description["resources"]["billing"]["url"],
        :headers => {
          "Accept" => "application/json"
        }
      }
    end

    define_request(:get_application) do |app_key|
      {
        :method => :get,
        :url => @description["resources"]["applications"]["url"],
        :query => {:application_key => app_key},
        :headers => {
          "Accept" => mediaType("applications"),
          "Content-Type" => mediaType("applications")
        }
      }
    end

    def discover
      response = request(:discover)
      raise "Error during discovery: #{response.status}" if response.status != 200
      @description = response.data
      @schema = @description["schema"][@version]
    end

    def mediaType(name)
      schema[name]["mediaType"]
    end
   
    def create_session(secret)
      response = request(:create_session, secret)
      raise "Error starting a secret-based session" if response.status != 201
      session_data = response.data
      API::Session.new(self, session_data)
    end

    # Authenticates a session using a login and password
    def login(login, password)
      response = request(:login, login, password)
      raise "Error attemping to login:  (#{response.status}) #{response.body}" if response.status != 201
      session_data = response.data
      API::Session.new(self, session_data)
    end

    # Register for a new spire account, and authenticates as the newly created account
    # @param [String] :email Email address of new account
    # @param [String] :password Password of new account
    def create_account(info)
      response = request(:create_account, info)
      if response.status != 201
        raise "Error attempting to register: (#{response.status}) #{response.body}"
      end
      session_data = response.data
      API::Session.new(self, session_data)
    end

    def password_reset_request(email)
      response = request(:password_reset)
      unless response.status == 202
        raise "Error requesting password reset: (#{response.status}) #{response.body}"
      end
      response
    end

    # Gets an application resource from a key without requiring any authentication
    # @param [String] application_key The application key
    def get_application(application_key)
      response = request(:get_application, application_key)
      if response.status != 200
        raise "Error attempting to retrieve application (#{response.status}) #{response.body}"
      end
      API::Application.new(self, response.data)
    end
  end
end
