# Encoding: ASCII-8BIT

##
# encoders.rb
# Created March, 2018
# By Ron Bowes
#
# See: LICENSE.md
##

require 'dnscat2/tunnel_drivers/dns/exception'
require 'dnscat2/tunnel_drivers/dns/encoders/hex'
require 'dnscat2/tunnel_drivers/dns/encoders/base32'

module Dnscat2
  module TunnelDrivers
    module DNS
      ##
      # An easier way to access the encoders.
      ##
      module Encoders
        def self.get_by_name(name)
          if name.casecmp('hex').zero?
            return Hex
          elsif name.casecmp('base32').zero?
            return Base32
          end

          raise(Exception, "Unknown encoder: #{name}")
        end
      end
    end
  end
end
