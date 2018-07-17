# Encoding: ASCII-8BIT
require 'test_helper'

require 'dnscat2/tunnel_drivers/dns/exception'
require 'dnscat2/tunnel_drivers/dns/encoders/base32'
require 'dnscat2/tunnel_drivers/dns/encoders/hex'

require 'dnscat2/tunnel_drivers/dns/builders/cname'

module Dnscat2
  module TunnelDrivers
    module DNS
      module Builders
        class NameHelperTest < ::Test::Unit::TestCase
          def test_cname_normal()
            encoder = CNAME.new(
              tag: nil,
              domain: nil,
              max_subdomain_length: 63,
              encoder: Encoders::Hex,
            )

            rr = encoder.build(data: 'AAAA').pop()

            assert_equal('41414141', rr.name)
          end

          def test_cname_with_tag()
            encoder = CNAME.new(
              tag: 'aaa',
              domain: nil,
              max_subdomain_length: 63,
              encoder: Encoders::Hex,
            )

            rr = encoder.build(data: 'AAAA').pop()

            assert_equal('aaa.41414141', rr.name)
          end

          def test_cname_with_domain()
            encoder = CNAME.new(
              tag: nil,
              domain: 'aaa',
              max_subdomain_length: 63,
              encoder: Encoders::Hex,
            )

            rr = encoder.build(data: 'AAAA').pop()

            assert_equal('41414141.aaa', rr.name)
          end

          def test_cname_with_different_subdomain_length()
            encoder = CNAME.new(
              tag: nil,
              domain: nil,
              max_subdomain_length: 3,
              encoder: Encoders::Hex,
            )

            rr = encoder.build(data: 'AAAA').pop()

            assert_equal('414.141.41', rr.name)
          end

          def test_cname_with_different_encoder()
            encoder = CNAME.new(
              tag: nil,
              domain: nil,
              max_subdomain_length: 63,
              encoder: Encoders::Base32,
            )

            rr = encoder.build(data: 'AAAA').pop()

            assert_equal('ifaucqi', rr.name)
          end

          def test_cname_with_just_less_than_too_much_data()
            encoder = CNAME.new(
              tag: nil,
              domain: nil,
              max_subdomain_length: 63,
              encoder: Encoders::Hex,
            )

            rr = encoder.build(data: 'A' * encoder.max_length()).pop()
            assert_not_nil(rr)
            assert_not_nil(rr.name)
          end

          def test_cname_with_too_much_data()
            encoder = CNAME.new(
              tag: nil,
              domain: nil,
              max_subdomain_length: 63,
              encoder: Encoders::Hex,
            )

            assert_raises(Exception) do
              encoder.build(data: 'A' * (encoder.max_length() + 1)).pop()
            end
          end

          def test_cname_with_just_less_than_too_much_data_and_a_domain()
            encoder = CNAME.new(
              tag: nil,
              domain: 'aaaaaaaaaaaaaaaaa',
              max_subdomain_length: 10,
              encoder: Encoders::Hex,
            )

            rr = encoder.build(data: 'A' * encoder.max_length()).pop()
            assert_not_nil(rr)
            assert_not_nil(rr.name)
          end

          def test_cname_with_too_much_data_and_a_domain()
            encoder = CNAME.new(
              tag: nil,
              domain: 'aaaaaaaaaaaaaaaaa',
              max_subdomain_length: 10,
              encoder: Encoders::Hex,
            )

            assert_raises(Exception) do
              encoder.build(data: 'A' * (encoder.max_length() + 1))
            end
          end
        end
      end
    end
  end
end
