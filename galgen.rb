require 'rubygems'
require 'fileutils'
require 'tilt'
require 'RedCloth'
require 'builder'

class GalGen
	def initialize(rootdir)
		@rootdir = rootdir
		default_config = {
			:thumb_size => "800x600",
			:minithumb_size => "200x150",
			:atom_items => 10,
			:total_feed => "gindex.xml"
		}
		@config = if File.readable?(@rootdir + "/" + "galgen.yml")
			default_config.merge(YAML.load_file(@rootdir + "/" + "galgen.yml"))
		else
			puts "Using default config; create galgen.yml to override"
			default_config
		end
		@sorting_func = lambda do |a,b|
			if a[:modified] == b[:modified]
				a[:image_name] <=> b[:image_name]
			else
				a[:modified] <=> b[:modified]
			end
		end
		# Supply default versions of templates if they don't exist
		if !File.readable?(@rootdir + "/image.erb")
			puts "Creating image.erb"
			File.open(@rootdir + "/image.erb", "w") do |f|
				erb <<-EOF
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en-us" lang="en-us"><head><title><%= image_title %></title>
<meta http-equiv="content-type" content="text/html; charset=utf-8" />
  </head>
  <body>
   	<a href="..">..</a> / <a href="<%= gallery_url %>"><%= gallery_title %></a> / <a href="<% image_page_url %>"><% image_title %></a>
     
    <h1> <%= image_title %> </h1>

<div >
<a href="<%= image_url %>">
<img src="<%= image_thumb_url %>" />
</a>
<br />
<%= description %>
</div>

<div>
	<% if defined? prev_image_url %>
		<a href="<%= prev_image_url %>">&lt;&lt;&lt;</a>
	<% else %>
		&lt;&lt;&lt;
	<% end %>
|
	<% if defined? next_image_url %>
		<a href="<%= next_image_url %>">&gt;&gt;&gt;</a>
	<% else %>
		&gt;&gt;&gt;
	<% end %>
</div>
</body>
</html>
				EOF
				f.write erb
			end
		end
		if !File.readable?(@rootdir + "/gallery.erb")
			puts "Creating gallery.erb"
			File.open(@rootdir + "/gallery.erb", "w") do |f|
				erb <<-EOF
<!DOCTYPE html PUBLIC "-//W3C//DTD XHTML 1.0 Strict//EN" "http://www.w3.org/TR/xhtml1/DTD/xhtml1-strict.dtd">
<html xmlns="http://www.w3.org/1999/xhtml" xml:lang="en-us" lang="en-us">
  <head>
    <title><% gallery_title %></title>
    <meta http-equiv="content-type" content="text/html; charset=utf-8" />
  </head>
  <body>
  	<a href="<%= gallery_url %>"><%= gallery_title %></a>
       
    <h1> <a href="<%= gallery_url %>"><%= gallery_title %></a> </h1>

<%= gallery_description %>

<%= gallery_previews %>

<%= image_previews %>
  </body>
</html>
				EOF
				f.write erb
			end
		end
		if !File.readable?(@rootdir + "/image_preview.erb")
			puts "Creating image_preview.erb"
			File.open(@rootdir + "/image_preview.erb", "w") do |f|
				erb <<-EOF
<div>
<a href="<%= image_page_url %>">
<img src="<%= image_minithumb_url %>" />
<br />
<h3 style="display:inline">
	<%= image_title %>
</h3>
</a>
</a>
</div>
				EOF
				f.write erb
			end
		end
		if !File.readable?(@rootdir + "/gallery_preview.erb")
			puts "Creating gallery_preview.erb"
			File.open(@rootdir + "/gallery_preview", "w") do |f|
				erb <<-EOF
<%= gallery_description %>
<h2>
	<a href="<%= gallery_url %>"><%=gallery_title%></a>
