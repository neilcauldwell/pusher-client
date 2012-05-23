require 'pusher-client'

PusherClient.logger = Logger.new(STDOUT)
options = {:secret => YOUR_APP_SECRET}
socket = PusherClient::Socket.new(YOUR_APP_KEY, options)
socket.connect(true) # Connect asynchronously

# Subscribe to a channel
socket.subscribe('channel')

# Bind to a global event
socket.bind('event') do |data|
  puts data
end

loop do
  sleep(1) # Keep your main thread running
end
