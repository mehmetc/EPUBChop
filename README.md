EPUBChop [![Continuous Integration](https://travis-ci.org/mehmetc/EPUBChop.png?branch=master)](http://travis-ci.org/mehmetc/EPUBChop)
========

Creates EPUB samples

```
$ ./bin/epubchop --help
EPUBChop will create a sample version of an EPUB.

Usage:
      epubchop [options] <filename>

where [options] are:
  --words, -w <i>:   the amount of words to put in the preview (default: 10)
   --base, -b <s>:   if given the base value of the amount of words is ... Possible values percentage (default: percentage)
  --line1, -l <s>:   Text that is shown on line 1 of the chopped of pages (default: Continue reading?)
  --line2, -i <s>:   Text that is shown on line 2 of the chopped of pages (default: Go to your local library or buy the book.)
       --help, -h:   Show this message
```

### Example:
Create a new EPUB with 10% of the content all other pages should contain the lines "Want to read more? Buy the book!"
```ruby
epubchop --words 10 --base percentage -line1 "Want to read more?" -line2 "Buy the book!" my.epub
```

This gem depends on [![epubinfo](http://github.com/chdorner/epubinfo)] I made some additions to the gem but they are still in a branch. Until they get accepted I'll be using the [![epubinfo_with_toc](https://github.com/mehmetc/epubinfo/tree/table_of_contents)]
gem.

### Changes
* 0.1.0
    - Warning!!! I monkey patch rubyzip until they release an update(it is already fixed in the main branch). Apparently the latest Rubyzip inserts a placeholder for 64bit addressing by default. This breaks file recognition for tools like FIDO.


## Contributing to EPUBChop
* Fork the project.
* Create a new branch to implement your bugfixes or features
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.

## Copyright

Copyright (c) 2013-2014 LIBIS/KULeuven, Mehmet Celik. See LICENSE for further details.
