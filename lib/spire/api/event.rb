class Spire
  class API
    class Event < Resource
      def resource_name
        "event"
      end
    end

    class Message < Event
      def resource_name
        "message"
      end
    end

    class Join < Event
      def resource_name
        "join"
      end
    end

    class Part < Event
      def resource_name
        "part"
      end
    end
  end
end
