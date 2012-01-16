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

    def define_request(name, &block)
      requests[name] = block
    end
  end

  module InstanceMethods
    def prepare_request(name, *args)
      block = self.class.requests[name]
      options = self.instance_exec(*args, &block)
      Request.new(@client, options)
    end

    def request(name, *args)
      prepare_request(name, *args).exec
    end
  end

  class Request
    attr_accessor :url
    def initialize(client, options)
      @client = client
      @method = options.delete(:method) 
      @url = options.delete(:url) 
      @options = options
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
      @client.send(@method, @url, @options)
    end
  end

end


