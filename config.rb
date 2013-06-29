###
# Compass
###

# Susy grids in Compass
# First: gem install susy --pre
# require 'susy'

# Change Compass configuration
# compass_config do |config|
#   config.output_style = :compact
# end

###
# Page options, layouts, aliases and proxies
###

# Per-page layout changes:
#
# With no layout
# page "/path/to/file.html", :layout => false
#
# With alternative layout
# page "/path/to/file.html", :layout => :otherlayout
#
# A path which all have the same layout
# with_layout :admin do
#   page "/admin/*"
# end

# Proxy (fake) files
# page "/this-page-has-no-template.html", :proxy => "/template-file.html" do
#   @which_fake_page = "Rendering a fake page with a variable"
# end

###
# Helpers
###

# Automatic image dimensions on image_tag helper
# activate :automatic_image_sizes

# Methods defined in the helpers block are available in templates
helpers do
  def cc_html(options={}, &blk)
    attrs = options.map { |k, v| " #{h k}='#{h v}'" }.join('')
    [ "<!--[if lt IE 7 ]> <html#{attrs} class='ie6 no-js'> <![endif]-->",
      "<!--[if IE 7 ]>    <html#{attrs} class='ie7 no-js'> <![endif]-->",
      "<!--[if IE 8 ]>    <html#{attrs} class='ie8 no-js'> <![endif]-->",
      "<!--[if IE 9 ]>    <html#{attrs} class='ie9 no-js'> <![endif]-->",
      "<!--[if (gt IE 9)|!(IE)]><!--> <html#{attrs} class='no-js'> <!--<![endif]-->",
      capture_haml(&blk).strip,
      "</html>"
    ].join("\n")
  end

  def h(str); Rack::Utils.escape_html(str); end


  class JPEG
    attr_reader :width, :height, :bits

    def initialize(file)
      if file.kind_of? IO
        examine(file)
      else
        File.open(file, 'rb') { |io| examine(io) }
      end
    end

    private
    def examine(io)
      raise "malformed JPEG #{io.path}" unless io.getc == 0xFF.chr && io.getc == 0xD8.chr # SOI

      class << io
        def readint; (readchar.bytes.first << 8) + readchar.bytes.first; end
        def readframe; read(readint - 2); end
        def readsof; [readint, readchar.bytes.first, readint, readint, readchar.bytes.first]; end
        def next
          c = readchar while c != 0xFF.chr
          c = readchar while c == 0xFF.chr
          c
        end
      end

      while marker = io.next.bytes.first
        case marker
          when 0xC0..0xC3, 0xC5..0xC7, 0xC9..0xCB, 0xCD..0xCF # SOF markers
            length, @bits, @height, @width, components = io.readsof
            raise 'malformed JPEG' unless length == 8 + components * 3
          when 0xD9, 0xDA
            break # EOI, SOS
          when 0xFE
            @comment = io.readframe # COM
          when 0xE1
            io.readframe # APP1, contains EXIF tag
          else
            io.readframe # ignore frame
        end
      end
    end
  end

  def photostrip(item)
    photos = Dir[File.join(File.dirname(__FILE__), 'source/images', item.to_s, '*.jpg')].map do |file|
      options = {}
      unless RUBY_VERSION.start_with?('1.8')
        image = RUBY_VERSION.start_with?('1.8') ? nil : JPEG.new(file)
        options = {:width => image.width, :height => image.height}
      end
      relative_url = file.gsub(File.join(File.dirname(__FILE__), 'source'), '')
      '<a href="#" onclick="return zoomImage(this);">' +
        image_tag(relative_url, options) +
      '</a>'
    end

    output = ["<div class=\"photostrip\">"]
    output += photos
    output + ['</div>']
  end

  def nav(active_item = nil, &blk)
    items = {
      :illustration => 'Illustration',
      :photos => 'Photos',
      :branding => 'Branding',
      :motion => 'Motion'
    }

    output = ['<nav><ul>']
    items.each do |item, label|
      link = link_to("<h2>#{label}</h2>", "#{item}.html", :relative => true)
      if item == active_item
        output << "<li class=\"active\">#{link}"
        # output << capture_haml(&blk) if block_given?
        output += photostrip(item)
        output << "</li>"
      else
        output << "<li>#{link}</li>"
      end
    end
    output << '</ul></nav>'

    output.join("\n")
  end
end

set :css_dir, 'stylesheets'

set :js_dir, 'javascripts'

set :images_dir, 'images'

# Build-specific configuration
configure :build do
  activate :minify_css
  activate :minify_javascript
  activate :asset_hash
  activate :relative_assets
  activate :gzip
  activate :helpers
end
