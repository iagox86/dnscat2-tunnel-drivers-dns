# Encoding: ASCII-8BIT

require 'test_helper'

require 'dnscat2/tunnel_drivers/dns/exception'

require 'dnscat2/tunnel_drivers/dns/encoders/base32'

module Dnscat2
  module TunnelDrivers
    module DNS
      module Encoders
        class Base32Test < ::Test::Unit::TestCase
          def test_characteristics
            assert_equal('Base32 encoder', Base32::NAME)
            assert_equal(1.6, Base32::RATIO)
          end

          def test_encode
            assert_equal('',                 Base32.encode(data: 'A' * 0))
            assert_equal('ie',               Base32.encode(data: 'A' * 1))
            assert_equal('ifaq',             Base32.encode(data: 'A' * 2))
            assert_equal('ifauc',            Base32.encode(data: 'A' * 3))
            assert_equal('ifaucqi',          Base32.encode(data: 'A' * 4))
            assert_equal('ifaucqkb',         Base32.encode(data: 'A' * 5))
            assert_equal('ifaucqkbie',       Base32.encode(data: 'A' * 6))
            assert_equal('ifaucqkbifaq',     Base32.encode(data: 'A' * 7))
            assert_equal('ifaucqkbifauc',    Base32.encode(data: 'A' * 8))
            assert_equal('ifaucqkbifaucqi',  Base32.encode(data: 'A' * 9))
            assert_equal('ifaucqkbifaucqkb', Base32.encode(data: 'A' * 10))
          end

          def test_decode
            assert_equal('A' * 0,  Base32.decode(data: ''))
            assert_equal('A' * 1,  Base32.decode(data: 'ie'))
            assert_equal('A' * 2,  Base32.decode(data: 'ifaq'))
            assert_equal('A' * 3,  Base32.decode(data: 'ifauc'))
            assert_equal('A' * 4,  Base32.decode(data: 'ifaucqi'))
            assert_equal('A' * 5,  Base32.decode(data: 'ifaucqkb'))
            assert_equal('A' * 6,  Base32.decode(data: 'ifaucqkbie'))
            assert_equal('A' * 7,  Base32.decode(data: 'ifaucqkbifaq'))
            assert_equal('A' * 8,  Base32.decode(data: 'ifaucqkbifauc'))
            assert_equal('A' * 9,  Base32.decode(data: 'ifaucqkbifaucqi'))
            assert_equal('A' * 10, Base32.decode(data: 'ifaucqkbifaucqkb'))
          end

          def test_decode_errors
            assert_raises(Exception) do
              Base32.decode(data: '!')
            end
            assert_raises(Exception) do
              Base32.decode(data: 'aa=aa')
            end
          end

          def test_case
            assert_equal('A' * 10, Base32.decode(data: 'IfAuCqKbIfAuCqKb'))
          end
        end
      end
    end
  end
end
