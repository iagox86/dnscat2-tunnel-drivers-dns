# Encoding: ASCII-8BIT

##
# builder_helper.rb
# Created March, 2013
# By Ron Bowes
#
# See: LICENSE.md
##

require 'nesser'

module Dnscat2
  module TunnelDrivers
    module DNS
      module Builders
        MAX_RR_LENGTH = 300
        MAX_NAME_LENGTH = 254

        ##
        # Helper mixin for writing builders.
        ##
        module BuilderHelper
          public
          def double_check_length(rrs:)
            rrs.each do |rr|
              packer = Nesser::Packer.new
              rr.pack(packer)

              if packer.get.length > MAX_RR_LENGTH
                raise(Exception, "Tried to pack too much data into a name (packed #{packer.get.length} bytes, max is #{MAX_RR_LENGTH}! (This is an internal bug)")
              end
            end
          end
        end
      end
    end
  end
end
