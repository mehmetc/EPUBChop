$LOAD_PATH << './'
require 'spec_helper'

describe EPUBChop do
  describe 'get' do
    puts "1234"
    chop_mock = double
    EPUBChop::Chop.should_receive(:new) {chop_mock}
    EPUBChop.get().should == chop_mock
  end
end