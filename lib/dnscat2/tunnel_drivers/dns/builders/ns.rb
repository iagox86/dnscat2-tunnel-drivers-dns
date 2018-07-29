# Encoding: ASCII-8BIT
##
# ns_builder.rb
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

module Dnscat2
  module TunnelDrivers
    module DNS
      module Builders
        class NS < NameHelper
          include BuilderHelper

          public
          def initialize(tag:, domain:, max_subdomain_length: 63, encoder: Encoders::Hex)
            # 2 extra bytes (for the length)
            super(tag:tag, domain:domain, max_subdomain_length: max_subdomain_length, encoder: encoder, extra_bytes: 2)

            @l = SingLogger.instance()
          end

          ##
          # Gets a string of data, no longer than max_length().
          #
          # Returns a resource record of the correct type.
          ##
          public
          def build(data:)
            @l.debug("TunnelDrivers::DNS::Builders::NS Encoding #{data.length} bytes of data")

            name = encode_name(data: data)

            # Create the RR with a random preference
            rr = Nesser::NS.new(name: name)
            double_check_length(rrs: [rr])
            return [rr]
          end
        end
      end
    end
  end
end
