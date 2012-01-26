require "excon"
require "json"

require "requestable"
require "spire/api/resource"
require "spire/api/session"
require "spire/api/account"
require "spire/api/channel"
require "spire/api/subscription"

class Spire

  class API
    include Requestable

    def self.deserialize(string)
      JSON.parse(string, :symbolize_names => false)
    end

    attr_reader :client, :description, :schema
    def initialize(url="https://api.spire.io", options={})
      @version = options[:version] || "1.0"
      @client = Excon
      @url = url
    end

    def inspect
      "#<Spire::API:0x#{object_id.to_s(16)} @url=#{@url.dump}>"
    end

    define_request(:discover) do
      {
        :method => :get,
        :url => @url,
        :headers => {"Accept" => "application/json"}
      }
    end

    define_request(:create_session) do |key|
      {
        :method => :post,
        :url => @description["resources"]["sessions"]["url"],
        :body => {:key => key}.to_json,
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
          :password_confirmation => info[:password_confirmation]
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


    def discover
      response = request(:discover)
      raise "Error during discovery: #{response.status}" if response.status != 200
      @description = API.deserialize(response.body)
      @schema = @description["schema"][@version]
    end

    def mediaType(name)
      schema[name]["mediaType"]
    end
   
    def create_session(key)
      response = request(:create_session, key)
      raise "Error starting a key-based session" if response.status != 201
      session_data = API.deserialize(response.body)
      API::Session.new(self, session_data)
    end

    # Authenticates a session using a login and password
    def login(login, password)
      response = request(:login, login, password)
      raise "Error attemping to login:  (#{response.status}) #{response.body}" if response.status != 201
      session_data = API.deserialize(response.body)
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
      session_data = API.deserialize(response.body)
      API::Session.new(self, session_data)
    end

    def password_reset_request(email)
      response = request(:password_reset)
      unless response.status == 202
        raise "Error requesting password reset: (#{response.status}) #{response.body}"
      end
      response
    end

    # Returns a billing object than contains a list of all the plans available
    # @param [String] info optional object description
    # @return [Billing]
    def billing(info=nil)
      response = request(:billing)
      raise "Error getting billing plans: #{response.status}" if response.status != 200
      API::Billing.new(self, API.deserialize(response.body))
    end
    
    class Billing < Resource
      def resource_name
        "billing"
      end
    end

  end

end
