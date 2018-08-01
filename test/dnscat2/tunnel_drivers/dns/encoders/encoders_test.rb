# Encoding: ASCII-8BIT

require 'test_helper'

require 'dnscat2/tunnel_drivers/dns/exception'

require 'dnscat2/tunnel_drivers/dns/encoders/base32'
require 'dnscat2/tunnel_drivers/dns/encoders/encoders'
require 'dnscat2/tunnel_drivers/dns/encoders/hex'

module Dnscat2
  module TunnelDrivers
    module DNS
      module Encoders
        class EncodersTest < ::Test::Unit::TestCase
          def test_get_by_name
            assert_equal(Encoders::Hex, Encoders.get_by_name('Hex'))
            assert_equal(Encoders::Base32, Encoders.get_by_name('baSE32'))
          end
        end
      end
    end
  end
end
