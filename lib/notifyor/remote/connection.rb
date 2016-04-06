require 'redis-objects'
require 'notifyor/growl'
require 'notifyor/util/formatter'
require 'net/ssh/gateway'
module Notifyor
  module Remote
    class Connection

      def initialize
        @ssh_host = ENV['ssh_host']
        @ssh_port = ENV['ssh_port']
        @ssh_user = ENV['ssh_user']
        @tunnel_port = ENV['ssh_tunnel_port']
        @redis_port = ENV['ssh_redis_port']
        @ssh_gateway = nil
        @redis_tunnel_connection = nil
      end

      def build_tunnel
        unless ['127.0.0.1', 'localhost'].include? @ssh_host
          @ssh_gateway = Net::SSH::Gateway.new(@ssh_host, @ssh_user, port: @ssh_port)
          @ssh_gateway.open('127.0.0.1', @redis_port, @tunnel_port)
        end
      end

      def build_redis_tunnel_connection
        redis_port = (['127.0.0.1', 'localhost'].include? @ssh_host) ? @redis_port : @tunnel_port
        @redis_tunnel_connection = Redis.new(port: redis_port)
      end

      def subscribe_to_redis
        @redis_tunnel_connection.subscribe('notifyor') do |on|
          on.message do |channel, msg|
            data = JSON.parse(msg)
            growl_message(data['message'])
          end
        end
      end

      def growl_message(message)
        ::Notifyor::Growl.create_growl("Notifyor", message) unless Notifyor::Util::Formatter.squish!(message).empty?
      end
    end
  end
end