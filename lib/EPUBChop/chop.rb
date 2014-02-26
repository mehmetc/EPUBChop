#encoding: UTF-8
require 'nokogiri'
require 'epubinfo'
require 'tempfile'
require 'zip'
require 'lib/ext/zip/entry'

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
      @resource_word_count.values.inject(0) { |sum, i| sum + i }
    end

    def resource_allowed_word_count
      #figure out what to return
      @resource_allowed_word_count ||= files_allowed(allowed_words(@words, @base))
    end

    def chop(options = {})
      set_defaults(options)

      original_zip_file = @book.table_of_contents.parser.zip_file
      extract_dir = extract_epub_to_tmp_dir(original_zip_file)

      chop_files_in_tmp_dir(extract_dir)
      remove_unused_media_from_tmp_dir(extract_dir)


      return rebuild_epub_from_tmp_dir(extract_dir)
    rescue Zip::ZipError => e
      raise RuntimeError, "Error processing EPUB #{@book.table_of_contents.parser.path}.\n #{e.message}", e.backtrace
    rescue Exception => e
      puts e.backtrace.join("\n")
      raise RuntimeError, "Chopping went wrong for #{@book.table_of_contents.parser.path}.\n #{e.message}", e.backtrace
    ensure
      FileUtils.remove_entry_secure(extract_dir)
    end

    private

    def extract_epub_to_tmp_dir(original_zip_file)
      #unzip in temp dir
      extract_dir = Dir.mktmpdir('epub_extract')
      original_zip_file.entries.each do |e|
        file_dir = File.split(e.name)[0]
        FileUtils.mkdir_p(File.join(extract_dir, file_dir)) unless Dir.exists?(File.join(extract_dir, file_dir)) || file_dir.eql?('.')
        original_zip_file.extract(e, File.join(extract_dir, e.name))
      end

      extract_dir
    end


    def chop_files_in_tmp_dir(extract_dir)
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
              f.puts empty_file_with_cover(filename)
            end

          else
            #noinspection RubyResolve
            resource = Nokogiri::HTML(@book.table_of_contents.resources[filename]) do |config|
            #resource = Nokogiri::HTML.parse(@book.table_of_contents.resources[filename], 'UTF-8') do |config|
              config.noblanks.nonet
            end
            resource.encoding = 'UTF-8'

            resource = chop_file(resource, processed_file_size)

            #persist page
            File.open("#{extract_dir}/#{filename}", 'w:UTF-8') do |f|
              #  f.puts resource.to_xml(:save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION)
              f.puts resource.serialize(:encoding => 'UTF-8', :save_with => Nokogiri::XML::Node::SaveOptions::NO_DECLARATION)
            end

          end
        end
      end
    end

    def chop_file(resource, processed_file_size)
      #TODO: get a better algorithm to determine where to chop
      return resource if resource.nil?

      resource.css('script').remove
      resource.css('style').remove
      resource_text = resource.at_css('body').text.split[0..processed_file_size]

      # get a string that can be found
      data = nil
      window_begin = default_window_begin = 5
      window_end = 0
      while data.nil?
        puts "data window:#{(processed_file_size - window_begin)}..#{(processed_file_size - window_end)}" if @verbose
        processed_window_begin = processed_file_size - window_begin
        processed_window_end   = processed_file_size - window_end

        processed_window_begin = 0 if processed_window_begin < 0
        processed_window_end   = processed_file_size

        look_for = resource_text[processed_window_begin..processed_window_end]

        if look_for.nil?
          window_begin = default_window_begin += 5
          window_end = 0
        else
          look_for.map! {|m| m.gsub("'", "\'")}
          data = resource.at_css("p:contains(\"#{look_for.join(' ')}\")")
          data = resource.at_css("body:contains(\"#{look_for.join(' ')}\")") if data.nil?

          window_begin -= 1
          window_end += 1

          if window_begin == window_end
            window_begin = default_window_begin += 5
            window_end = 0
          end
        end
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

      resource
    end


    def rebuild_epub_from_tmp_dir(extract_dir)
      #zip new ebook
      new_ebook_name = Tempfile.new(['epub', '.epub'], Dir.tmpdir)
      new_ebook_name_path = new_ebook_name.path
      new_ebook_name_path.gsub!('-', '')

      zipfile = Zip::File.open(new_ebook_name_path, Zip::File::CREATE)

      epub_files = Dir[File.join(extract_dir, '**', '**')]

      #minetype should be the first entry and should not be zipped. Else FIDO will not know that this is an EPUB
      mimetype = epub_files.delete("#{extract_dir}/mimetype")
      mimetype_entry = Zip::Entry.new(zipfile, mimetype.sub("#{extract_dir}/", ''), '', '', 0, 0, Zip::Entry::STORED)
      zipfile.add(mimetype_entry, mimetype) unless mimetype.nil?

      #all the other files
      epub_files.each do |file|
        zipfile.add(file.sub("#{extract_dir}/", ''), file)
      end
      zipfile.close

      new_ebook_name_path
    end

    #noinspection RubyInstanceMethodNamingConvention
    def remove_unused_media_from_tmp_dir(extract_dir)
      #TODO: remove other media
      #TODO: rebuild toc.ncx and content.opf
      remove_unused_images_from_tmp_dir(extract_dir)
    end

    #noinspection RubyInstanceMethodNamingConvention
    def remove_unused_images_from_tmp_dir(extract_dir)
      puts 'removing unused media' if @verbose
      not_to_be_deleted_images = []
      all_images = @book.table_of_contents.resources.images.map { |i| i[:uri] }
      @book.table_of_contents.resources.html.each do |resource|
        file = Nokogiri::HTML(File.read("#{extract_dir}/#{resource[:uri]}"))

        all_images.each do |image|
          next if image.nil?
          i = image.split('/').last
          data = file.at_css("img[src$='#{i}']")

          if data
            not_to_be_deleted_images << image
          end
        end
      end

      to_be_deleted_images = (all_images - not_to_be_deleted_images)
      to_be_deleted_images.each do |image|
        next if image.nil?
        puts "\t\tremoving #{image}" if @verbose
        File.delete("#{extract_dir}/#{image}") if File.exists?("#{extract_dir}/#{image}")
      end

      to_be_deleted_images
    end


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

      @chop_by = options[:chop_by] || :spine
      @verbose = options[:verbose] || false
    end

    def empty_file_with_cover(filename)
      number_of_subdirectories = filename.split('/').size - 1

      cover_path = ''
      number_of_subdirectories.times { cover_path += '../' }

      cover_path += @book.cover && @book.cover.exists? ? @book.cover.exists?.to_s : ''

      data = <<DATA
