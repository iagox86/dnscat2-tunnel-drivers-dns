# Encoding: ASCII-8BIT
require 'test_helper'

require 'dnscat2/tunnel_drivers/dns/encoders/base32'
require 'dnscat2/tunnel_drivers/dns/exception'

require 'dnscat2/tunnel_drivers/dns/builders/a'

module Dnscat2
  module TunnelDrivers
    module DNS
      module Builders
        class ATest < ::Test::Unit::TestCase
          def setup()
            @builder = A.new(tag: 'abc', domain: 'def')
          end

          def test_encode_blank()
            rrs = @builder.build(data: '')
            assert_equal("0.0.255.255",  rrs[0].address.to_s)
          end

          def test_encode_some_bytes()
            rrs = @builder.build(data: "ABCDEFGHIJ")
            assert_equal(4, rrs.length)
            assert_equal("0.10.65.66",  rrs[0].address.to_s)
            assert_equal("1.67.68.69",  rrs[1].address.to_s)
            assert_equal("2.70.71.72",  rrs[2].address.to_s)
            assert_equal("3.73.74.255", rrs[3].address.to_s)
          end

          def test_encode_one_byte()
            rrs = @builder.build(data: "A")
            assert_equal(1, rrs.length)
            assert_equal("0.1.65.255", rrs[0].address.to_s)
          end

          def test_encode_one_ip()
            rrs = @builder.build(data: "\x00\x00")
            assert_equal(1, rrs.length)
            assert_equal("0.2.0.0", rrs[0].address.to_s)
          end

          def test_encode_on_boundary()
            rrs = @builder.build(data: "ABCDEFGHIJK")
            assert_equal(4, rrs.length)
            assert_equal("0.11.65.66", rrs[0].address.to_s)
            assert_equal("1.67.68.69", rrs[1].address.to_s)
            assert_equal("2.70.71.72", rrs[2].address.to_s)
            assert_equal("3.73.74.75", rrs[3].address.to_s)
          end

          def test_encode_max_bytes()
            rrs = @builder.build(data: "A" * @builder.max_length)
            assert_equal(63, rrs.length)
            assert_equal("0.188.65.65", rrs[0].address.to_s)

            1.upto(62) do |i|
              assert_equal("#{i}.65.65.65", rrs[i].address.to_s)
            end
          end

          def test_encode_max_bytes_plus_one()
            assert_raises(Exception) do
              @builder.build(data: "A" * (@builder.max_length + 1))
            end
          end
        end
      end
    end
  end
end
