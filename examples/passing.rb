require "pp"
require "spire/api"

api = Spire::API.new
api.discover
session = api.login("me@me.com","carlospants")
channel = session.create_channel "smurf-#{Time.now.to_f}"

unpriv = Spire::API.new
unpriv.discover
pp unpriv_channel = Spire::API::Channel.new(unpriv, "url" => channel.url, "capability" => channel.capability)
pp unpriv_channel.publish "monkey"

