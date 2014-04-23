# Monkey patching bug in rubyzip can not reproduce this on the main branch
require 'zip/version'

if Zip::VERSION.eql?('1.1.3')
  module Zip
    class Entry
      alias_method :old_write_to_zip_output_stream, :write_to_zip_output_stream

      def write_to_zip_output_stream(zip_output_stream) #:nodoc:all
        if @ftype == :directory
          zip_output_stream.put_next_entry(self, nil, nil, ::Zip::Entry::STORED)
        elsif @filepath
          zip_output_stream.put_next_entry(self, nil, nil, self.compression_method || ::Zip::Entry::DEFLATED )
          get_input_stream { |is| ::Zip::IOExtras.copy_stream(zip_output_stream, is) }
        else
          zip_output_stream.copy_raw_entry(self)
        end
      end

    end
  end
end
