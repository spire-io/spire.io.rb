require "delegate"

class Spire
  class API

    module Requestable

      def self.included(mod)
        mod.module_eval do
          extend(ClassMethods)
          include(InstanceMethods)
        end
      end

      module ClassMethods
        def requests
          @requests ||= {}
        end

        def get_request(name)
          if req = requests[name]
            req
          elsif superclass.respond_to?(:get_request)
            superclass.get_request(name)
          else
            nil
          end
        end

        def define_request(name, &block)
          requests[name] = block
        end
      end

      module InstanceMethods
        def prepare_request(name, *args)
          if block = self.class.get_request(name)
            options = self.instance_exec(*args, &block)
            Request.new(@client, options)
          else
            raise ArgumentError, "No request has been defined for #{name.inspect}"
          end
        end

        def request(name, *args)
          prepare_request(name, *args).exec
        end
      end

      class Request
        # @!attribute [rw] url
        #   Url of the request
        attr_accessor :url
        def initialize(client, options)
          @client = client
          @method = options.delete(:method) 
          @url = options.delete(:url) 
          @options = options
          @options[:headers] = {
            "User-Agent" => "Ruby spire.io client"
          }.merge(@options[:headers] || {})
        end

        def headers
          @options[:headers]
        end

        def body
          @options[:body]
        end

        def body=(val)
          @options[:body] = val
        end

        def query
          @options[:query]
        end

        def exec
          response = Response.new(@client.send(@method, @url, @options))
          headers = response.headers
          content_type = headers.values_at("Content-Type", "content-type").compact.first
          if content_type =~ /json/ && [200, 201].include?(response.status)
            # FIXME: detect appropriate response headers, rather than rescuing
            begin
              response.data = API.deserialize(response.body)
            rescue
            end
          end
          response
        end

        class Response < SimpleDelegator
          # @!attribute [rw] data
          #   Response data
          attr_accessor :data
        end
      end

    end



    
  end
end
