# Encoding: ASCII-8BIT

##
# standard.rb
# Created July, 2018
# By Ron Bowes
#
# See: LICENSE.md
##

require 'nesser'
require 'singlogger'

require 'dnscat2/tunnel_drivers/dns/encoders/hex'

module Dnscat2
  module TunnelDrivers
    module DNS
      module Readers
        ##
        # Reads the data from a DNS packet's name. This is the normal (and only)
        # reader so far.
        ##
        class Standard
          def initialize
            @l = SingLogger.instance
          end

          ##
          # Attempt to read the data using the given domain suffix.
          ##
          public
          def try_domain(name:, domain:, encoder:)
            name = name.downcase
            domain = domain.downcase
            @l.debug("TunnelDrivers::DNS::Readers::Standard: Checking if #{name} matches the domain #{domain}...")

            # Handle the simple case
            if name == domain
              @l.debug("TunnelDrivers::DNS::Readers::Standard They're the same!")
              return ''
            end

            # Check if it ends with dot-domain
            if name.end_with?('.' + domain)
              @l.debug('TunnelDrivers::DNS::Readers::Standard Yes it does!')
              return encoder.decode(data: name[0...-(domain.length + 1)].delete('.'))
            end

            @l.debug('TunnelDrivers::DNS::Readers::Standard No it does not!')
            return nil
          end

          ##
          # Attempt to read the data using the given tag prefix.
          ##
          public
          def try_tag(name:, tag:, encoder:)
            name = name.downcase
            tag = tag.downcase
            @l.debug("TunnelDrivers::DNS::Readers::Standard: Checking if #{name} matches the tag #{tag}...")

            # Handle the simple case
            if name == tag
              @l.debug("TunnelDrivers::DNS::Readers::Standard They're the same!")
              return ''
            end

            # Check if it starts with tag-dot
            if name.start_with?(tag + '.')
              @l.debug('TunnelDrivers::DNS::Readers::Standard Yes it does!')
              return encoder.decode(data: name[(tag.length + 1)..-1].delete('.'))
            end

            @l.debug('TunnelDrivers::DNS::Readers::Standard No it does not!')
            return nil
          end
        end
      end
    end
  end
end
