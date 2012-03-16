class Spire
  class API

    class Subscription < Resource

      attr_reader :last
      def resource_name
        "subscription"
      end

      define_request(:events) do |options|
        {
          :method => :get,
          :url => @url,
          :query => {
            "timeout" => options[:timeout],
            "last" => options[:last],
            "order-by" => options[:order_by],
            "delay" => options[:delay]
          },
          :headers => {
            "Authorization" => "Capability #{@capabilities["events"]}",
            "Accept" => @spire.mediaType("events")
          }
        }
      end

      def listeners
        @listeners ||= []
      end

      def add_listener(&block)
        listeners << block
        block
      end

      def retrieve_events(options={})
        options[:last] ||= "0"
        options[:delay] ||= 0
        options[:order_by] ||= "desc"

        response = request(:events, options)
        unless response.status == 200
          raise "Error retrieving messages from #{self.class.name}: (#{response.status}) #{response.body}"
        end
        @last = response.data["last"] if response.data and response.data["last"]
        response.data
      end

      def retrieve_messages(options={})
        events = retrieve_events(options)
        messages = events["messages"].map do |message|
          API::Message.new(@spire, message)
        end
        messages.each do |message|
          listeners.each do |listener|
            listener.call(message)
          end
        end
        messages
      end

      def poll(options={})
        # timeout option of 0 means no long poll,
        # so we force it here.
        options[:timeout] = 0
        options[:last] = @last
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
