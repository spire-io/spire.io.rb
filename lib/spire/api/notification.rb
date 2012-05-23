class Spire
  class API

    class Notification < Resource
      def resource_name
        "notification"
      end
      
      define_request(:push) do |options|
        {
          :method => :post,
          :url => @url,
          :body => {
            :device_tokens => options[:device_tokens],
            :message => options[:message]
          }.to_json,
          :headers => {
            "Authorization" => "Capability #{@capabilities["push"]}",
            "Accept" => @api.mediaType("notification"),
            "Content-Type" => @api.mediaType("notification")
          }
        }
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
            "Content-Type" => "application/json"
          }
        }
      end
      
      def send_notification(options={})
        response = request(:push, options)
        unless response.status == 200
          raise "Error sending push notification #{self.class.name}: (#{response.status}) #{response.body}"
        end
        response.data
      end
      
      def devices!
        response = request(:devices)
        unless response.status == 200
          raise "Error getting device list #{self.class.name}: (#{response.status}) #{response.body}"
        end
        response.data["devices"]
      end
      
      def register_device(device_token)
        response = request(:register_device, :token => device_token)
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
