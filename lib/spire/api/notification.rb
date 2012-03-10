class Spire
  class API

    class Notification < Resource
      def resource_name
        "notification"
      end
      
      define_request(:addDevice) do |data|
        devices = properties["resources"]["devices"]
        capability = devices["capabilities"]["add_device"]
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
      
      def addDevice(properties)
        response = request(:addDevice, properties)
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
