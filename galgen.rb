require 'rubygems'
require 'fileutils'
require 'tilt'
require 'RedCloth'

default_config = {
	:thumb_size => "800x600",
	:minithumb_size => "200x150"
}

class GalGen
	def initialize(config, rootdir)
		@config = config
		@rootdir = rootdir
	end
	
	attr_reader :config
	
	def check_timestamp(source, target)
		if source.is_a? Array
			source.map { |s| check_timestamp(s, target)} - [true] == []
		elsif !File.exists?(target)
			false
		else
			File.mtime(source) <= File.mtime(target)
		end
	end
	
	def generate_gallery(out_directory, gallery_path = [])
		directory = ([@rootdir] + gallery_path).join("/")
		gallery_previews = ""
		if File.exists?(directory + "/" + "galleries")
			(Dir.entries(directory + "/" + "galleries") - [".",".."]).each do |gallery|
				child = generate_gallery(out_directory, gallery_path + [gallery])
				child[:gallery_url] = gallery + "/"
				cg_tmpl = Tilt::ERBTemplate.new([@rootdir, "gallery_preview.erb"].join("/"))
				gallery_previews << cg_tmpl.render(nil, child)
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
		gallery_vars = { :gallery_title => gallery_title, :gallery_url => './', :gallery_description => gallery_description }
		g_tmpl = Tilt::ERBTemplate.new([@rootdir, "gallery.erb"].join("/"))
		previews = ""
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
				image_vars = { :image_title => title, :description => description,  :image_page_url => base_image_name + ".html", :image_url => (([".."] * gallery_path.length) + ["images", "full"] + gallery_path + [clean_image_name]).join("/"), :image_thumb_url => (([".."] * gallery_path.length) + ["images", "thumb"] + gallery_path + [clean_image_name]).join("/"), :image_minithumb_url => (([".."] * gallery_path.length) + ["images", "minithumb"] + gallery_path + [clean_image_name]).join("/")}
				
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
					puts (gallery_path + [base_image_name + ".html"]).join("/")
				end
				
				p_tmpl = Tilt::ERBTemplate.new([@rootdir, "image_preview.erb"].join("/"))
				previews << p_tmpl.render(nil, gallery_vars.merge(image_vars))
			end
		end
		FileUtils.mkdir_p(([out_directory] + gallery_path).join("/"))
		File.open(([out_directory] + gallery_path + ["index.html"]).join("/"), "w") do |f|
			f.write(g_tmpl.render(nil, gallery_vars.merge(:image_previews => previews, :gallery_previews => gallery_previews)))	
			puts (gallery_path + ["index.html"]).join("/")
		end
		gallery_vars
	end
end

galgen = GalGen.new(default_config, ARGV[0])

galgen.generate_gallery(ARGV[1])