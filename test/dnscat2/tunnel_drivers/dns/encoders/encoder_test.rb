# Encoding: ASCII-8BIT
require 'test_helper'

require 'dnscat2/tunnel_drivers/dns/exception'

require 'dnscat2/tunnel_drivers/dns/encoders/base32'
require 'dnscat2/tunnel_drivers/dns/encoders/encoder'
require 'dnscat2/tunnel_drivers/dns/encoders/hex'

module Dnscat2
  module TunnelDrivers
    module DNS
      module Encoders
        class HexTest < ::Test::Unit::TestCase
          def setup()
            @encoder = Encoder.new(default: Encoders::Hex, secondary: Encoders::Base32)
          end

          def test_simple_use()
            d, encoder = @encoder.decode(data: '41414141')
            assert_equal('AAAA', d)
            assert_equal(Encoders::Hex, encoder)

            e = @encoder.encode(data: 'BBBB', encoder: encoder)
            assert_equal('42424242', e)
          end

          def test_combined()
            # Use it as hex
            result = @encoder.decode_encode(data: '41414141') do |data|
              assert_equal('AAAA', data)
              'BBBB' # return
            end
            assert_equal('42424242', result)

            # Use it as base32
            result = @encoder.decode_encode(data: 'M-FRggzdFMY') do |data|
              assert_equal('abcdef', data)
              'BBBB' # return
            end
            assert_equal('ijbeeqq', result)
          end

          def test_unknown_encoder()
            assert_raises(Exception) do
              Encoder.new(default: 'nope')
            end
          end
        end
      end
    end
  end
end
