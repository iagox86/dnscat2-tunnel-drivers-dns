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
        class Standard
          def initialize(tags:, domains:, encoder:Encoders::Hex)
            @l        = SingLogger.instance()
            @tags     = tags || []
            @domains  = domains  || []
            @encoder  = encoder
          end

          ##
          # Determines whether this message is intended for us (it either starts
          # with one of the 'tags' or ends with one of the domains).
          #
          # The return is a true/false value, followed by the question with the
          # extra cruft removed (just the data remaining).
          ##
          private
          def _is_this_message_for_me(name:)
            # Check for domain first
            @domains.each do |d|
              if(name.downcase.end_with?(d.downcase)) # TODO: This will fire inappropriately if the name is "blahDOMAIN.com", no period
                @l.debug("TunnelDrivers::DNS::Readers::Standard Message is for me, based on domain! #{name}")
                return nil, d, name[0...-d.length]
              end
            end

            # Check for tags second
            @tags.each do |p|
              if(name.downcase.start_with?(p.downcase))
                @l.debug("TunnelDrivers::DNS::Readers::Standard Message is for me, based on tag! #{name}")
                return p, nil, name[p.length..-1]
              end
            end

            return nil, nil, name
          end

          public
          def read_data(question:)
            # Get the name handy
            name = question.name

            # Either tag or domain must be set
            tag, domain, name = _is_this_message_for_me(name: name)

            if(!tag && !domain)
              @l.debug("TunnelDrivers::DNS::Readers::Standard Received a message that didn't match our tag or domains: #{name}")
              return nil
            end

            # Decode the name into data
            @l.debug("TunnelDrivers::DNS::Readers::Standard Decoding #{name}...")
            return @encoder.decode(data: name.gsub(/\./, '')), tag, domain
          end
        end
      end
    end
  end
end
