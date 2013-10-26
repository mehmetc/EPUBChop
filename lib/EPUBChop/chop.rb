require 'nokogiri'
require 'epubinfo'
require 'tempfile'
require 'zip'
require 'securerandom'

module EPUBChop
  class Chop
    attr_reader :book, :words, :base, :resource_word_count, :resource_allowed_word_count, :text1, :text2

    def initialize(input, options ={})
      set_defaults(options)


      raise 'Please supply an input file name' if input.nil?

      #count the number of words in a file
      @resource_word_count = count_words(input)

    end

    def total_words
      @resource_word_count.values.inject(0){|sum, i| sum + i}
    end

    def resource_allowed_word_count
      #figure out what to return
      @resource_allowed_word_count ||= files_allowed(allowed_words(@words, @base))
    end

    def chop(options = {})
      set_defaults(options)

      puts "Chopping file"
      original_zip_file = @book.table_of_contents.parser.zip_file
      #unzip in temp dir
      extract_dir = Dir.mktmpdir('epub_extract')
        original_zip_file.entries.each do |e|
            file_dir = File.split(e.name)[0]
            Dir.mkdir(File.join(extract_dir,file_dir)) unless Dir.exists?(File.join(extract_dir,file_dir)) || file_dir.eql?(".")
            original_zip_file.extract(e, File.join(extract_dir,e.name))
        end

      #fix spine files
      filename_list = @resource_word_count.keys
      filename_list.each do |filename|
        original_file_size = @resource_word_count[filename]
        processed_file_size = resource_allowed_word_count[filename]

        if original_file_size != processed_file_size
          if processed_file_size == 0
            FileUtils.rm("#{extract_dir}/#{filename}", :force => true)
            FileUtils.touch "#{extract_dir}/#{filename}"
            File.open("#{extract_dir}/#{filename}", 'w') do |f|
              f.puts empty_file
            end

          else
            resource = Nokogiri::XML(@book.table_of_contents.resources[filename]) do |config|
              config.noblanks.nonet
            end
            resource_text = resource.at_css('body').text.split[0..processed_file_size]
            resource_text_length = resource_text.length

            # get a string that can be found
            data = nil
            window_begin = 5
            window_end   = 0
            while data.nil?
              look_for = resource_text[(processed_file_size - window_begin)..(processed_file_size - window_end)].join(' ')
              data = resource.at_css("p:contains('#{look_for}')")
              window_begin += 1
              window_end   += 1
            end

            #limit on found string
            if data
              next_data = data.next_element
              while next_data
                in_resource = resource.css(next_data.css_path)
                in_resource.remove

                next_data = data.nil? || data.next_element.to_s.length == 1 ? nil : data.next_element
              end
            end

            #persist page
            File.open("#{extract_dir}/#{filename}", 'w') do |f|
              f.puts resource.to_xml(:save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION)
            end

          end
        end
      end
      #TODO:remove unwanted media

      #zip new ebook
      new_ebook_name = Tempfile.new(['epub', '.epub'], '/tmp')
      new_ebook_name_path = new_ebook_name.path
      new_ebook_name_path.gsub!('-', '')

      puts "rebuilding EPUB"
      zipfile = Zip::File.open(new_ebook_name_path, Zip::File::CREATE)

        Dir[File.join(extract_dir, '**', '**')].each do |file|
          zipfile.add(file.sub("#{extract_dir}/", ''), file)
        end
      zipfile.close

      return new_ebook_name_path
    rescue Zip::ZipError => e
      raise RuntimeError, ''
    rescue Exception => e
      puts "Chopping went wrong. #{e.message}"
      puts e.backtrace

      return nil
    ensure
      FileUtils.remove_entry_secure(extract_dir)
    end

    private

    def set_defaults(options)
      @words = options[:words] || 10
      @base = options[:base] || :percentage
      if options[:text].is_a?(Array)
        @text1 = options[:text][0] || 'Continue reading?'
        @text2 = options[:text][1] || 'Go to your local library or buy the book.'
      else
        @text1 = options[:text] || 'Continue reading? Go to your local library or buy the book.'
        @text2 = ''
      end
    end

    def empty_file
      data = <<DATA
<?xml version="1.0" encoding="utf-8" standalone="no"?>
<!DOCTYPE html>
<html xmlns="http://www.w3.org/1999/xhtml">
<head>
<title>Read more</title>
</head>
<body>
<center>
<div style='width:100%;border:1px solid black;margin-top:20px;padding:5px'>
<div><h2>#{@text1}</h2></div>
<div><h2>#{@text2}</h2></div>
</div>
</center>
</body>
</html>
DATA
    end

    def count_words(input)
      @book = EPUBInfo.get(input)
      resource_word_count = {}
      if @book
        @book.table_of_contents.resources.spine.each do |resource|
          raw = Nokogiri::HTML(@book.table_of_contents.resources[resource[:uri]]) do |config|
            config.noblanks.nonet
          end
          raw.css('script').remove
          raw.css('style').remove
          size = raw.at_css('body').text.split.size
          resource_word_count.store(resource[:uri], size)
        end
      end
      # resource_word_count.values.inject(0){|sum, i| sum + i}
      resource_word_count
    end

    def allowed_words(words, base)
      @allowed_words ||= begin
        case base.to_s
          when 'absolute'
            @allowed_words = words
          when 'percentage'
            @allowed_words = (total_words * (words / 100.0)).to_i
        end
      end

    end

    def files_allowed(allowed_words)
      word_counter = 0
      resource_allowed_word_count = @resource_word_count.select do |r|
        (word_counter += @resource_word_count[r]) < allowed_words
      end
      word_counter = resource_allowed_word_count.values.inject(0){|sum, i| sum + i}

      how_many_words_left = allowed_words - word_counter
      if how_many_words_left > 0
        resource_to_split_name = @resource_word_count.keys[resource_allowed_word_count.length]
        word_count_of_resource_to_split = @resource_word_count[resource_to_split_name]
        if  how_many_words_left < word_count_of_resource_to_split
          resource_allowed_word_count.store(resource_to_split_name, how_many_words_left)
        end
      end

      @resource_word_count.keys[resource_allowed_word_count.length..@resource_word_count.length].each do |r|
        resource_allowed_word_count.store(r, 0)
      end

      resource_allowed_word_count
    end

  end
end