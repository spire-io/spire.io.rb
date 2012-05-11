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
            "limit" => options[:limit],
            "min_timestamp" => options[:min_timestamp],
            "max_timestamp" => options[:max_timestamp],
            "delay" => options[:delay],
            "last" => options[:last]
          },
          :headers => {
            "Authorization" => "Capability #{@capabilities["events"]}",
            "Accept" => @spire.mediaType("events")
          }
        }
      end

      EVENT_TYPES = ["message", "join", "part"]

      def listeners
        if @listeners
          @listeners
        else
          @listeners = { }
          EVENT_TYPES.each do |type|
            @listeners[type] = []
          end
          @listeners
        end
      end

      def add_listener(type="message", &block)
        type.downcase!
        if !EVENT_TYPES.include?(type)
          throw "Listener type must be one of #{EVENT_TYPES}"
        end

        listeners[type] << block
        block
      end

      def retrieve_events(options={})
        response = request(:events, options)
        unless response.status == 200
          raise "Error retrieving messages from #{self.class.name}: (#{response.status}) #{response.body}"
        end
        @last = response.data["last"] if response.data and response.data["last"]

        event_hash = {
          :first => response.data["first"],
          :last => response.data["last"]
        }

        EVENT_TYPES.each do |type|
          type_pl = "#{type}s"
          event_hash[type_pl.to_sym] = []
          response.data[type_pl].each do |event|
            klass_name = type.capitalize
            klass = API.const_get(klass_name)
            event_obj = klass.new(@spire, event)
            event_hash[type_pl.to_sym].push(event_obj)

            listeners[type].each do |listener|
              listener.call(event_obj)
            end
          end
        end
        event_hash
      end

      def poll(options={})
        # timeout option of 0 means no long poll,
        # so we force it here.
        options[:timeout] = 0
        long_poll(options)
      end

      def long_poll(options={})
        options[:timeout] ||= 30
        options[:last] = @last
        retrieve_events(options)
      end

      def listen(options={})
        loop do
          break unless yield(long_poll(options))
        end
      end

    end
  end
end
