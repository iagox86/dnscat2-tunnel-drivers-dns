# Encoding: ASCII-8BIT

require 'test_helper'

require 'nesser'
require 'resolv'
require 'timeout'

require 'dnscat2/tunnel_drivers/dns/exception'
require 'dnscat2/tunnel_drivers/dns/driver_dns'

module Dnscat2
  module TunnelDrivers
    module DNS
      class MyTestSink
        attr_reader :data_out, :max_length
        def initialize(data:)
          @data_in = data
          @data_out = nil
          @max_length = nil
        end

        def feed(data:, max_length:)
          @data_out = data
          @max_length = max_length
          return @data_in
        end
      end

      ##
      # This literally opens a port and listens on it. So it's real testing
      # (except not through the hierarchy).
      ##
      class DriverTest < ::Test::Unit::TestCase
        PORT = 16_243

        def setup
          SingLogger.set_level_from_string(level: 'debug')
          @mutex = Mutex.new
          @resolv = ::Resolv::DNS.new(nameserver_port: [['127.0.0.1', PORT]])
        end

        def _resolv_a(name)
          return @resolv.getaddresses(name).map(&:to_s).sort
        end

        def test_start_stop
          @mutex.synchronize do
            begin
              driver = Driver.new(
                host: '127.0.0.1',
                port: PORT,
              )
            ensure
              driver.kill
            end
          end
        end

        def test_kill_twice
          @mutex.synchronize do
            driver = Driver.new(
              host: '127.0.0.1',
              port: PORT,
            )
            driver.kill
            assert_raises(Exception) do
              driver.kill
            end
          end
        end

        def test_wait
          @mutex.synchronize do
            driver = Driver.new(
              host: '127.0.0.1',
              port: PORT,
            )

            # Run this in a new thread
            t = Thread.new do
              driver.wait
            end

            driver.kill

            # Make sure the thread ends
            Timeout.timeout(5) do
              t.join
            end
          end
        end

        def test_single_domain_sink
          @mutex.synchronize do
            begin
              driver = Driver.new(host: '127.0.0.1', port: PORT)
              sink = MyTestSink.new(data: 'B')

              driver.add_domain(
                domain: 'test.com',
                sink:    sink,
                encoder: Encoders::Hex,
              )

              result = @resolv.getaddresses('41414141.test.com').map(&:to_s).sort
              assert_equal(['0.1.66.255'], result)
              assert_equal('AAAA', sink.data_out)
            ensure
              driver.kill
            end
          end
        end

        def test_single_tag_sink
          @mutex.synchronize do
            begin
              driver = Driver.new(host: '127.0.0.1', port: PORT)
              sink = MyTestSink.new(data: 'BBB')

              driver.add_tag(
                tag:    'abc',
                sink:    sink,
                encoder: Encoders::Hex,
              )

              result = @resolv.getaddresses('abc.41414141').map(&:to_s).sort
              assert_equal(['0.3.66.66', '1.66.255.255'], result)
              assert_equal('AAAA', sink.data_out)
            ensure
              driver.kill
            end
          end
        end

        def test_multiple_sinks
          @mutex.synchronize do
            begin
              driver = Driver.new(host: '127.0.0.1', port: PORT)
              sink1 = MyTestSink.new(data: '1')
              sink2 = MyTestSink.new(data: '2')
              sink3 = MyTestSink.new(data: '3')
              sink4 = MyTestSink.new(data: '4')

              driver.add_domain(
                domain: 'test.com',
                sink:    sink1,
                encoder: Encoders::Hex,
              )

              driver.add_domain(
                domain: '123test.com',
                sink:    sink2,
                encoder: Encoders::Hex,
              )

              driver.add_tag(
                tag:    'abc',
                sink:    sink3,
                encoder: Encoders::Base32,
              )

              driver.add_tag(
                tag:    'abc123',
                sink:    sink4,
                encoder: Encoders::Hex,
              )

              result1 = @resolv.getaddresses('31313131.test.com').map(&:to_s).sort
              result2 = @resolv.getaddresses('32323232.123test.com').map(&:to_s).sort
              result3 = @resolv.getaddresses('abc.gmztgmy').map(&:to_s).sort
              result4 = @resolv.getaddresses('abc123.34343434').map(&:to_s).sort

              assert_equal(['0.1.49.255'], result1)
              assert_equal(['0.1.50.255'], result2)
              assert_equal(['0.1.51.255'], result3)
              assert_equal(['0.1.52.255'], result4)

              assert_equal('1111', sink1.data_out)
              assert_equal('2222', sink2.data_out)
              assert_equal('3333', sink3.data_out)
              assert_equal('4444', sink4.data_out)
            ensure
              driver.kill
            end
          end
        end

        def test_other_record_types
          @mutex.synchronize do
            begin
              tests = [
                { name: 'A',     sink: MyTestSink.new(data: 'A'),     type: Resolv::DNS::Resource::IN::A,     func: :address,  expected: ['0.1.65.255'] },
                { name: 'AAAA',  sink: MyTestSink.new(data: 'AAAA'),  type: Resolv::DNS::Resource::IN::AAAA,  func: :address,  expected: ['4:4141:4141:FFFF:FFFF:FFFF:FFFF:FFFF'] },
                { name: 'CNAME', sink: MyTestSink.new(data: 'CNAME'), type: Resolv::DNS::Resource::IN::CNAME, func: :name,     expected: ['CNAME.434e414d45'] },
                { name: 'MX',    sink: MyTestSink.new(data: 'MX'),    type: Resolv::DNS::Resource::IN::MX,    func: :exchange, expected: ['MX.4d58'] },
                { name: 'NS',    sink: MyTestSink.new(data: 'NS'),    type: Resolv::DNS::Resource::IN::NS,    func: :name,     expected: ['NS.4e53'] },
                { name: 'TXT',   sink: MyTestSink.new(data: 'TXT'),   type: Resolv::DNS::Resource::IN::TXT,   func: :data,     expected: ['545854'] },
              ]

              driver = Driver.new(host: '127.0.0.1', port: '16243')

              # Add all the tests as tags
              tests.each do |t|
                driver.add_tag(tag: t[:name], sink: t[:sink], encoder: Encoders::Hex)
              end

              # Try them all
              tests.each do |t|
                results = @resolv.getresources(t[:name] + '.41424344', t[:type]).map { |n| n.send(t[:func]).to_s }.sort
                assert_equal(t[:expected], results)
              end
            ensure
              driver.kill
            end
          end
        end

        def test_any
          @mutex.synchronize do
            sink = MyTestSink.new(data: 'AA')

            driver = Driver.new(
              host:     '127.0.0.1',
              port:     '16243',
            )
            driver.add_domain(
              domain:  'test.com',
              sink:    sink,
              encoder: Encoders::Hex,
            )

            begin
              # Do this enough times that we should randomly select every type
              # of ANY
              100.times do
                result = @resolv.getresources('414243444546474849.test.com', Resolv::DNS::Resource::IN::ANY).pop

                if result.respond_to?(:name)
                  assert_equal('4141.test.com', result.name.to_s)
                elsif result.respond_to?(:address)
                  assert_equal('0.2.65.65', result.address.to_s)
                elsif result.respond_to?(:exchange)
                  assert_equal('4141.test.com', result.exchange.to_s)
                elsif result.respond_to?(:data)
                  assert_equal('4141', result.data)
                else
                  assert_equal("Unknown result type was returned, asserting false! Type: #{result.class} :: #{result}", '')
                end

                assert_equal('ABCDEFGHI', sink.data_out)
              end
            ensure
              driver.kill
            end
          end
        end

        def test_try_to_add_duplicates
          @mutex.synchronize do
            begin
              sink = MyTestSink.new(data: 'AA')

              driver = Driver.new(
                host:     '127.0.0.1',
                port:     '16243',
              )

              driver.add_domain(domain: 'test.com', sink: sink, encoder: Encoders::Hex)
              driver.add_tag(tag: 'abc.123', sink: sink, encoder: Encoders::Hex)

              # Make sure subdomains of test are caught
              assert_raises(Dnscat2::TunnelDrivers::DNS::Exception) do
                driver.add_domain(domain: 'sub.test.com', sink: sink, encoder: Encoders::Hex)
              end
              # ...and superdomains
              assert_raises(Dnscat2::TunnelDrivers::DNS::Exception) do
                driver.add_domain(domain: 'com', sink: sink, encoder: Encoders::Hex)
              end

              # Make sure we CAN add domains that are part of the strings
              driver.add_domain(domain: '123test.com', sink: sink, encoder: Encoders::Hex)

              # Same with tags
              assert_raises(Dnscat2::TunnelDrivers::DNS::Exception) do
                driver.add_tag(tag: 'abc', sink: sink, encoder: Encoders::Hex)
              end
              assert_raises(Dnscat2::TunnelDrivers::DNS::Exception) do
                driver.add_tag(tag: 'abc.123.super', sink: sink, encoder: Encoders::Hex)
              end

              # Make sure we CAN add tags that are part of the strings
              driver.add_domain(domain: 'abc.123hi', sink: sink, encoder: Encoders::Hex)
            ensure
              driver.kill
            end
          end
        end

        def test_remove_sink
          @mutex.synchronize do
            begin
              driver = Driver.new(host: '127.0.0.1', port: PORT)
              sink = MyTestSink.new(data: '1')

              driver.add_domain(domain: 'test.com', sink: sink, encoder: Encoders::Hex)
              assert_equal(['0.1.49.255'], @resolv.getaddresses('31313131.test.com').map(&:to_s).sort)
              driver.remove_domain(domain: 'test.com')
              assert_equal([], @resolv.getaddresses('31313131.test.com').map(&:to_s).sort)
              driver.add_domain(domain: 'test.com', sink: sink, encoder: Encoders::Hex)
              assert_equal(['0.1.49.255'], @resolv.getaddresses('31313131.test.com').map(&:to_s).sort)

              driver.add_tag(tag: 'abc', sink: sink, encoder: Encoders::Hex)
              assert_equal(['0.1.49.255'], @resolv.getaddresses('abc.31313131').map(&:to_s).sort)
              driver.remove_tag(tag: 'abc')
              assert_equal([], @resolv.getaddresses('abc.31313131').map(&:to_s).sort)
              driver.add_tag(tag: 'abc', sink: sink, encoder: Encoders::Hex)
              assert_equal(['0.1.49.255'], @resolv.getaddresses('abc.31313131').map(&:to_s).sort)
            ensure
              driver.kill
            end
          end
        end

        def test_invalid_type
          @mutex.synchronize do
            begin
              sink = MyTestSink.new(data: 'AA')

              driver = Driver.new(
                host:     '127.0.0.1',
                port:     '16243',
              )
              driver.add_domain(
                domain:  'test.com',
                sink:    sink,
                encoder: Encoders::Hex,
              )

              result = @resolv.getresources('414243444546474849.test.com', Resolv::DNS::Resource::IN::SOA).pop
              assert_nil(result)
            ensure
              driver.kill
            end
          end
        end

        def test_passthrough_servers
          @mutex.synchronize do
            begin
              driver = Driver.new(host: '127.0.0.1', port: '16243')
              assert_nil(driver.passthrough)
            ensure
              driver.kill
            end

            tests = [
              { test: 'a',       expected: { host: 'a', port: 53 } },
              { test: 'a:a',     expected: { host: 'a', port: 53 } },
              { test: 'a:53',    expected: { host: 'a', port: 53 } },
              { test: 'a:53:53', expected: { host: 'a', port: 53 } },
            ]

            tests.each do |test|
              begin
                driver = Driver.new(host: '127.0.0.1', port: '16243', passthrough: test[:test])
                assert_equal(test[:expected], driver.passthrough)
              ensure
                driver.kill
              end
            end
          end
        end

        def test_passthrough
          @mutex.synchronize do
            begin
              driver = Driver.new(host: '127.0.0.1', port: '16243')
              assert_equal([], @resolv.getaddresses('example.org').map(&:to_s).sort)
            ensure
              driver.kill
            end

            begin
              driver = Driver.new(host: '127.0.0.1', port: '16243', passthrough: '8.8.8.8')
              assert_not_equal([], @resolv.getaddresses('example.org').map(&:to_s))
            ensure
              driver.kill
            end
          end
        end

        def test_blank
          @mutex.synchronize do
            begin
              driver = Driver.new(host: '127.0.0.1', port: PORT)
              sink1 = MyTestSink.new(data: '')
              sink2 = MyTestSink.new(data: '')

              driver.add_domain(
                domain: 'test.com',
                sink:    sink1,
                encoder: Encoders::Hex,
              )

              driver.add_tag(
                tag:    'abc',
                sink:    sink2,
                encoder: Encoders::Base32,
              )

              result1 = @resolv.getaddresses('test.com').map(&:to_s).sort
              result2 = @resolv.getaddresses('abc').map(&:to_s).sort

              assert_equal(['0.0.255.255'], result1)
              assert_equal(['0.0.255.255'], result2)

              assert_equal('', sink1.data_out)
              assert_equal('', sink2.data_out)
            ensure
              driver.kill
            end
          end
        end

        def test_too_much_data
          @mutex.synchronize do
            # Way too much data
            sink = MyTestSink.new(data: 'A' * 32_767)

            driver = Driver.new(
              host:     '127.0.0.1',
              port:     '16243',
            )
            driver.add_domain(
              domain:  'test.com',
              sink:    sink,
              encoder: Encoders::Hex,
            )

            begin
              results = _resolv_a('414243444546474849.test.com')
              assert_equal([], results)
              assert_equal('ABCDEFGHI', sink.data_out)
            ensure
              driver.kill
            end
          end
        end

        def test_base32
          @mutex.synchronize do
            sink = MyTestSink.new(data: 'QWERTY')

            driver = Driver.new(
              host:     '127.0.0.1',
              port:     '16243',
            )
            driver.add_domain(
              domain:  'test.com',
              sink:    sink,
              encoder: Encoders::Base32,
            )

            begin
              results = @resolv.getresources('IFBEGRCFIzDUQSKKJNGE2.test.com', Resolv::DNS::Resource::IN::TXT).pop.data
              assert_equal('kflukusule', results)
              assert_equal('ABCDEFGHIJKLM', sink.data_out)
            ensure
              driver.kill
            end
          end
        end

        def test_nil_outgoing_message
          @mutex.synchronize do
            sink = MyTestSink.new(data: nil)

            driver = Driver.new(
              host:     '127.0.0.1',
              port:     '16243',
            )
            driver.add_domain(
              domain:  'test.com',
              sink:    sink,
              encoder: Encoders::Hex,
            )

            begin
              results = @resolv.getresources('41.test.com', Resolv::DNS::Resource::IN::TXT).pop.data
              assert_equal('', results)
              assert_equal('A', sink.data_out)
            ensure
              driver.kill
            end
          end
        end
      end
    end
  end
end
