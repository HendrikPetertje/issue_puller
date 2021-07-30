class Store
  require 'fileutils'
  require 'json'

  def self.to_file(repo, issues)
    matchgroup = repo.match(/^(.+?)\/(.+?)$/)
    dir = matchgroup[1]
    project = matchgroup[2]

    json_issues = JSON.pretty_generate(issues)

    Dir.mkdir("out") unless File.exists?("out")
    Dir.mkdir("out/#{dir}") unless File.exists?("out/#{dir}")
    Dir.mkdir("out/#{dir}/#{project}") unless File.exists?("out/#{dir}/#{project}")

    File.open("out/#{dir}/#{project}/#{project}.json", 'w') { |file| file.write(json_issues) }

    Store.store_images_for(issues, "out/#{dir}/#{project}")
  end

  def self.store_images_for(issues, out_folder)
    issues.each do |issue|
      image_urls = issue['body'].scan(/\!\[.+?\]\((.+?)\)/).flatten
      issue['comments'].each do |comment|
        comment_image_urls = comment['body'].scan(/\!\[.+?\]\((.+?)\)/).flatten
        image_urls.push(*comment_image_urls)
      end

      image_urls.each { |url| Store.download_to_disk(url, out_folder, issue['number']) }
    end
  end

  def self.download_to_disk(url, out_folder, issue_number)
    uri = URI.parse(url)
    basename = File.basename(uri.path)

    Dir.mkdir("#{out_folder}/#{issue_number}") unless File.exists?("#{out_folder}/#{issue_number}")
    File.open("#{out_folder}/#{issue_number}/#{basename}", "w") do |file|
      file.binmode
      HTTParty.get(url, stream_body: true) do |fragment|
        file.write(fragment)
      end
    end
  rescue
    puts "Unable to store #{url} to #{out_folder}"
  end

end
