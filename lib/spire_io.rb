require "delegate"

require "spire/api"

class Spire

  # How many times we will try to fetch a channel or subscription after
  # getting a 409 Conflict.
  RETRY_CREATION_LIMIT = 3

  # @!attribute [rw] api
  #   Spire API object.  Has low-level methods for accessing the spire.io API.
  # @!attribute [rw] session
  #   Spire session.  Contains methods for creating channels, subscriptions, and applications.
  attr_accessor :api, :session, :resources

  def initialize(url="https://api.spire.io")
    @api = Spire::API.new(url)
    @url = url
    @api.discover
  end

  def start(secret)
    @session = @api.create_session(secret)
    self
  end

  # Authenticates a session using a login and password
  def login(login, password)
    @session = @api.login(login, password)
    self
  end

  # Register for a new spire account, and authenticates as the newly created account
  # @param [String] :email Email address of new account
  # @param [String] :password Password of new account
  # @param [String] :password_confirmation Password confirmation (optional)
  def register(info)
    @session = @api.create_account(info)
    self
  end

  def password_reset_request(email)
    @api.password_reset_request(email)
  end
end
