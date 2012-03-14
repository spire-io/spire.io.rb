class Spire
  class API

    class Notification < Resource
      def resource_name
        "notification"
      end
      
      define_request(:devices) do
        devices = properties["resources"]["devices"]
        capability = devices["capabilities"]["devices"]
        {
          :method => :get,
          :url => devices["url"],
          :headers => {
            "Authorization" => "Capability #{capability}",
            "Accept" => "application/json"
          }
        }
      end
      
      define_request(:register_device) do |data|
        devices = properties["resources"]["devices"]
        capability = devices["capabilities"]["register_device"]
        {
          :method => :put,
          :url => devices["url"],
          :body => data.to_json,
          :headers => {
            "Authorization" => "Capability #{capability}",
            "Accept" => "application/json",
            "Content-Type" => "application/json"
          }
        }
      end
      
      define_request(:remove_device) do |data|
        devices = properties["resources"]["devices"]
        capability = devices["capabilities"]["remove_device"]
        {
          :method => :delete,
          :url => devices["url"],
          :body => data.to_json,
          :headers => {
            "Authorization" => "Capability #{capability}",
            "Accept" => "application/json",
            "Content-Type" => "application/json",
          }
        }
      end
      
      def register_device(properties)
        response = request(:register_device, properties)
        unless response.status == 200
          raise "Error adding device #{self.class.name}: (#{response.status}) #{response.body}"
        end
        token = response.data["token"]
        devices[token] = response.data
      end
      
      def devices
        @devices ||= {}
      end
      
    end

  end
end
