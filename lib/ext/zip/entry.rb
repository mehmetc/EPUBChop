# Monkey patching bug in rubyzip, currently fixed on master, but not yet released
# and EPUBChop brings in the 1.0 release.

module Zip
  class Entry
    private
      def prep_zip64_extra(for_local_header)
      end
  end
end