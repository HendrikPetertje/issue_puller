class Store
  require 'fileutils'
  require 'json'
  require 'date'

  GITHUB_URL = ENV.fetch('GITHUB_URL', 'https://api.github.com')

  def self.to_file(repo, issues)
    matchgroup = repo.match(/^(.+?)\/(.+?)$/)
    dir = matchgroup[1]
    project = matchgroup[2]

    Dir.mkdir("out") unless File.exists?("out")
    Dir.mkdir("out/#{dir}") unless File.exists?("out/#{dir}")
    Dir.mkdir("out/#{dir}/#{project}") unless File.exists?("out/#{dir}/#{project}")

    now = Time.now.utc

    # Store each issue separately
    issues.each do |issue|
      single_file_contents = {
        created_at: now,
        issue: issue
      }

      json_issue = JSON.pretty_generate(single_file_contents)

      File.open("out/#{dir}/#{project}/#{issue['number']}.json", 'w') { |file| file.write(json_issue) }
    end

    # Create file with all issues
    file_contents = {
      created_at: now,
      issues: issues
    }
    json_issues = JSON.pretty_generate(file_contents)

    File.open("out/#{dir}/#{project}/#{project}.json", 'w') { |file| file.write(json_issues) }

    Store.store_attachments_for(issues, "out/#{dir}/#{project}")
  end

  def self.store_attachments_for(issues, out_folder)
    base_url_match =  GITHUB_URL.match(/(.+)\/api\/v3/)
    base_url = base_url_match ? base_url_match[1] : GITHUB_URL
    base_url_regex = Regexp.compile(base_url)
    path_url_regex = /\/storage\/user\/\d+\/files\/[\w-]+/

    regex = Regexp.new(base_url_regex.source + path_url_regex.source)

    issues.each do |issue|
      file_urls = issue['body'] ? issue['body'].scan(regex).flatten : []
      issue['comments'].each do |comment|
        comment_file_urls = comment['body'].scan(regex).flatten
        file_urls.push(*comment_file_urls)
      end
      if issue['pull_request']
        (issue['pull_request']['review_comments'] || []).each do |rvc|
          comment_file_urls = rvc['body'].scan(regex).flatten
          file_urls.push(*comment_file_urls)
        end
      end
      if issue['pull_request']
        (issue['pull_request']['reviews'] || []).each do |rv|
          comment_file_urls = rv['body'].scan(regex).flatten
          file_urls.push(*comment_file_urls)
        end
      end

      file_urls.each { |url| Store.download_to_disk(url, out_folder, issue['number']) }
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
    puts "Unable to store #{url} to #{out_folder}/#{issue_number}"
  end
end
