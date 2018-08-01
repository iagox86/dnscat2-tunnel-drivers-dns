# Encoding: ASCII-8BIT

require 'test_helper'

require 'nesser'

require 'dnscat2/tunnel_drivers/dns/encoders/base32'
require 'dnscat2/tunnel_drivers/dns/encoders/hex'
require 'dnscat2/tunnel_drivers/dns/exception'

require 'dnscat2/tunnel_drivers/dns/readers/standard'

module Dnscat2
  module TunnelDrivers
    module DNS
      module Readers
        class StandardTest < ::Test::Unit::TestCase
          def setup
            @reader = Readers::Standard.new
          end

          def test_unrecognized
            data = @reader.try_domain(name: 'hello.this.com', domain: 'test.com', encoder: Encoders::Hex)
            assert_nil(data)

            data = @reader.try_tag(name: 'hello.this.com', tag: 'abc', encoder: Encoders::Hex)
            assert_nil(data)
          end

          def test_known_domain_and_tag
            data = @reader.try_domain(name: '41414141.test.com', domain: 'test.com', encoder: Encoders::Hex)
            assert_equal('AAAA', data)

            data = @reader.try_tag(name: 'abc.41414141', tag: 'abc', encoder: Encoders::Hex)
            assert_equal('AAAA', data)
          end

          def test_periods_matter_when_they_matter
            data = @reader.try_domain(name: '414141.41test.com', domain: 'test.com', encoder: Encoders::Hex)
            assert_nil(data)

            data = @reader.try_tag(name: 'abc41.414141', tag: 'abc', encoder: Encoders::Hex)
            assert_nil(data)
          end

          def test_periods_dont_matter_when_they_dont_matter
            data = @reader.try_domain(name: '4.14.141.41.test.com', domain: 'test.com', encoder: Encoders::Hex)
            assert_equal('AAAA', data)

            data = @reader.try_tag(name: 'abc.41.414.14.1', tag: 'abc', encoder: Encoders::Hex)
            assert_equal('AAAA', data)
          end

          def test_case_is_insensitive_in_tag_and_domain
            data = @reader.try_domain(name: '41414141.tEST.COm', domain: 'test.com', encoder: Encoders::Hex)
            assert_equal('AAAA', data)

            data = @reader.try_tag(name: 'aBc.41414141', tag: 'abc', encoder: Encoders::Hex)
            assert_equal('AAAA', data)
          end

          def test_case_is_insensitive_in_data
            data = @reader.try_domain(name: '4a4B4c4D.test.com', domain: 'test.com', encoder: Encoders::Hex)
            assert_equal('JKLM', data)

            data = @reader.try_tag(name: 'abc.4D4c4B4a', tag: 'abc', encoder: Encoders::Hex)
            assert_equal('MLKJ', data)
          end

          def test_no_data
            data = @reader.try_domain(name: 'test.com', domain: 'test.com', encoder: Encoders::Hex)
            assert_equal('', data)

            data = @reader.try_tag(name: 'abc', tag: 'abc', encoder: Encoders::Hex)
            assert_equal('', data)
          end

          def test_base32
            data = @reader.try_domain(name: 'ifaucqi.test.com', domain: 'test.com', encoder: Encoders::Base32)
            assert_equal('AAAA', data)

            data = @reader.try_tag(name: 'abc.ifaucqi', tag: 'abc', encoder: Encoders::Base32)
            assert_equal('AAAA', data)
          end
        end
      end
    end
  end
end
