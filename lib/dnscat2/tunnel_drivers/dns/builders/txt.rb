# Encoding: ASCII-8BIT

##
# txt.rb
# Created March, 2013
# By Ron Bowes
#
# See: LICENSE.md
##

require 'nesser'
require 'singlogger'

require 'dnscat2/tunnel_drivers/dns/builders/builder_helper'
require 'dnscat2/tunnel_drivers/dns/builders/name_helper'
require 'dnscat2/tunnel_drivers/dns/encoders/hex'
require 'dnscat2/tunnel_drivers/dns/exception'

module Dnscat2
  module TunnelDrivers
    module DNS
      module Builders
        ##
        # Encode into a TXT record.
        ##
        class TXT
          include BuilderHelper

          public
          def initialize(tag:, domain:, encoder: Encoders::Hex)
            @l = SingLogger.instance
            @tag = tag
            @domain = domain
            @encoder = encoder
          end

          ##
          # The maximum length of data that can be encoded, including pre- or
          # appending tags and domain names.
          ##
          public
          def max_length
            # Max length of a TXT record is straight up 255 bytes
            return (255 / @encoder::RATIO).floor
          end

          ##
          # Gets a string of data, no longer than max_length().
          #
          # Returns a resource record of the correct type.
          ##
          public
          def build(data:)
            @l.debug("TunnelDrivers::DNS::Builders::TXT Encoding #{data.length} bytes of data")
            if data.length > max_length
              raise(Exception, 'Tried to encode too much data!')
            end

            # Note: we still encode TXT records, because some OSes have trouble
            # with null-bytes in TXT records (I'm looking at you, Windows)
            data = @encoder.encode(data: data)

            # Always double check that we aren't too big for a DNS packet
            rr = Nesser::TXT.new(data: data)
            double_check_length(rrs: [rr])
            return [rr]
          end
        end
      end
    end
  end
end
