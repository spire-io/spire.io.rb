class Spire
  class API

    class Subscription < Resource

      attr_reader :last
      def resource_name
        "subscription"
      end

      define_request(:messages) do |options|
        {
          :method => :get,
          :url => @url,
          :query => {
            "timeout" => options[:timeout],
            "last-message" => options[:last],
            "order-by" => options[:order_by],
            "delay" => options[:delay]
          },
          :headers => {
            "Authorization" => "Capability #{@capability}",
            "Accept" => @spire.mediaType("events")
          }
        }
      end

      def retrieve_messages(options={})
        options[:last] ||= "0"
        options[:delay] ||= 0
        options[:order_by] ||= "desc"

        response = request(:messages, options)
        unless response.status == 200
          raise "Error retrieving messages from #{self.class.name}: (#{response.status}) #{response.body}"
        end
        messages = API.deserialize(response.body)["messages"]
        @last = messages.last["timestamp"] unless messages.empty?
        messages
      end

      def poll(options={})
        # timeout option of 0 means no long poll,
        # so we force it here.
        options[:timeout] = 0
        retrieve_messages(options)
      end

      def long_poll(options={})
        options[:timeout] ||= 30
        options[:last] = @last
        retrieve_messages(options)
      end

      def listen(options={})
        loop do
          break unless yield(long_poll(options))
        end
      end

    end

  end
end