# Encoding: ASCII-8BIT
##
# mx.rb
# Created July, 2018
# By Ron Bowes
#
# See: LICENSE.md
##

require 'nesser'
require 'singlogger'
require 'thread'

require 'dnscat2/tunnel_drivers/dns/builders/builder_helper'
require 'dnscat2/tunnel_drivers/dns/builders/name_helper'
require 'dnscat2/tunnel_drivers/dns/constants'

module Dnscat2
  module TunnelDrivers
    module DNS
      module Builders
        class MX < NameHelper
          include BuilderHelper

          public
          def initialize(tag:, domain:, max_subdomain_length: 63, encoder: Encoders::Hex)
            # CNAME has 4 extra bytes: the 4-byte length field
            super(tag:tag, domain:domain, max_subdomain_length: max_subdomain_length, encoder: encoder, extra_bytes: 4)

            @l = SingLogger.instance()
          end

          ##
          # Gets a string of data, no longer than max_length().
          #
          # Returns a resource record of the correct type.
          ##
          public
          def build(data:)
            @l.debug("TunnelDrivers::DNS::Builders::MX Encoding #{data.length} bytes of data")

            name = encode_name(data: data)

            # Create the RR with a random preference
            rr = Nesser::MX.new(name: name, preference: [10, 20, 30, 40, 50].sample)
            double_check_length(rrs: [rr])
            return [rr]
          end
        end
      end
    end
  end
end
