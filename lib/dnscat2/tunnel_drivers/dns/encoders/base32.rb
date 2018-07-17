# Encoding: ASCII-8BIT
##
# base32.rb
# Created March, 2018
# By Ron Bowes
#
# See: LICENSE.md
##

require 'base32'

require 'dnscat2/tunnel_drivers/dns/exception'

module Dnscat2
  module TunnelDrivers
    module DNS
      module Encoders
        class Base32
          NAME = "Base32 encoder"
          RATIO = 1.6
          DESCRIPTION = "Encodes to base32, which is letters and digits only"
          CHARSET = /^[A-Z2-7]*$/

          public
          def self.encode(data:)
            # Encode the data, remove the trailing '=' signs, and downcase it
            return ::Base32.encode(data).gsub(/=*$/, '').downcase
          end

          public
          def self.decode(data:)
            # Always force the data to be uppercase
            data = data.upcase

            if(data !~ CHARSET)
              raise(Exception, "Data isn't base32 encoded: #{data}")
            end

            # Fix the base32 string (uppercase, padded to a multiple of 8)
            # Even though the library we're using just strips off the '=' signs,
            # it's still a good idea to re-add them!
            data = data + '=' * ((8 - (data.length % 8)) % 8)

            begin
              return ::Base32.decode(data)

            # Because of my check above, I'm not 100% sure that these are
            # possible, but doesn't hurt to validate
            rescue ArgumentError => e
              raise(Exception, "Illegal Base32 string: #{e}")
            rescue TypeError => e
              raise(Exception, "Illegal Base32 string: #{e}")
            end
          end
        end
      end
    end
  end
end
