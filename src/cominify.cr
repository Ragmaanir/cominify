require "option_parser"
require "file_utils"

require "./cominify/*"

# size_threshold = 2000 # bytes
# input_folder = nil
# output_folder = nil
# quality = 50
# scale = 1024
# filter_strength = 50
# lossless = false
# threads = 6
# format = "pdf"
# ram = 2048

options = Cominify::Options.new

OptionParser.parse! do |parser|
  parser.banner = <<-TEXT
    Cominify #{Cominify::VERSION}
    Description: Converts CBR, CBT, CB7, CBZ or PDF containing any images to a CBT with images in WEBP format which can be viewed with e.g. Pynocchio.
    Author: Ragmaanir (https://github.com/Ragmaanir/cominify)

    Usage: cominify [arguments]
    Short Example: cominify -i input/folder -o output/folder -q 75 -s 2048 -l
    Long Example: cominify --input input/folder --output output/folder --quality 75 -scale 2048 --lossless

  TEXT

  parser.on("-i NAME", "--input=NAME", "Folder of original CBR/PDF files") { |name| options.input_folder = File.expand_path(name) }
  parser.on("-o NAME", "--output=NAME", "Output folder of minified CBR files") { |name| options.output_folder = File.expand_path(name) }
  parser.on("-q QUALITY", "--quality=QUALITY", "Quality of output WEBP files (#{options.quality})") { |q| options.quality = q }
  parser.on("-s SCALE", "--scale=SIZE", "Scale of the output images (#{options.scale})") { |s| options.scale = s }
  parser.on("-f STRENGTH", "--filter=STRENGTH", "Strength of the WEBP filter (#{options.filter_strength})") { |s| options.filter_strength = s }
  parser.on("-l", "--lossless", "If set, compression is lossless (#{options.lossless})") { options.lossless = true }

  parser.on("-m BYTES", "--min=BYTES", "Skip files smaller than min bytes because sometimes invalid/empty pages are generated (#{options.size_threshold})") { |s| options.size_threshold = s }

  parser.on("-t THREADS", "--thread=THREADS", "Number of threads to use (#{options.threads})") { |t| options.threads = t }

  parser.on("-v", "--version", "Show version {#{Cominify::VERSION}}") { puts Cominify::VERSION }

  parser.on("-h", "--help", "Show this help") { puts parser }
end

# convert_options = Cominify::ConvertOptions.new(
#   scale: scale,
#   quality: quality,
#   filter_strength: filter_strength,
#   lossless: lossless,
#   threads: threads,
# )

# Cominify.validate_parameters(input_folder, output_folder)

if !options.valid?
  STDERR.puts "Invalid arguments:"
  STDERR.puts
  STDERR.puts options

  exit 1
end

Cominify.run(options)

module Cominify
  extend self

  class Options
    macro option(name, method)
      def {{name.id}}=(v : String)
        if i = v.{{method}}
          @{{name.id}} = i
        else
          errors[{{name}}] = "Expected Integer, got #{v}"
        end
      end
    end

    property! input_folder : String
    property! output_folder : String
    getter quality : Int32
    getter scale : Int32
    getter filter_strength : Int32
    getter threads : Int32
    getter size_threshold : Int32
    getter lossless : Bool
    # getter! convert_options : Cominify::ConvertOptions
    getter errors : Hash(Symbol, String) = {} of Symbol => String

    def initialize
      @size_threshold = 2000 # bytes
      @input_folder = nil
      @output_folder = nil
      @quality = 50
      @scale = 1024
      @filter_strength = 50
      @lossless = false
      @threads = 6
    end

    # def input_folder=(i)
    #   if i == nil || i.blank?
    #     errors[:input_folder] = "Input folder required"
    #   elsif !File.exists?(i)
    #     errors[:input_folder] = "Input folder does not exist"
    #   else
    #     @input_folder = i
    #   end
    # end

    # def output_folder=(o)
    #   if o == nil || o.blank?
    #     errors[:output_folder] = "Output folder required"
    #   elsif !File.exists?(o)
    #     errors[:output_folder] = "Output folder does not exist"
    #   else
    #     @output_folder = o
    #   end
    # end

    option(:filter_strength, to_i32?)
    option(:quality, to_i32?)
    option(:size_threshold, to_i32?)
    option(:scale, to_i32?)
    option(:threads, to_i32?)

    def lossless=(l)
      case l
      when "true", "false"
        @lossless = l == "true"
      else
        errors[:filter_strength] = "Expected true/false, got #{l}"
      end
    end

    def convert_options
      ConvertOptions.new(
        scale,
        quality,
        filter_strength,
        lossless,
        threads
      )
    end

    def validate
      i = @input_folder

      case i = @input_folder
      when nil     then errors[:input_folder] = "required"
      when .blank? then errors[:input_folder] = "empty"
      else
        errors[:input_folder] = "does not exist (#{i})" if !File.exists?(i)
      end

      o = @output_folder

      case o = @output_folder
      when nil     then errors[:output_folder] = "required"
      when .blank? then errors[:output_folder] = "empty"
      else
        errors[:output_folder] = "does not exist (#{o})" if !File.exists?(o)
      end
    end

    def to_s(io : IO)
      errors.each do |k, e|
        io.puts("- %s : %s" % [k, e])
        # io.print "- "
        # io.print k
        # io.prin " "
        # io.puts e
      end
    end

    def valid?
      validate
      errors.empty?
    end
  end

  class ConvertOptions
    getter scale : Int32, quality : Int32, filter_strength : Int32, lossless : Bool, threads : Int32

    def initialize(@scale, @quality, @filter_strength, @lossless, @threads)
    end
  end

  def run(options : Options)
    puts

    tmpfs_path = File.expand_path("/dev/shm/cominify")
    tmpfs_images = File.join(tmpfs_path, "images")
    tmpfs_minified = File.join(tmpfs_path, "minified")

    file_pattern = File.join(options.input_folder, "*.*")

    Dir.glob(file_pattern).each_with_index do |full_name, comic_no|
      Dir.mkdir_p(tmpfs_images)
      Dir.mkdir_p(tmpfs_minified)

      comic_name = File.basename(full_name).sub(/\.[^\.]+\z/, "")

      puts "Converting #{comic_name} (#{full_name})"

      extract_original_images(full_name, tmpfs_images)
      minify_images(tmpfs_images, tmpfs_minified, options.convert_options)

      output_file = File.join(options.output_folder, comic_name + ".cbt")
      pack_images(tmpfs_minified, output_file, options.size_threshold)

      FileUtils.rm_r(tmpfs_images)
      FileUtils.rm_r(tmpfs_minified)
    end
  end

  def extract_original_images(full_file_path, output_folder)
    puts "Extracting: #{full_file_path}"

    Dir.mkdir_p(output_folder)

    f = %{"#{full_file_path}"}
    o = %{"#{output_folder}"}

    format = shell("file \"#{full_file_path}\"").downcase

    # cmd = case format.downcase
    #       when /tar archive/ then %{tar -xvf #{f} #{o}}
    #       when /7-zip archive/ then %{7z x #{f} -o#{o}}
    #       when /zip archive/ then %{unzip #{f} #{o}}
    #       when /rar archive/ then %{unrar e #{f} #{o}}
    #       when /pdf document/ then %{pdfimages #{f} #{o}/image}
    #       else raise "unknown format #{format}"
    #       end

    cmd = case format
          when /tar archive/   then %{tar -xvf #{f} #{o}}
          when /7-zip archive/ then %{7z x #{f} -o#{o}}
          when /zip archive/   then %{unzip #{f} #{o}}
          when /rar archive/   then %{unrar e #{f} #{o}}
          when /pdf document/  then %{pdfimages #{f} #{o}/image}
          else                      raise "unknown format #{format}"
          end

    shell(cmd)
  end

  def minify_images(input_folder, output_folder, convert_options)
    files = Dir.glob("#{input_folder}/*.*").to_a
    count = files.size

    files.each_with_index do |in_name, i|
      print "Minifying (%03d / %03d)\r" % [i, count]

      out_name = File.basename(in_name).sub(/\.[^\.]+\z/, ".webp")

      command = <<-BASH
      convert "#{in_name}"
        -scale #{convert_options.scale}
        -quality #{convert_options.quality}
        -define webp:lossless=#{convert_options.lossless}
        -define webp:thread-level=#{convert_options.threads}
        -define webp:alpha-compression=0
        -define webp:filter-strength=#{convert_options.filter_strength}
        "#{output_folder}"/"#{out_name}"
    BASH

      shell(command.gsub(/\n/, ""))
    end

    puts "(%03d / %03d)" % [count, count]
  end

  def pack_images(image_folder, output_file, min_size)
    puts "PACK: #{image_folder} => #{output_file}"
    o = "\"#{output_file}\""

    Dir.glob(File.join(image_folder, "*.*")).each do |f|
      size = File.size(f)
      if size < min_size
        puts "Too small: #{f} (#{size} < #{min_size})"
        FileUtils.rm(f)
      end
    end

    shell("tar -cvf #{o} #{image_folder}")
  end

  def shell(cmd)
    # puts "CMD: #{cmd}"
    `#{cmd}` || raise("Command failed")
  end
end
