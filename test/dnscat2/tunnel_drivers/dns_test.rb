require "test_helper"

module Dnscat2
  module TunnelDrivers
    module DNS
      class DnsTest < ::Test::Unit::TestCase
        def test_that_it_has_a_version_number
          assert_not_nil(::Dnscat2::TunnelDrivers::DNS::VERSION)
        end
      end
    end
  end
end
