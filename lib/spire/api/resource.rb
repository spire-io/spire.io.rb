class Spire
  class API
    class Resource
      include Requestable

      define_request(:get) do
        {
          :method => :get,
          :url => @url,
          :headers => {
            "Authorization" => "Capability #{@capabilities["get"]}",
            "Accept" => media_type
          }
        }
      end

      define_request(:update) do |properties|
        {
          :method => :put,
          :url => @url,
          :body => properties.to_json,
          :headers => {
            "Authorization" => "Capability #{@capabilities["update"]}",
            "Accept" => media_type,
            "Content-Type" => media_type
          }
        }
      end

      define_request(:delete) do
        {
          :method => :delete,
          :url => @url,
          :headers => { 
            "Authorization" => "Capability #{@capabilities["delete"]}",
            "Accept" => media_type,
            "Content-Type" => media_type,
          }
        }
      end
  
      attr_reader :url, :properties, :capabilities, :capability

      def initialize(spire, data)
        @spire = spire
        @client = spire.client
        @url = data["url"]
        @capabilities = data["capabilities"]
        @properties = data
      end

      def key
        properties["key"]
      end

      def method_missing(name, *args)
        if description = schema["properties"][name.to_s]
          properties[name.to_s]
        else
          super
        end
      end

      def [](name)
        properties[name]
      end

      def get
        response = request(:get)
        unless response.status == 200
          raise "Error retrieving #{self.class.name}: (#{response.status}) #{response.body}"
        end
        @properties = response.data
        self
      end

      def update(properties)
        response = request(:update, properties)
        unless response.status == 200
          raise "Error updating #{self.class.name}: (#{response.status}) #{response.body}"
        end
        @properties = response.data
        self
      end

      def delete
        response = request(:delete)
        unless response.status == 204
          raise "Error deleting #{self.class.name}: (#{response.status}) #{response.body}"
        end
        true
      end

      def schema
        @spire.schema[resource_name]
      end

      def media_type
        schema["mediaType"]
      end
    end

  end
end

