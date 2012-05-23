require 'json'
require 'hmac-sha2'
require 'digest/md5'

module PusherClient
  class Socket

    # Mimick the JavaScript client
    CLIENT_ID = 'js'
    VERSION = '1.7.1'

    attr_accessor :encrypted, :secure
    attr_reader :path, :connected, :subscriptions, :global_channel, :socket_id

    def initialize(application_key, options={})
      raise ArgumentError if (!application_key.is_a?(String) || application_key.size < 1)

      @path = "/app/#{application_key}?client=#{CLIENT_ID}&version=#{VERSION}"
      @key = application_key
      @secret = options[:secret]
      @socket_id = nil
      @subscriptions = Subscriptions.new
      @global_channel = Channel.new('pusher_global_channel')
      @global_channel.global = true
      @secure = false
      @connected = false
      @encrypted = options[:encrypted] || false

      bind('pusher:connection_established') do |data|
        socket = JSON.parse(data)
        @connected = true
        @socket_id = socket['socket_id']
        subscribe_all
      end

      bind('pusher:connection_disconnected') do |data|
        @subscriptions.subscriptions.each { |s| s.disconnect }
      end

      bind('pusher:error') do |data|
        PusherClient.logger.fatal("Pusher : error : #{data.inspect}")
      end
    end

    def connect(async = false)
      if @encrypted || @secure
        url = "wss://#{HOST}:#{WSS_PORT}#{@path}"
      else
        url = "ws://#{HOST}:#{WS_PORT}#{@path}"
      end
      PusherClient.logger.debug("Pusher : connecting : #{url}")

      @connection_thread = Thread.new {
        @connection = WebSocket.new(url)
        PusherClient.logger.debug "Websocket connected"
        loop do
          msg = @connection.receive[0]
          params  = parser(msg)
          next if (params['socket_id'] && params['socket_id'] == self.socket_id)
          event_name   = params['event']
          event_data   = params['data']
          channel_name = params['channel']
          send_local_event(event_name, event_data, channel_name)
        end
      }

      @connection_thread.run
      @connection_thread.join unless async
      return self
    end

    def disconnect
      if @connected
        PusherClient.logger.debug "Pusher : disconnecting"
        @connection.close
        @connection_thread.kill if @connection_thread
        @connected = false
      else
        PusherClient.logger.warn "Disconnect attempted... not connected"
      end
    end

    def subscribe(channel_name, user_id = nil, options={})
      if user_id
        user_data = {:user_id => user_id, :user_info => options}.to_json
      else
        user_data = {:user_id => '', :user_info => ''}.to_json
      end

      subscription = @subscriptions.add(channel_name, user_data)
      if @connected
        authorize(subscription, method(:authorize_callback))
      end
      return subscription
    end

    def subscribe_existing(subscription)
      if @connected
        authorize(subscription, method(:authorize_callback))
      end
      return subscription
    end

    def subscribe_all
      @subscriptions.subscriptions.each{ |s| subscribe_existing(s) }
    end

    def unsubscribe(channel_name, user_data)
      subscription = @subscriptions.remove(channel_name, user_data)
      if @connected
        send_event('pusher:unsubscribe', {
          'channel' => channel_name
        })
      end
      return subscription
    end

    def bind(event_name, &callback)
      @global_channel.bind(event_name, &callback)
      return self
    end

    def [](channel_name)
      if @subscriptions[channel_name]
        @subscriptions[channel_name]
      else
        @subscriptions << channel_name
      end
    end

    def authorize(subscription, callback)
      if is_private_channel(subscription)
        auth_data = get_private_auth(subscription)
      elsif is_presence_channel(subscription)
        auth_data = get_presence_auth(subscription)
      end
      callback.call(subscription, auth_data)
    end

    def authorize_callback(subscription, auth_data)
      send_event('pusher:subscribe', {
        'channel' => subscription.channel,
        'auth' => auth_data,
        'channel_data' => subscription.user_data
      })
      subscription.acknowledge_subscription(nil)
    end

    def is_private_channel(subscription)
      subscription.channel.match(/^private-/)
    end

    def is_presence_channel(subscription)
      subscription.channel.match(/^presence-/)
    end

    def get_private_auth(subscription)
      string_to_sign = @socket_id + ':' + subscription.channel + ':' + subscription.user_data
      signature = HMAC::SHA256.hexdigest(@secret, string_to_sign)
      return "#{@key}:#{signature}"
    end

    def get_presence_auth(subscription)
      string_to_sign = @socket_id + ':' + subscription.channel + ':' + subscription.user_data
      signature = HMAC::SHA256.hexdigest(@secret, string_to_sign)
      return "#{@key}:#{signature}"
    end

    # For compatibility with JavaScript client API
    alias :subscribeAll :subscribe_all

    def send_event(event_name, data)
      payload = {'event' => event_name, 'data' => data}.to_json
      @connection.send(payload)
      PusherClient.logger.debug("Pusher : sending event : #{payload}")
    end

  protected

    def send_local_event(event_name, event_data, channel_name)
      if (channel_name)
        subs = @subscriptions.find_all(channel_name)
        if (subs)
          subs.each {|s| s.dispatch_with_all(event_name, event_data)}
        end
      end

      @global_channel.dispatch_with_all(event_name, event_data)
      PusherClient.logger.debug("Pusher : event received : channel: #{channel_name}; event: #{event_name}")
    end

    def parser(data)
      begin
        return JSON.parse(data)
      rescue => err
        PusherClient.logger.warn(err)
        PusherClient.logger.warn("Pusher : data attribute not valid JSON - you may wish to implement your own Pusher::Client.parser")
        return data
      end
    end
  end
end