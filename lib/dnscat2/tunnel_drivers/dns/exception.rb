##
# exception.rb
# Created July/2018
# By Ron Bowes
#
# See LICENSE.md
#
# Custom exception for DNS tunnel driver.
##

module Dnscat2
  module TunnelDrivers
    module DNS
      class Exception < ::StandardError
      end
    end
  end
end
