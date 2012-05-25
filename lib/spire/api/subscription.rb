class Spire
  class API

    # The subscription class represents a read connection to a Spire channel
    #
    # You can get a subscription by calling subscribe on a spire object with the name of the channel or
    # by calling subscribe on a channel object
    #
    # * spire = Spire.new
    # * spire.start("your api secret")
    # *THEN*
    # * subscription = spire.subscribe("subscription name", "channel name")
    # *OR*
    # * channel = spire["channel name"]
    # * subscription = channel.subscribe("subscription name")
    class Subscription < Resource

      # @!attribute [rw]
      #   Timestamp (in microseconds) of the last event received
      attr_accessor :last

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
            "last" => options[:last],
            "order-by" => options[:order_by]
          },
          :headers => {
            "Authorization" => "Capability #{@capabilities["events"]}",
            "Accept" => @api.mediaType("events")
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
            @listeners[type] = {}
          end
          @listeners
        end
      end

      # provided named listeners, threading, and a
      # stop_listening method.
      def add_listener(type, listener_name = nil, &block)
        type ||= ""
        type.downcase!
        if !EVENT_TYPES.include?(type)
          throw "Listener type must be one of #{EVENT_TYPES}"
        end

        raise ArgumentError unless block_given?
        listener_name ||= generate_listener_name
        listener = wrap_listener(&block)
        listeners[type][listener_name] = listener
        listener_name
      end

      def remove_listener(type, arg)
        type ||= ""
        type.downcase!
        if !EVENT_TYPES.include?(type)
          throw "Listener type must be one of #{EVENT_TYPES}"
        end

        if arg.is_a? String
          listener = listeners[type].delete(arg)
        else
          listener_name, _listener = listeners.detect {|k,v| v == arg }
          listener = listeners[type].delete(listener_name)
        end

        if listener
          listeners[type].delete(listener)
        end
      end

      def wrap_listener(&block)
        lambda do |message|
          Thread.new do
            # Messages received after a call to stop_listening
            # will not be processed.
            yield message if @listening
          end
        end
      end

      def generate_listener_name
        listener_name = nil
        while !listener_name
          new_name = "Listener-#{rand(9999999)}"
          listener_name = new_name unless listeners.has_key?(new_name)
        end
        listener_name
      end

      def start_listening(options={})
        @listening = true
        Thread.new do
          long_poll(options) while @listening
        end
      end

      def stop_listening
        @listening = false
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
            event_obj = klass.new(@api, event)
            event_hash[type_pl.to_sym].push(event_obj)

            listeners[type].each_value do |listener|
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
        options[:last] = @last if @last
        retrieve_events(options)
      end
    end
  end
end
