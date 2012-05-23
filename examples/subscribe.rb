require 'pusher-client'

PusherClient.logger = Logger.new(STDOUT)
options = {:secret => YOUR_APP_SECRET}
socket = PusherClient::Socket.new(YOUR_APP_KEY, options)

# Subscribe to a public channel
socket.subscribe('channel')

# Subscribe to an authenticated channel (presence or private)
socket.subscribe('presence-channel', 'user_id')

# Subscribe to an authenticated channel with optional :user_info
socket.subscribe('presence-channel', 'user_id', { :name => 'name' })

# Subscribe to array of channels
['channel1', 'channel2'].each do |c|
  socket.subscribe("presence-#{c}", 'user_id')
end

# Bind to global events (a catch-all for any 'event' across subscribed channels)
socket.bind('event') do |data|
  puts data
end

# Bind to events that occur on a specific channel
socket['channel'].bind('event') do |data|
  puts data
end

socket.connect
