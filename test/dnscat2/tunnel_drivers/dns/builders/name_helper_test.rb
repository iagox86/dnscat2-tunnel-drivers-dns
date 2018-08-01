# Encoding: ASCII-8BIT

require 'test_helper'

require 'dnscat2/tunnel_drivers/dns/exception'
require 'dnscat2/tunnel_drivers/dns/encoders/base32'
require 'dnscat2/tunnel_drivers/dns/encoders/hex'

require 'dnscat2/tunnel_drivers/dns/builders/name_helper'

module Dnscat2
  module TunnelDrivers
    module DNS
      module Builders
        class NameHelperTest < ::Test::Unit::TestCase
          def test_max_length_different_tags
            # Start with (253 - 4 periods - 1 NUL byte) / 2 characters/byte => 125
            assert_equal(124, NameHelper.new(tag: nil,      domain: nil).max_length)

            # Prepending 'a.' means we have two less bytes, so (253 - 4 periods - 2 bytes - 1 byte) / 2 characters/byte => 125
            assert_equal(123, NameHelper.new(tag: 'a',      domain: nil).max_length)

            # Prepending 'aa.' means we have three less bytes, so (253 - 4 periods - 3 bytes - 1 byte) / 2 characters/byte => 124
            assert_equal(123, NameHelper.new(tag: 'aa',     domain: nil).max_length)

            # (253 - 4 - 4 - 1) / 2
            assert_equal(122, NameHelper.new(tag: 'aaa',    domain: nil).max_length)

            # (253 - 4 - 5 - 1) / 2
            assert_equal(122, NameHelper.new(tag: 'aaaa',   domain: nil).max_length)

            # (253 - 4 - 6 - 1) / 2
            assert_equal(121, NameHelper.new(tag: 'aaaaa',  domain: nil).max_length)

            # (253 - 4 - 7 - 1) / 2
            assert_equal(121, NameHelper.new(tag: 'aaaaaa', domain: nil).max_length)

            # Appending domains should be exactly the same as prepending a tag
            assert_equal(124, NameHelper.new(tag: nil, domain: nil).max_length)
            assert_equal(123, NameHelper.new(tag: nil, domain: 'a').max_length)
            assert_equal(123, NameHelper.new(tag: nil, domain: 'aa').max_length)
            assert_equal(122, NameHelper.new(tag: nil, domain: 'aaa').max_length)
            assert_equal(122, NameHelper.new(tag: nil, domain: 'aaaa').max_length)
            assert_equal(121, NameHelper.new(tag: nil, domain: 'aaaaa').max_length)
            assert_equal(121, NameHelper.new(tag: nil, domain: 'aaaaaa').max_length)
          end

          def test_max_length_different_segment_lengths
            # The math to calculate these "correct" values is annoying.. it's 253 - ceil(253 / n + 1) / 2
            # The 253 is the max RR size (254) minus one for the NUL byte
            assert_equal(63,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 1).max_length)
            assert_equal(84,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 2).max_length)
            assert_equal(94,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 3).max_length)
            assert_equal(101,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 4).max_length)
            assert_equal(105,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 5).max_length)
            assert_equal(108,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 6).max_length)
            assert_equal(110,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 7).max_length)
            assert_equal(112,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 8).max_length)
            assert_equal(113,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 9).max_length)
            assert_equal(115,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 10).max_length)
            assert_equal(115,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 11).max_length)
            assert_equal(116,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 12).max_length)
            assert_equal(117,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 13).max_length)
            assert_equal(118,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 14).max_length)
            assert_equal(118,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 15).max_length)
            assert_equal(119,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 16).max_length)
            assert_equal(119,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 17).max_length)
            assert_equal(119,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 18).max_length)
            assert_equal(120,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 19).max_length)
            assert_equal(120,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 20).max_length)
            assert_equal(120,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 21).max_length)
            assert_equal(121,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 22).max_length)
            assert_equal(121,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 23).max_length)
            assert_equal(121,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 24).max_length)
            assert_equal(121,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 25).max_length)
            assert_equal(121,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 26).max_length)
            assert_equal(121,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 27).max_length)
            assert_equal(122,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 28).max_length)
            assert_equal(122,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 29).max_length)
            assert_equal(122,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 30).max_length)
            assert_equal(122,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 31).max_length)
            assert_equal(122,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 32).max_length)
            assert_equal(122,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 33).max_length)
            assert_equal(122,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 34).max_length)
            assert_equal(122,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 35).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 36).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 37).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 38).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 39).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 40).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 41).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 42).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 43).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 44).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 45).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 46).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 47).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 48).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 49).max_length)
            assert_equal(124,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 50).max_length)
            assert_equal(124,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 51).max_length)
            assert_equal(124,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 52).max_length)
            assert_equal(124,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 53).max_length)
            assert_equal(124,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 54).max_length)
            assert_equal(124,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 55).max_length)
            assert_equal(124,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 56).max_length)
            assert_equal(124,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 57).max_length)
            assert_equal(124,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 58).max_length)
            assert_equal(124,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 59).max_length)
            assert_equal(124,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 60).max_length)
            assert_equal(124,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 61).max_length)
            assert_equal(124,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 62).max_length)
            assert_equal(124,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 63).max_length)
          end

          def test_encode
            tests = [
              # Pretty normal test
              { tag: nil,   domain: nil,   data: 'AAAA', expected: '41414141',        max_subdomain_length: 63, encoder: Encoders::Hex },

              # Subdomain length of 1
              { tag: nil,   domain: nil,   data: 'AAAA', expected: '4.1.4.1.4.1.4.1', max_subdomain_length: 1, encoder: Encoders::Hex },

              # Add a tag
              { tag: 'abc', domain: nil,   data: 'AAAA', expected: 'abc.41414141',    max_subdomain_length: 63, encoder: Encoders::Hex },

              # Add a domain
              { tag: nil,   domain: 'abc', data: 'AAAA', expected: '41414141.abc',    max_subdomain_length: 63, encoder: Encoders::Hex },

              # Same tests, in Base32
              { tag: nil,   domain: nil,   data: 'AAAA', expected: 'ifaucqi',         max_subdomain_length: 63, encoder: Encoders::Base32 },

              # Subdomain length of 1
              { tag: nil,   domain: nil,   data: 'AAAA', expected: 'i.f.a.u.c.q.i',   max_subdomain_length: 1, encoder: Encoders::Base32 },

              # Add a tag
              { tag: 'abc', domain: nil,   data: 'AAAA', expected: 'abc.ifaucqi',     max_subdomain_length: 63, encoder: Encoders::Base32 },

              # Add a domain
              { tag: nil,   domain: 'abc', data: 'AAAA', expected: 'ifaucqi.abc',     max_subdomain_length: 63, encoder: Encoders::Base32 },

            ]

            tests.each do |t|
              helper = NameHelper.new(tag: t[:tag], domain: t[:domain], max_subdomain_length: t[:max_subdomain_length], encoder: t[:encoder])
              name = helper.encode_name(data: t[:data])
              assert_equal(t[:expected], name)
            end
          end

          def test_push_length_boundary
            # This will mostly fail on its own if it creates a message that's too long
            1.upto(63) do |subdomain_length|
              0.upto(250) do |domain_length|
                # Hex
                n = NameHelper.new(tag: nil, domain: 'A' * domain_length, max_subdomain_length: subdomain_length)
                assert_not_nil(n.encode_name(data: ('a' * n.max_length)))

                # Base32
                n = NameHelper.new(tag: nil, domain: 'A' * domain_length, max_subdomain_length: subdomain_length, encoder: Encoders::Base32)
                assert_not_nil(n.encode_name(data: ('a' * n.max_length)))
              end
            end
          end
        end
      end
    end
  end
end