<?xml version="1.0" encoding="utf-8" standalone="no"?>
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.1//EN" "http://www.w3.org/TR/xhtml11/DTD/xhtml11.dtd">
<html xmlns="http://www.w3.org/1999/xhtml">
  <head>
      <title>Read more</title>
  </head>

  <body>
  <div style="margin-top:100px;width:500px;margin-left:auto;margin-right:auto;">
    <div style='text-align:center;'>
      <h2>#{CGI.escape_html(@text1 ? @text1 : '')}</h2>
      <span>#{CGI.escape_html(@text2 ? @text2 : '')}</span>
    </div>

    <div style="margin-top:20px;">
      <div style="float:left;margin-right:30px;max-height: 190px; min-height: 120px; width: 125px;">
        <img src="#{cover_path}" alt="" style="width:100%" />
      </div>

      <div style='padding-top:10px;'>
        <h3>#{CGI.escape_html(@book.titles.first ? @book.titles.first : '')}</h3>
      </div>

      <div>
        <h4>#{CGI.escape_html(@book.creators.first ? @book.creators.first.name : '')}</h4>
      </div>

    </div>

    <br />

    <div style="clear:both;text-align:center;font-size:0.5em;"> #{CGI.escape_html(@book.rights ? @book.rights : '')} </div>
  </div>
</body>
</html>

DATA

      data
    end

    def count_words(input)
      @book = EPUBInfo.get(input)
      resource_word_count = {}
      if @book
        resources = @book.table_of_contents.resources.to_a
        chop_by = @chop_by.eql?(:ncx) ? @book.table_of_contents.resources.ncx : @book.table_of_contents.resources.spine

        chop_by.each do |resource|
          raw = Nokogiri::HTML(@book.table_of_contents.resources[resource[:uri]]) do |config|
            #noinspection RubyResolve
            config.noblanks.nonet
          end
          raw.css('script').remove
          raw.css('style').remove
          size = raw.at_css('body').text.split.size
          resource_word_count[resource[:uri]] = size
        end
      end
      # resource_word_count.values.inject(0){|sum, i| sum + i}
      resource_word_count
    end

    def allowed_words(words, base)
      @allowed_words ||= begin
        case base.to_s
          when 'percentage'
            @allowed_words = (total_words * (words / 100.0)).to_i
          else
            @allowed_words = words
        end
      end

    end

    def files_allowed(allowed_words)
      word_counter = 0
      resource_allowed_word_count = @resource_word_count.select do |r|
        (word_counter += @resource_word_count[r]) < allowed_words
      end

      word_counter = resource_allowed_word_count.values.inject(0) { |sum, i| sum + i }

      how_many_words_left = allowed_words - word_counter
      if how_many_words_left > 0
        resource_to_split_name = @resource_word_count.keys[resource_allowed_word_count.length]

        #noinspection RubyLocalVariableNamingConvention
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