</h2>
				EOF
				f.write erb
			end
		end
	end
	
	attr_reader :config
	attr_reader :sorting_func
	
	def check_timestamp(source, target)
		if source.is_a? Array
			source.map { |s| check_timestamp(s, target)} - [true] == []
		elsif !File.exists?(target)
			false
		else
			File.mtime(source) <= File.mtime(target)
		end
	end
	
	def generate(out_directory)
		gallery_vars = generate_gallery(out_directory)
		
		xo = File.open(([out_directory] + gallery_vars[:gallery_path] + [config[:total_feed]]).join("/"), "w")
		
		xml = Builder::XmlMarkup.new(:target => xo)
		xml.instruct!
		xml.feed("xmlns"=>"http://www.w3.org/2005/Atom") do |feed|
			feed.title("Updates to all galleries")
			feed.link("href" => config[:http_root])
			gallery_vars[:children].sort(&sorting_func).last(config[:atom_items]).each do |c_img|
				feed.entry do |entry|
					entry.title(c_img[:image_title])
					entry.updated(c_img[:modified].strftime("%FT%T%z"))
					uri = ([config[:http_root]] + c_img[:gallery_path] + [c_img[:image_page_url]]).join("/")
					img_uri = ([config[:http_root]] + ["images", "thumb"] + c_img[:gallery_path] + [c_img[:image_name]]).join("/")
					full_uri = ([config[:http_root]] + ["images", "full"] + c_img[:gallery_path] + [c_img[:image_name]]).join("/")
					entry.id(uri)
					entry.link("href" => uri)
					entry.content({"type" => "html"}, "<a href='#{img_uri}'><img src='#{full_uri}' /></a> #{c_img[:description]}")
				end
			end
		end
		
		xo.close
		
		puts ([out_directory] + gallery_vars[:gallery_path] + [config[:total_feed]]).join("/")
	end
	
	def generate_gallery(out_directory, gallery_path = [])
		directory = ([@rootdir] + gallery_path).join("/galleries/")
		
		FileUtils.mkdir_p(([out_directory] + gallery_path).join("/")) if gallery_path.length > 0
		
		static_dir = [@rootdir, "static"].join("/")
		
		if File.exists? static_dir and not check_timestamp(static_dir, out_directory + "/static")
			FileUtils.cp_r static_dir, out_directory
			puts "static/*"
		end
		
		gallery_previews = ""
		children_children = []
		if File.exists?(directory + "/" + "galleries")
			(Dir.entries(directory + "/" + "galleries") - [".",".."]).each do |gallery|
				child = generate_gallery(out_directory, gallery_path + [gallery])
				child[:gallery_url] = gallery + "/"
				cg_tmpl = Tilt::ERBTemplate.new([@rootdir, "gallery_preview.erb"].join("/"))
				gallery_previews << cg_tmpl.render(nil, child)
				children_children += child[:children]
			end
		end
		
		gallery_description_file = [directory, "index.textile"].join("/")
		gallery_title = gallery_path.last
		gallery_description = ""
		if File.readable?(gallery_description_file)
			desc_text = File.read(gallery_description_file)
			gallery_title = desc_text.scan(/^(.*?)(\n\n|$)/)[0][0]
			gallery_description = RedCloth.new(desc_text.gsub(/^.*?(\n\n|$)/,"")).to_html
		end
		gallery_vars = { :gallery_title => gallery_title, :gallery_url => './', :gallery_description => gallery_description, :root => (gallery_path.length == 0 ? "." : ([".."] * gallery_path.length).join("/")), :gallery_path => gallery_path }
		gallery_vars[:children] = children_children
		g_tmpl = Tilt::ERBTemplate.new([@rootdir, "gallery.erb"].join("/"))
		previews = ""
		child_images = []
		if File.exists? [directory, "images"].join("/")
			images = (Dir.entries([directory, "images"].join("/")) - [".",".."]).sort
			clean_images = images.map {|i| i.gsub(/^\d+_/,"").gsub(/\.\w+$/,"")}
			images.each do |image_name|
				full_image_name = [directory, "images", image_name].join("/")
				description_file = [directory, "descriptions", image_name + ".textile"].join("/")
				clean_image_name = image_name.gsub(/^\d+_/,"")
				base_image_name = clean_image_name.gsub(/\.\w+$/,"")
				description = ""
				title = base_image_name
				if File.readable?(description_file)
					desc_text = File.read(description_file)
					title = desc_text.scan(/^(.*?)(\n\n|$)/)[0][0]
					description = RedCloth.new(desc_text.gsub(/^.*?\n\n/,"")).to_html
				end
				tmpl = Tilt::ERBTemplate.new([@rootdir, "image.erb"].join("/"))
				image_vars = { :image_title => title, :description => description,  :image_page_url => base_image_name + ".html", :image_url => (([".."] * gallery_path.length) + ["images", "full"] + gallery_path + [clean_image_name]).join("/"), :image_thumb_url => (([".."] * gallery_path.length) + ["images", "thumb"] + gallery_path + [clean_image_name]).join("/"), :image_minithumb_url => (([".."] * gallery_path.length) + ["images", "minithumb"] + gallery_path + [clean_image_name]).join("/"), :image_name => clean_image_name, :modified => File.mtime(full_image_name), :original_name => image_name}
				
				idx = clean_images.index(base_image_name)
				
				if idx != 0
					image_vars[:prev_image_url] = clean_images[idx-1] + ".html"
				end
				
				if idx != clean_images.size - 1
					image_vars[:next_image_url] = clean_images[idx+1] + ".html"
				end
				
				FileUtils.mkdir_p(([out_directory, "images", "full"] + gallery_path).join("/"))
				FileUtils.mkdir_p(([out_directory, "images", "thumb"] + gallery_path).join("/"))
				FileUtils.mkdir_p(([out_directory, "images", "minithumb"] + gallery_path).join("/"))
				
				full_path = ([out_directory, "images", "full"] + gallery_path + [clean_image_name]).join("/")
				unless check_timestamp(full_image_name, full_path)
					FileUtils.cp(full_image_name, full_path)
					puts full_path
				end
				
				
				thumb_path = ([out_directory, "images", "thumb"] + gallery_path + [clean_image_name]).join("/")
				unless check_timestamp(full_image_name, thumb_path)
					`convert #{full_image_name} -resize #{config[:thumb_size]} #{thumb_path}`
					puts thumb_path
				end
				
				minithumb_path = ([out_directory, "images", "minithumb"] + gallery_path + [clean_image_name]).join("/")
				unless check_timestamp(full_image_name, minithumb_path)
					`convert #{full_image_name} -resize #{config[:minithumb_size]} #{minithumb_path}`
					puts minithumb_path
				end
				
				File.open(([out_directory] + gallery_path + [base_image_name + ".html"]).join("/"),"w") do |f|
					f.write(tmpl.render(nil, gallery_vars.merge(image_vars)))
					puts ([out_directory] + gallery_path + [base_image_name + ".html"]).join("/")
				end
				
				p_tmpl = Tilt::ERBTemplate.new([@rootdir, "image_preview.erb"].join("/"))
				previews << p_tmpl.render(nil, gallery_vars.merge(image_vars))
				child_images << gallery_vars.merge(image_vars)
			end
		end
		FileUtils.mkdir_p(([out_directory] + gallery_path).join("/"))
		File.open(([out_directory] + gallery_path + ["index.html"]).join("/"), "w") do |f|
			f.write(g_tmpl.render(nil, gallery_vars.merge(:image_previews => previews, :gallery_previews => gallery_previews)))	
			puts ([out_directory] + gallery_path + ["index.html"]).join("/")
		end
		
		gallery_vars[:children] += child_images
		
		atom_feed = ([out_directory] + gallery_path + ["index.xml"]).join("/")
		xo = File.open(atom_feed, "w")
		
		xml = Builder::XmlMarkup.new(:target => xo)
		xml.instruct!
		xml.feed("xmlns"=>"http://www.w3.org/2005/Atom") do |feed|
			feed.title("Updates to '#{gallery_title}'")
			feed.link("href" => ([config[:http_root]] + gallery_path).join("/"))
			child_images.sort(&sorting_func).last(config[:atom_items]).each do |c_img|
				p
				feed.entry do |entry|
					entry.title(c_img[:image_title])
					entry.updated(c_img[:modified].strftime("%FT%T%z"))
					uri = ([config[:http_root]] + gallery_path + [c_img[:image_page_url]]).join("/")
					img_uri = ([config[:http_root]] + ["images", "thumb"] + gallery_path + [c_img[:image_name]]).join("/")
					full_uri = ([config[:http_root]] + ["images", "full"] + gallery_path + [c_img[:image_name]]).join("/")
					entry.id(uri)
					entry.link("href" => uri)
					entry.content({"type" => "html"}, "<a href='#{img_uri}'><img src='#{full_uri}' /></a> #{c_img[:description]}")
				end
			end
		end
		
		puts atom_feed
		
		xo.close
		
		
		
		gallery_vars
	end
	
end



galgen = GalGen.new(ARGV[0])

galgen.generate(ARGV[1])