# Encoding: ASCII-8BIT
##
# a.rb
# Created July, 2018
# By Ron Bowes
#
# See: LICENSE.md
##

require 'nesser'
require 'singlogger'
require 'thread'

require 'dnscat2/tunnel_drivers/dns/builders/builder_helper'
require 'dnscat2/tunnel_drivers/dns/encoders/hex'
require 'dnscat2/tunnel_drivers/dns/exception'

module Dnscat2
  module TunnelDrivers
    module DNS
      module Builders
        class A
          include BuilderHelper

          public
          def initialize(tag:, domain:, encoder:Encoders::Hex)
            # We don't bother saving any of the parameters, they aren't
            # necessary

            @l = SingLogger.instance()
          end

          ##
          # The maximum amount of data that can be recorded
          ##
          public
          def max_length()
            # We can fit 2 bytes in the first ip address, then 3 bytes in the
            # remaining ones
            number_of_ips = MAX_RR_LENGTH / 4
            return 2 + ((number_of_ips - 1) * 3)
          end

          ##
          # Gets a string of data, no longer than max_length().
          #
          # Returns a resource record of the correct type.
          ##
          public
          def build(data:)
            @l.debug("TunnelDrivers::DNS::Builder::A Encoding #{data.length} bytes of data")
            if(data.length > max_length)
              raise(Exception, "Tried to encode too much data!")
            end

            if(data.length > 255)
              raise(Exception, "Tried to encode more than 255 bytes of data!")
            end

            # Prefix with length
            data = [data.length, data].pack('Ca*')

            # Break into 3-byte blocks, so we can prepend a sequence number to
            # each
            i = 0
            data = data.chars.each_slice(3).map(&:join).map do |ip|
              ip = [i] + ip.ljust(3, "\xFF").bytes()
              i += 1

              '%d.%d.%d.%d' % [ip[0], ip[1], ip[2], ip[3]]
            end

            return data.map() do |ip|
              Nesser::A.new(address: ip)
            end
          end
        end
      end
    end
  end
end
