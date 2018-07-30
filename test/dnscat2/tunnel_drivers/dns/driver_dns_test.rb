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

      class DriverTest < ::Test::Unit::TestCase
        PORT = 16_243

        def setup
          @mutex = Mutex.new
          @resolv = ::Resolv::DNS.new(nameserver_port: [['127.0.0.1', PORT]])
        end

        def _resolv_a(name)
          return @resolv.getaddresses(name).map(&:to_s).sort
        end

        def test_start_stop
          @mutex.synchronize do
            sink = MyTestSink.new(data: 'BBBBBBBBBB')

            driver = Driver.new(
              tags:     ['abc', 'def'],
              domains:  ['test1.com', 'test2.com'],
              sink:     sink,
              host:     '127.0.0.1',
              port:     PORT,
            )
            driver.start

            begin
              # Use our DNS server with a different DNS tool to make sure it works
              addresses = _resolv_a('41414141.test1.com')
              assert_equal(['0.10.66.66', '1.66.66.66', '2.66.66.66', '3.66.66.255'], addresses)
              assert_equal('AAAA', sink.data_out)

              # Stop the driver
              driver.stop

              # Make sure it's stopped
              assert_equal([], _resolv_a('41414141.test1.com'))

              # Start it again
              driver.start

              # Resolve again
              addresses = _resolv_a('44444444.test1.com')

              # Check if it equals the data we planned to send
              assert_equal(['0.10.66.66', '1.66.66.66', '2.66.66.66', '3.66.66.255'], addresses)
              assert_equal('DDDD', sink.data_out)
            ensure
              # Close everything
              driver.stop
            end
          end
        end

        def test_tags
          @mutex.synchronize do
            sink = MyTestSink.new(data: 'A')

            driver = Driver.new(
              tags:     ['abc', 'def'],
              domains:  ['test1.com', 'test2.com'],
              sink:     sink,
              host:     '127.0.0.1',
              port:     '16243',
            )
            driver.start

            begin
              # Try using the first tag ('abc.')
              addresses = _resolv_a('abc.41424344')
              assert_equal(['0.1.65.255'], addresses)
              assert_equal('ABCD', sink.data_out)

              # Try using the second tag ('def.')
              addresses = _resolv_a('def.45464748')
              assert_equal(['0.1.65.255'], addresses)
              assert_equal('EFGH', sink.data_out)
            ensure
              driver.stop
            end
          end
        end

        def test_domains
          @mutex.synchronize do
            sink = MyTestSink.new(data: 'A')

            driver = Driver.new(
              tags:     ['abc', 'def'],
              domains:  ['test1.com', 'test2.com'],
              sink:     sink,
              host:     '127.0.0.1',
              port:     '16243',
            )
            driver.start

            begin
              # Try using the first domain ('.test1.com')
              addresses = _resolv_a('41424344.test1.com')
              assert_equal(['0.1.65.255'], addresses)
              assert_equal('ABCD', sink.data_out)

              # Try using the second domain ('.test2.com')
              addresses = _resolv_a('45464748.test2.com')
              assert_equal(['0.1.65.255'], addresses)
              assert_equal('EFGH', sink.data_out)
            ensure
              driver.stop
            end
          end
        end

        def test_no_tag_nor_domain
          @mutex.synchronize do
            sink = MyTestSink.new(data: 'A')

            driver = Driver.new(
              tags:     ['abc', 'def'],
              domains:  ['test1.com', 'test2.com'],
              sink:     sink,
              host:     '127.0.0.1',
              port:     '16243',
            )
            driver.start

            begin
              addresses = _resolv_a('414243444546474849')
              assert_equal([], addresses)
              assert_nil(sink.data_out)
            ensure
              driver.stop
            end
          end
        end

        def test_aaaa_record
          @mutex.synchronize do
            sink = MyTestSink.new(data: 'QWERTYQWERTYQWERTY')

            driver = Driver.new(
              tags:     [],
              domains:  ['test1.com'],
              sink:     sink,
              host:     '127.0.0.1',
              port:     '16243',
            )
            driver.start

            begin
              results = @resolv.getresources('414243444546474849.test1.com', Resolv::DNS::Resource::IN::AAAA).map { |a| a.address.to_s }.sort

              assert_equal(['12:5157:4552:5459:5157:4552:5459:5157',
                            '145:5254:59FF:FFFF:FFFF:FFFF:FFFF:FFFF'], results)
              assert_equal('ABCDEFGHI', sink.data_out)
            ensure
              driver.stop
            end
          end
        end

        def test_cname_record_with_domain
          @mutex.synchronize do
            sink = MyTestSink.new(data: 'QWERTY')

            driver = Driver.new(
              tags:     ['abc'],
              domains:  ['test1.com'],
              sink:     sink,
              host:     '127.0.0.1',
              port:     '16243',
            )
            driver.start

            begin
              results = @resolv.getresources('414243444546474849.test1.com', Resolv::DNS::Resource::IN::CNAME).pop.name.to_s
              assert_equal('515745525459.test1.com', results)
              assert_equal('ABCDEFGHI', sink.data_out)
            ensure
              driver.stop
            end
          end
        end

        def test_cname_record_with_tag
          @mutex.synchronize do
            sink = MyTestSink.new(data: 'QWERTY')

            driver = Driver.new(
              tags:     ['abc'],
              domains:  ['test1.com'],
              sink:     sink,
              host:     '127.0.0.1',
              port:     '16243',
            )
            driver.start

            begin
              results = @resolv.getresources('abc.414243444546474849', Resolv::DNS::Resource::IN::CNAME).pop.name.to_s
              assert_equal('abc.515745525459', results)
              assert_equal('ABCDEFGHI', sink.data_out)
            ensure
              driver.stop
            end
          end
        end

        def test_mx_record
          @mutex.synchronize do
            sink = MyTestSink.new(data: 'QWERTY')

            driver = Driver.new(
              tags:     ['abc'],
              domains:  ['test1.com'],
              sink:     sink,
              host:     '127.0.0.1',
              port:     '16243',
            )
            driver.start

            begin
              results = @resolv.getresources('414243444546474849.test1.com', Resolv::DNS::Resource::IN::MX).pop.exchange.to_s
              assert_equal('515745525459.test1.com', results)
              assert_equal('ABCDEFGHI', sink.data_out)
            ensure
              driver.stop
            end
          end
        end

        def test_ns_record
          @mutex.synchronize do
            sink = MyTestSink.new(data: 'QWERTY')

            driver = Driver.new(
              tags:     ['abc'],
              domains:  ['test1.com'],
              sink:     sink,
              host:     '127.0.0.1',
              port:     '16243',
            )
            driver.start

            begin
              results = @resolv.getresources('414243444546474849.test1.com', Resolv::DNS::Resource::IN::NS).pop.name.to_s
              assert_equal('515745525459.test1.com', results)
              assert_equal('ABCDEFGHI', sink.data_out)
            ensure
              driver.stop
            end
          end
        end

        def test_txt_record
          @mutex.synchronize do
            sink = MyTestSink.new(data: 'QWERTY')

            driver = Driver.new(
              tags:     ['abc'],
              domains:  ['test1.com'],
              sink:     sink,
              host:     '127.0.0.1',
              port:     '16243',
            )
            driver.start

            begin
              results = @resolv.getresources('414243444546474849.test1.com', Resolv::DNS::Resource::IN::TXT).pop.data
              assert_equal('515745525459', results)
              assert_equal('ABCDEFGHI', sink.data_out)
            ensure
              driver.stop
            end
          end
        end

        def test_any
          @mutex.synchronize do
            sink = MyTestSink.new(data: 'AA')

            driver = Driver.new(
              tags:     ['abc'],
              domains:  ['test1.com'],
              sink:     sink,
              host:     '127.0.0.1',
              port:     '16243',
            )
            driver.start

            begin
              # Do this enough times that we should randomly select every type
              # of ANY
              100.times do
                result = @resolv.getresources('414243444546474849.test1.com', Resolv::DNS::Resource::IN::ANY).pop

                if result.respond_to?(:name)
                  assert_equal('4141.test1.com', result.name.to_s)
                elsif result.respond_to?(:address)
                  assert_equal('0.2.65.65', result.address.to_s)
                elsif result.respond_to?(:exchange)
                  assert_equal('4141.test1.com', result.exchange.to_s)
                elsif result.respond_to?(:data)
                  assert_equal('4141', result.data)
                else
                  puts(result.class)
                  puts(result.methods)
                  assert_equal("Unknown result type: #{result}", '')
                end

                assert_equal('ABCDEFGHI', sink.data_out)
              end
            ensure
              driver.stop
            end
          end
        end

        def test_unknown_record_type
          @mutex.synchronize do
            sink = MyTestSink.new(data: 'AA')

            driver = Driver.new(
              tags:     ['abc'],
              domains:  ['test1.com'],
              sink:     sink,
              host:     '127.0.0.1',
              port:     '16243',
            )
            driver.start

            begin
              result = @resolv.getresources('414243444546474849.test1.com', Resolv::DNS::Resource::IN::SOA).pop
              assert_nil(result)
            ensure
              driver.stop
            end
          end
        end

        def test_too_much_data
          @mutex.synchronize do
            # Way too much data
            sink = MyTestSink.new(data: 'A' * 1024)

            driver = Driver.new(
              tags:     ['abc'],
              domains:  ['test1.com'],
              sink:     sink,
              host:     '127.0.0.1',
              port:     '16243',
            )
            driver.start

            begin
              results = _resolv_a('414243444546474849.test1.com')
              assert_equal([], results)
              assert_equal('ABCDEFGHI', sink.data_out)
            ensure
              driver.stop
            end
          end
        end

        def test_bad_start_stop_state
          @mutex.synchronize do
            sink = MyTestSink.new(data: 'BBBBBBBBBB')

            driver = Driver.new(
              tags:     ['abc', 'def'],
              domains:  ['test1.com', 'test2.com'],
              sink:     sink,
              host:     '127.0.0.1',
              port:     PORT,
            )

            assert_raises(Exception) do
              driver.stop
            end

            driver.start

            assert_raises(Exception) do
              driver.start
            end

            driver.stop

            assert_raises(Exception) do
              driver.stop
            end
          end
        end

        def test_base32
          @mutex.synchronize do
            sink = MyTestSink.new(data: 'QWERTY')

            driver = Driver.new(
              tags:     ['abc'],
              domains:  ['test1.com'],
              sink:     sink,
              host:     '127.0.0.1',
              port:     '16243',
              encoder:  'base32',
            )
            driver.start

            begin
              results = @resolv.getresources('IFBEGRCFIzDUQSKKJNGE2.test1.com', Resolv::DNS::Resource::IN::TXT).pop.data
              assert_equal('kflukusule', results)
              assert_equal('ABCDEFGHIJKLM', sink.data_out)
            ensure
              driver.stop
            end
          end
        end

        def test_nil_outgoing_message
          @mutex.synchronize do
            sink = MyTestSink.new(data: nil)

            driver = Driver.new(
              tags:     ['abc'],
              domains:  ['test1.com'],
              sink:     sink,
              host:     '127.0.0.1',
              port:     '16243',
              encoder:  'hex',
            )
            driver.start

            begin
              results = @resolv.getresources('41.test1.com', Resolv::DNS::Resource::IN::TXT).pop.data
              assert_equal('', results)
              assert_equal('A', sink.data_out)
            ensure
              driver.stop
            end
          end
        end
      end
    end
  end
end
