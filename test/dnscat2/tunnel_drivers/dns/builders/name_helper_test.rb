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
          def test_max_length_different_tags()
            # Start with (253 - 4 periods - 1 NUL byte) / 2 characters/byte => 125
            assert_equal(124, NameHelper.new(tag: nil,      domain: nil, extra_bytes: 0).max_length)

            # Prepending 'a.' means we have two less bytes, so (253 - 4 periods - 2 bytes - 1 byte) / 2 characters/byte => 125
            assert_equal(123, NameHelper.new(tag: 'a',      domain: nil, extra_bytes: 0).max_length)

            # Prepending 'aa.' means we have three less bytes, so (253 - 4 periods - 3 bytes - 1 byte) / 2 characters/byte => 124
            assert_equal(122, NameHelper.new(tag: 'aa',     domain: nil, extra_bytes: 0).max_length)

            # (253 - 4 - 4 - 1) / 2
            assert_equal(122, NameHelper.new(tag: 'aaa',    domain: nil, extra_bytes: 0).max_length)

            # (253 - 4 - 5 - 1) / 2
            assert_equal(121, NameHelper.new(tag: 'aaaa',   domain: nil, extra_bytes: 0).max_length)

            # (253 - 4 - 6 - 1) / 2
            assert_equal(121, NameHelper.new(tag: 'aaaaa',  domain: nil, extra_bytes: 0).max_length)

            # (253 - 4 - 7 - 1) / 2
            assert_equal(120, NameHelper.new(tag: 'aaaaaa', domain: nil, extra_bytes: 0).max_length)

            # Appending domains should be exactly the same as prepending a tag
            assert_equal(124, NameHelper.new(tag: nil, domain: nil,      extra_bytes: 0).max_length)
            assert_equal(123, NameHelper.new(tag: nil, domain: 'a',      extra_bytes: 0).max_length)
            assert_equal(122, NameHelper.new(tag: nil, domain: 'aa',     extra_bytes: 0).max_length)
            assert_equal(122, NameHelper.new(tag: nil, domain: 'aaa',    extra_bytes: 0).max_length)
            assert_equal(121, NameHelper.new(tag: nil, domain: 'aaaa',   extra_bytes: 0).max_length)
            assert_equal(121, NameHelper.new(tag: nil, domain: 'aaaaa' , extra_bytes: 0).max_length)
            assert_equal(120, NameHelper.new(tag: nil, domain: 'aaaaaa', extra_bytes: 0).max_length)

            # Use 'extra bytes' the same way
            assert_equal(124, NameHelper.new(tag: nil, domain: nil, extra_bytes: 0).max_length)
            assert_equal(123, NameHelper.new(tag: nil, domain: nil, extra_bytes: 1).max_length)
            assert_equal(123, NameHelper.new(tag: nil, domain: nil, extra_bytes: 2).max_length)
            assert_equal(122, NameHelper.new(tag: nil, domain: nil, extra_bytes: 3).max_length)
            assert_equal(122, NameHelper.new(tag: nil, domain: nil, extra_bytes: 4).max_length)
            assert_equal(121, NameHelper.new(tag: nil, domain: nil, extra_bytes: 5).max_length)
            assert_equal(121, NameHelper.new(tag: nil, domain: nil, extra_bytes: 6).max_length)
            assert_equal(120, NameHelper.new(tag: nil, domain: nil, extra_bytes: 7).max_length)
          end

          def test_max_length_different_segment_lengths()
            # The math to calculate these "correct" values is annoying.. it's 252 - ceil(252 / n + 1) / 2
            # The 252 is the max RR size (253) minus one for the NUL byte
            assert_equal(63,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 1,  extra_bytes: 0).max_length)
            assert_equal(84,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 2,  extra_bytes: 0).max_length)
            assert_equal(94,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 3,  extra_bytes: 0).max_length)
            assert_equal(100,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 4,  extra_bytes: 0).max_length)
            assert_equal(105,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 5,  extra_bytes: 0).max_length)
            assert_equal(108,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 6,  extra_bytes: 0).max_length)
            assert_equal(110,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 7,  extra_bytes: 0).max_length)
            assert_equal(112,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 8,  extra_bytes: 0).max_length)
            assert_equal(113,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 9,  extra_bytes: 0).max_length)
            assert_equal(114,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 10,  extra_bytes: 0).max_length)
            assert_equal(115,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 11,  extra_bytes: 0).max_length)
            assert_equal(116,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 12,  extra_bytes: 0).max_length)
            assert_equal(117,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 13,  extra_bytes: 0).max_length)
            assert_equal(117,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 14,  extra_bytes: 0).max_length)
            assert_equal(118,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 15,  extra_bytes: 0).max_length)
            assert_equal(118,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 16,  extra_bytes: 0).max_length)
            assert_equal(119,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 17,  extra_bytes: 0).max_length)
            assert_equal(119,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 18,  extra_bytes: 0).max_length)
            assert_equal(119,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 19,  extra_bytes: 0).max_length)
            assert_equal(120,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 20,  extra_bytes: 0).max_length)
            assert_equal(120,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 21,  extra_bytes: 0).max_length)
            assert_equal(120,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 22,  extra_bytes: 0).max_length)
            assert_equal(120,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 23,  extra_bytes: 0).max_length)
            assert_equal(120,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 24,  extra_bytes: 0).max_length)
            assert_equal(121,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 25,  extra_bytes: 0).max_length)
            assert_equal(121,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 26,  extra_bytes: 0).max_length)
            assert_equal(121,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 27,  extra_bytes: 0).max_length)
            assert_equal(121,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 28,  extra_bytes: 0).max_length)
            assert_equal(121,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 29,  extra_bytes: 0).max_length)
            assert_equal(121,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 30,  extra_bytes: 0).max_length)
            assert_equal(122,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 31,  extra_bytes: 0).max_length)
            assert_equal(122,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 32,  extra_bytes: 0).max_length)
            assert_equal(122,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 33,  extra_bytes: 0).max_length)
            assert_equal(122,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 34,  extra_bytes: 0).max_length)
            assert_equal(122,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 35,  extra_bytes: 0).max_length)
            assert_equal(122,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 36,  extra_bytes: 0).max_length)
            assert_equal(122,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 37,  extra_bytes: 0).max_length)
            assert_equal(122,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 38,  extra_bytes: 0).max_length)
            assert_equal(122,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 39,  extra_bytes: 0).max_length)
            assert_equal(122,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 40,  extra_bytes: 0).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 41,  extra_bytes: 0).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 42,  extra_bytes: 0).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 43,  extra_bytes: 0).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 44,  extra_bytes: 0).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 45,  extra_bytes: 0).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 46,  extra_bytes: 0).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 47,  extra_bytes: 0).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 48,  extra_bytes: 0).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 49,  extra_bytes: 0).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 50,  extra_bytes: 0).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 51,  extra_bytes: 0).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 52,  extra_bytes: 0).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 53,  extra_bytes: 0).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 54,  extra_bytes: 0).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 55,  extra_bytes: 0).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 56,  extra_bytes: 0).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 57,  extra_bytes: 0).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 58,  extra_bytes: 0).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 59,  extra_bytes: 0).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 60,  extra_bytes: 0).max_length)
            assert_equal(123,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 61,  extra_bytes: 0).max_length)
            assert_equal(124,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 62,  extra_bytes: 0).max_length)
            assert_equal(124,  NameHelper.new(tag: nil, domain: nil, max_subdomain_length: 63,  extra_bytes: 0).max_length)

          end

          def test_encode()
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
              helper = NameHelper.new(tag: t[:tag], domain: t[:domain], max_subdomain_length: t[:max_subdomain_length], encoder: t[:encoder], extra_bytes: 0)
              name = helper.encode_name(data: t[:data])
              assert_equal(t[:expected], name)
            end
          end

          def test_push_length_boundary()
            # This will mostly fail on its own if it creates a message that's too long
            1.upto(63) do |subdomain_length|
              0.upto(250) do |domain_length|
                #puts("subdomain #{subdomain_length}, domain #{domain_length}...")
                # Hex
                n = NameHelper.new(tag: nil, domain: 'A' * domain_length, max_subdomain_length: subdomain_length, extra_bytes: 0)
                assert_not_nil(n.encode_name(data: ('a' * n.max_length)))

                # Base32
                n = NameHelper.new(tag: nil, domain: 'A' * domain_length, max_subdomain_length: subdomain_length, encoder: Encoders::Base32, extra_bytes: 0)
                assert_not_nil(n.encode_name(data: ('a' * n.max_length)))
              end
            end
          end
        end
      end
    end
  end
end
