require File.dirname(File.expand_path(__FILE__)) + '/teststrap.rb'
require 'logger'

describe "A PusherClient::Channels collection" do
  before do
    @channels = PusherClient::Channels.new
  end

  it "should initialize empty" do
    @channels.empty?.should.equal(true)
    @channels.size.should.equal 0
  end

  it "should instantiate new channels added to it by name" do
    @channels << 'TestChannel'
    @channels.find('TestChannel').class.should.equal(PusherClient::Channel)
  end

  it "should allow removal of channels by name" do
    @channels << 'TestChannel'
    @channels['TestChannel'].class.should.equal(PusherClient::Channel)
    @channels.remove('TestChannel')
    @channels.empty?.should.equal(true)
  end

  it "should not allow two channels of the same name" do
    @channels << 'TestChannel'
    @channels << 'TestChannel'
    @channels.size.should.equal 1
  end

end

describe "A PusherClient::Channel" do
  before do
    @channels = PusherClient::Channels.new
    @channel = @channels << "TestChannel"
  end

  it 'should not be subscribed by default' do
    @channel.subscribed.should.equal false
  end

  it 'should not be global by default' do
    @channel.global.should.equal false
  end

  it 'can have procs bound to an event' do
    @channel.bind('TestEvent') {}
    @channel.callbacks.size.should.equal 1
  end

  it 'should run callbacks when an event is dispatched' do
    @channel.bind('TestEvent') do
      PusherClient.logger.test "Local callback running"
    end

    @channel.dispatch('TestEvent', {})
    PusherClient.logger.test_messages.should.include?("Local callback running")
  end
end

describe "A PusherClient::Subscriptions collection" do
  before do
    @subscriptions = PusherClient::Subscriptions.new
  end

  it "should initialize empty" do
    @subscriptions.empty?.should.equal(true)
    @subscriptions.size.should.equal 0
  end

  it "should instantiate new subscriptions added to it by channel and user_data" do
    @subscriptions.add('TestChannel', 'user_id_1')
    @subscription = @subscriptions.find('TestChannel', 'user_id_1')
    @subscription.class.should.equal(PusherClient::Subscription)
  end

  it "should be able to find all subscriptions with a channel_name" do
    @subscriptions.add('TestChannel', 'user_id_1')
    @subscriptions.add('TestChannel', 'user_id_2')
    @subs = @subscriptions.find_all('TestChannel')
    @subs.size.should.equal 2
    @subs.each { |s| s.channel.should.equal('TestChannel') }
  end

  it "should be able to find a unique subscription by channel_name and user_data" do
    @subscriptions.add('TestChannel', 'user_id_1')
    @subscription = @subscriptions.find('TestChannel', 'user_id_1')
    @subscription.channel.should.equal('TestChannel')
    @subscription.user_data.should.equal('user_id_1')
  end

  it "should allow removal of subscriptions by channel and user_data" do
    @subscriptions.add('TestChannel', 'user_id_1')
    @subscription = @subscriptions.find('TestChannel', 'user_id_1')
    @subscription.class.should.equal(PusherClient::Subscription)
    @subscriptions.remove('TestChannel', 'user_id_1')
    @subscriptions.empty?.should.equal(true)
  end

  it "should not allow two subscriptions of the same channel and user" do
    @subscriptions.add('TestChannel', 'user_id_1')
    @subscriptions.add('TestChannel', 'user_id_1')
    @subscriptions.add('TestChannel', 'user_id_2')
    @subscriptions.size.should.equal 2
  end
end

