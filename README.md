EPUBChop
========

Creates EPUB previews

```
$ ./bin/epubchop --help
EPUBChop will create a preview version of an EPUB file.

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
```ruby
epubchop --words 10 --base percentage -line1 "Want to read more?" -line2 "Buy the book!" my.epub
```

## Contributing to EPUBChop
* Fork the project.
* Create a new branch to implement your bugfixes or features
* Commit and push until you are happy with your contribution.
* Make sure to add tests for it. This is important so I don't break it in a future version unintentionally.

## Copyright

Copyright (c) 2013 LIBIS/KULeuven, Mehmet Celik. See LICENSE for further details.