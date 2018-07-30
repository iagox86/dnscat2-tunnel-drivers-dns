# Encoding: ASCII-8BIT

##
# hex.rb
# Created March, 2018
# By Ron Bowes
#
# See: LICENSE.md
##

require 'dnscat2/tunnel_drivers/dns/exception'

module Dnscat2
  module TunnelDrivers
    module DNS
      module Encoders
        ##
        # Encodes data to or from hex ('AAA' => '414141')
        ##
        class Hex
          NAME = 'Hex encoder'.freeze
          RATIO = 2.0
          DESCRIPTION = "Encodes to hex; for example, 'AAA' becomes '414141'. This is the simplest encoder (other than plaintext), but also the least efficient.".freeze
          CHARSET = /^[a-f0-9]*$/

          public
          def self.encode(data:)
            return data.unpack('H*').pop
          end

          public
          def self.decode(data:)
            if data !~ CHARSET
              raise(Exception, "Data isn't hex encoded!")
            end
            if data.length.odd?
              raise(Exception, "Data isn't proper hex (it should have an even number of characters)!")
            end

            return [data].pack('H*')
          end
        end
      end
    end
  end
end
