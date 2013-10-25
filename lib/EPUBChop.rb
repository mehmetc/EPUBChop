require "EPUBChop/version"
require 'EPUBChop/chop'


module EPUBChop
  def self.get(path, options = {})
    EPUBChop::Chop.new(path, options)
  end
end