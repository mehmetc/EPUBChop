$LOAD_PATH << './'
require 'spec_helper'

describe 'EPUBChop' do
    before(:all) do
      #chop EPUB at 10% of total words
      @chop = EPUBChop.get('./spec/epub/Verne_20000_West_pg11393.epub', {:base => :percentage, :words => 10})
    end

    it 'load an epub' do
      @chop.should be_kind_of EPUBChop::Chop
    end

    it 'should return the total words' do
      if RUBY_PLATFORM.eql?('java')
        @chop.total_words.should == 71573
      else
        @chop.total_words.should == 32511
      end
    end

    it 'should respect a 5% deviation of allowed words' do
      total_word_count = @chop.total_words
      allowed_word_count = (total_word_count/100) * @chop.words
      real_allowed_word_count = @chop.resource_allowed_word_count.values.inject(0){|sum, i| sum + i}

      deviation = (((real_allowed_word_count - allowed_word_count).abs / allowed_word_count.to_f) * 100).to_i
      puts deviation

      deviation.should < 5
    end

end