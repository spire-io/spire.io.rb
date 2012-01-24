class Spire
  class API
    class Resource
      include Requestable

      define_request(:get) do
        {
          :method => :get,
          :url => @url,
          :headers => {
            "Authorization" => "Capability #{@capability}",
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
            "Authorization" => "Capability #{@capability}",
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
            "Authorization" => "Capability #{@capability}",
            "Accept" => media_type,
            "Content-Type" => media_type,
          }
        }
      end
  
      attr_reader :url, :capability, :properties

      def initialize(spire, data)
        @spire = spire
        @client = spire.client
        @url = data["url"]
        @capability = data["capability"]
        @properties = data
      end

      def method_missing(name, *args)
        if description = schema["properties"][name.to_s]
          if description["url"]
            # if the schema for this property has a url,
            # then we don't want magic behavior
            super
          else
            properties[name.to_s]
          end
        else
          super
        end
      end

      def inspect
        "#<#{self.class.name}:0x#{object_id.to_s(16)}>"
      end

      def get
        response = request(:get)
        unless response.status == 200
          raise "Error retrieving #{self.class.name}: (#{response.status}) #{response.body}"
        end
        @properties = API.deserialize(response.body)
        self
      end

      def update(properties)
        response = request(:update, properties)
        unless response.status == 200
          raise "Error updating #{self.class.name}: (#{response.status}) #{response.body}"
        end
        @properties = API.deserialize(response.body)
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

