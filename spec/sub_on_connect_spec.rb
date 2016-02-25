require 'spec_helper'
require 'rspec/eventually'

def with_event_machine(options = {})
  raise "no block given" unless block_given?
  timeout = options[:timeout] ||= 10

  ::EM.epoll if ::EM.epoll?

  ::EM.run do
    quantum = 0.005
    ::EM.set_quantum(quantum * 1000) # Lowest possible timer resolution
    ::EM.set_heartbeat_interval(quantum) # Timeout connections asap
    # ::EM.add_timer(timeout) { raise "timeout" }

    yield
  end
end

describe 'subscribing at connect time' do
  let(:subject) { 'test.topic' }

  it 'subscribes when connecting to the server' do
    @pclient = @sclient = nil
    # t1 = Thread.new do
      with_event_machine do
        @sclient = NATS.connect(:max_reconnect_attempts => -1, :reconnect_time_wait => 5)
      end
    # end
    # t2 = Thread.new do
      with_event_machine do
        @pclient = NATS.connect(:max_reconnect_attempts => -1)
      end
    # end

    expect(Rspec::Eventually::Eventually.new(be).matches? -> { @sclient }).to be true
    expect(@pclient).not_to be_nil

    expect(@sclient).not_to be_nil
    @sclient.subscribe(subject)
    expect(@sclient.subscription_count).to eq 1

    sleep 5
    NatsServerControl.new.start_server

    expect(@sclient.msgs_received).to eq 0
    expect(@sclient.connected?).to be true
    expect(@pclient.connected?).to be true

    @pclient.publish(subject, 'HELLO AGAIN')
    expect(@sclient.subscription_count).to eq 1
    expect(Rspec::Eventually::Eventually.new(eq 1).within(20).matches? -> { @sclient.msgs_received }).to be_truthy
  end

  after do
  end
end