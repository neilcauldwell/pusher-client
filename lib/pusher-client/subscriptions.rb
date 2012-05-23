module PusherClient
  class Subscriptions
    attr_reader :subscriptions

    def initialize
      @subscriptions = []
    end

    def add(channel_name, user_data)
      unless find(channel_name, user_data)
        @subscriptions << Subscription.new(channel_name, user_data)
      end
      find(channel_name, user_data)
    end

    def find_all(channel_name)
      @subscriptions.select {|s| s.channel == channel_name }
    end

    def find_for_bind(channel_name)
      @subscriptions.detect {|s| s.channel == channel_name }
    end

    def find(channel_name, user_data)
      @subscriptions.detect { |s| s.channel == channel_name && s.user_data == user_data }
    end

    def remove(channel_name, user_data)
      subscription = find(channel_name, user_data)
      @subscriptions.delete(subscription)
      @subscriptions
    end

    def empty?
      @subscriptions.empty?
    end

    def size
      @subscriptions.size
    end

    alias :<< :add
    alias :[] :find_for_bind

  end
end
