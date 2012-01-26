class Spire
  class API

    class Account < Resource
      def resource_name
        "account"
      end

      define_request(:billing_subscription) do |info|
        billing = properties["billing"]
        {
          :method => :put,
          :url => billing["url"],
          :body => info.to_json,
          :headers => {
            "Accept" => media_type, "Content-Type" => media_type,
            "Authorization" => "Capability #{billing["capability"]}"
          }
        }
      end

      define_request(:billing_invoices) do
        invoices = properties["billing"]["invoices"]
        {
          :method => :get,
          :url => invoices["url"],
          :headers => {
            "Accept" => "application/json",
            "Authorization" => "Capability #{invoices["capability"]}"
          }
        }
      end

      define_request(:billing_invoices_upcoming) do
        upcoming = properties["billing"]["invoices"]["upcoming"]
        {
          :method => :get,
          :url => upcoming["url"],
          :headers => {
            "Accept" => "application/json",
            "Authorization" => "Capability #{upcoming["capability"]}"
          }
        }
      end

      # Updates and subscribe the account to a billing plan
      # @param [Object] info data containing billing description
      # @return [Account]
      def billing_subscription(info)
        response = request(:billing_subscription)
        raise "Error attempting to update account billing: (#{response.status}) #{response.body}" if response.status != 200
        properties = API.deserialize(response.body)
        #@resources["account"] = JSON.parse(response.body)
        self
      end

    end

  end
end
