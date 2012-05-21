
#
#  jeanny.rb
#  Obfuscation for web applications
#
#  Created by seriously drunken on 2009-09-16.
#  Copyright 2009 Yandex. All rights reserved.
#

$:.unshift File.dirname(__FILE__) unless $:.include? File.dirname(__FILE__)

module Jeanny

    JEANNY_VERSION = '0.85'

end

require 'jeanny/extend'
require 'jeanny/engine'
require 'jeanny/sugar'