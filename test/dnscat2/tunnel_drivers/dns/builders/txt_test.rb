# Encoding: ASCII-8BIT
require 'test_helper'

require 'dnscat2/tunnel_drivers/dns/encoders/base32'
require 'dnscat2/tunnel_drivers/dns/exception'

require 'dnscat2/tunnel_drivers/dns/builders/txt'

module Dnscat2
  module TunnelDrivers
    module DNS
      module Builders
        class TXTTest < ::Test::Unit::TestCase
          def setup()
            @builder = TXT.new(tag: 'abc', domain: 'def')
          end

          def test_max_length()
            assert_equal(125, @builder.max_length)
          end

          def test_encode_blank()
            rr = @builder.build(data: '').pop()

            assert_equal('', rr.data)
          end

          def test_encode_max_bytes()
            rr = @builder.build(data: 'A' * @builder.max_length()).pop()
            assert_equal('41' * @builder.max_length, rr.data)
          end

          def test_encode_128_bytes()
            e = assert_raises(Exception) do
              @builder.build(data: 'A' * (@builder.max_length() + 1))
            end

            assert_not_nil(e.message =~ /too much data/)
          end

          def test_encode_base32()
            encoder = TXT.new(tag: 'abc', domain: nil, encoder: Encoders::Base32)
            rr = encoder.build(data: 'AaAaAaAa').pop()

            assert_equal('ifqucykbmfawc', rr.data)
          end
        end
      end
    end
  end
end