describe "A PusherClient::Subscription" do
  before do
    @subscriptions = PusherClient::Subscriptions.new
    @subscription = @subscriptions.add("TestChannel", "user_id_1")
  end

  it 'should have a channel and a channel_name' do
    @subscription.channel.should.equal "TestChannel"
  end

  it 'should have user_data' do
    @subscription.user_data.should.equal "user_id_1"
  end

  it 'should not be subscribed by default' do
    @subscription.subscribed.should.equal false
  end

  it 'should not be global by default' do
    @subscription.global.should.equal false
  end

  it 'can have procs bound to an event' do
    @subscription.bind('TestEvent') {}
    @subscription.callbacks.size.should.equal 1
  end

  it 'should run callbacks when an event is dispatched' do
    @subscription.bind('TestEvent') do
      PusherClient.logger.test "Local callback running"
    end

    @subscription.dispatch('TestEvent', {})
    PusherClient.logger.test_messages.should.include?("Local callback running")
  end
end

describe "A PusherClient::Socket" do
  before do
    @socket = PusherClient::Socket.new(TEST_APP_KEY)
  end

  it 'should not connect when instantiated' do
    @socket.connected.should.equal false
  end

  it 'should raise ArgumentError if TEST_APP_KEY is not a nonempty string' do
    lambda {
      @broken_socket = PusherClient::Socket.new('')
    }.should.raise(ArgumentError)
    lambda {
      @broken_socket = PusherClient::Socket.new(555)
    }.should.raise(ArgumentError)
  end

  describe "...when connected" do
    before do
      @socket.connect
    end

    it 'should know its connected' do
      @socket.connected.should.equal true
    end

    it 'should know its socket_id' do
      @socket.socket_id.should.equal '123abc'
    end

    it 'should not be subscribed to its global channel' do
      @socket.global_channel.subscribed.should.equal false
    end

    it 'should create a subscription to a Public channel' do
      @socket.subscriptions.size.should.equal 0
      @subscription = @socket.subscribe('TestChannel')
      @socket.subscriptions.size.should.equal 1
      @subscription.subscribed.should.equal true
    end

    it 'should create a subscription to a Presence channel' do
      @socket.subscriptions.size.should.equal 0
      @subscription = @socket.subscribe('presence-TestChannel', 'user_id_1')
      @socket.subscriptions.size.should.equal 1
      @subscription.subscribed.should.equal true
    end

    it 'should create a subscription to a Private channel' do
      @socket.subscriptions.size.should.equal 0
      @subscription = @socket.subscribe('private-TestChannel', 'user_id_1')
      @socket.subscriptions.size.should.equal 1
      @subscription.subscribed.should.equal true
    end

    it 'should trigger callbacks for global events' do
      @socket.bind('globalevent') { |data| PusherClient.logger.test("Global event!") }
      @socket.global_channel.callbacks.has_key?('globalevent').should.equal true

      @socket.simulate_received('globalevent', 'some data', '')
      PusherClient.logger.test_messages.last.should.include?('Global event!')
    end

    it 'should kill the connection thread when disconnect is called' do
      @socket.disconnect
      Thread.list.size.should.equal 1
    end

    it 'should not be connected after disconnecting' do
      @socket.disconnect
      @socket.connected.should.equal false
    end

    describe "...when subscribed to a subscription" do
      before do
        @subscription = @socket.subscribe('TestChannel')
      end

      it 'should allow binding of callbacks for the subscribed subscription' do
        @socket['TestChannel'].bind('TestEvent') { |data| PusherClient.logger.test(data) }
        @socket['TestChannel'].callbacks.has_key?('TestEvent').should.equal true
      end

     it "should trigger channel callbacks when a message is received" do
       # Bind 2 events for the channel
       @socket['TestChannel'].bind('coming') { |data| PusherClient.logger.test(data) }
       @socket['TestChannel'].bind('going')  { |data| PusherClient.logger.test(data) }

       # Simulate the first event
       @socket.simulate_received('coming', 'Hello!', 'TestChannel')
       PusherClient.logger.test_messages.last.should.include?('Hello!')

       # Simulate the second event
       @socket.simulate_received('going', 'Goodbye!', 'TestChannel')
       PusherClient.logger.test_messages.last.should.include?('Goodbye!')
     end
    end
  end
end