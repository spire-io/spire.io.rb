require 'base64'
class Spire
  class API

    class Application < Resource
      attr_reader :resources

      def resource_name
        "application"
      end

      def initialize(spire, data)
        super
        @resources = data["resources"]
      end

      define_request(:create_member) do |data|
        collection = @resources["members"]
        capability = collection["capabilities"]["create"]
        url = collection["url"]
        {
          :method => :post,
          :url => url,
          :body => data.to_json,
          :headers => {
            "Authorization" => "Capability #{capability}",
            "Accept" => @spire.mediaType("member"),
            "Content-Type" => @spire.mediaType("member")
          }
        }
      end

      define_request(:members) do
        collection = @resources["members"]
        capability = collection["capabilities"]["all"]
        url = collection["url"]
        {
          :method => :get,
          :url => url,
          :headers => {
            "Authorization" => "Capability #{capability}",
            "Accept" => @spire.mediaType("members"),
          }
        }
      end

      define_request(:member_by_email) do |email|
        collection = @resources["members"]
        capability = collection["capabilities"]["get_by_email"]
        url = collection["url"]
        request = {
          :method => :get,
          :url => url,
          :query => {:email => email},
          :headers => {
            "Authorization" => "Capability #{capability}",
            "Accept" => @spire.mediaType("member"),
          }
        }
      end

      define_request(:authenticate_with_post) do |data|
        collection = @resources["authentication"]
        url = collection["url"]
        request = {
          :method => :post,
          :url => url,
          :body => data.to_json,
          :headers => {
            "Accept" => @spire.mediaType("member"),
          }
        }
      end

      define_request(:authenticate) do |data|
        collection = @resources["members"]
        url = "#{collection["url"]}?email=#{data[:email]}"
        auth = Base64.encode64("#{data[:email]}:#{data[:password]}").gsub("\n", '')
        request = {
          :method => :get,
          :url => url,
          :headers => {
            "Accept" => @spire.mediaType("member"),
            "Authorization" => "Basic #{auth}"
          }
        }
      end

      #Authenticates with the application using basic auth
      def authenticate(email, password)
        response = request(:authenticate, {:email => email, :password => password})
        unless response.status == 200
          raise "Error authenticating for application #{self.name}: (#{response.status}) #{response.body}"
        end
        API::Member.new(@spire, response.data)
      end

      #Alternative application authentication, without using basic auth
      def authenticate_with_post(email, password)
        response = request(:authenticate_with_post, {:email => email, :password => password})
        unless response.status == 201
          raise "Error authenticating for application #{self.name}: (#{response.status}) #{response.body}"
        end
        API::Member.new(@spire, response.data)
      end

      def create_member(member_data)
        response = request(:create_member, member_data)
        unless response.status == 201
          raise "Error creating member for application #{self.name}: (#{response.status}) #{response.body}"
        end
        API::Member.new(@spire, response.data)
      end
      
      def members
        @members || members!
      end

      def members!
        response = request(:members)
        unless response.status == 200
          raise "Error getting members for application #{self.name}: (#{response.status}) #{response.body}"
        end
        @members = {}
        response.data.each do |email, properties|
          @members[email] = API::Member.new(@spire, properties)
        end
        @members
      end

      def get_member(member_email)
        response = request(:member_by_email, member_email)
        unless response.status == 200
          raise "Error finding member with email #{member_email}: (#{response.status}) #{response.body}"
        end
        properties = response.data[member_email]
        member = API::Member.new(@spire, properties)
        @members[member_email] = member if @members.is_a?(Hash)
        member
      end
    end
  end
end
