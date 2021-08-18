class Github
  require 'httparty'
  GITHUB_TOKEN = ENV.fetch('GITHUB_TOKEN')
  GITHUB_URL = ENV.fetch('GITHUB_URL', 'https://api.github.com')

  def self.fetch_all(repo)
    issues = Github.fetch_all_issues(repo)
    issues.each do |issue|
      issue['comments'] = issue['comments'] >= 1 ? Github.fetch_all_meta(issue['comments_url']) : []
      issue['events'] = Github.fetch_all_meta(issue['events_url'])

      next unless issue['pull_request']

      puts "meta data fetch for #{repo}/pulls/#{issue['number']}"
      pull_request_meta = issue['pull_request']
      issue['pull_request'] = Github.fetch_all_meta(pull_request_meta['url'])
      issue['pull_request']['reviews'] =
        Github.fetch_all_meta("#{GITHUB_URL}/repos/#{repo}/pulls/#{issue['number']}/reviews")
      issue['pull_request']['review_comments'] = Github.fetch_all_meta(issue['pull_request']['review_comments_url'])
      issue['pull_request']['commits'] = Github.fetch_all_meta(issue['pull_request']['commits_url'])
      issue['pull_request'].delete('head')
      issue['pull_request'].delete('base')
    end

    issues
  end

  def self.fetch_all_issues(repo)
    iteration = 1
    issues = []
    while true
      puts iteration
      response = fetch_page(repo, iteration)

      body = response.body.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')
      parsed = JSON.parse(body)

      return issues if parsed.length == 0

      issues.push(*parsed)
      iteration += 1
    end
  end

  def self.fetch_all_meta(url)
    response = Github.fetch_meta(url)
    body = response.body.encode('UTF-8', invalid: :replace, undef: :replace, replace: '?')

    parsed = JSON.parse(body)
  end

  def self.fetch_page(repo, page)
    HTTParty.get(
      "#{Github::GITHUB_URL}/repos/#{repo}/issues?per_page=100&page=#{page}&state=all",
      headers: {
        Accept: 'application/vnd.github.v3+json"',
        Authorization: "token #{GITHUB_TOKEN}"
      }
    )
  end

  def self.fetch_meta(url, retries = 3)
    HTTParty.get(
      "#{url}?per_page=100",
      headers: {
        Accept: 'application/vnd.github.v3+json"',
        Authorization: "token #{GITHUB_TOKEN}"
      }
    )
  rescue Net::OpenTimeout => e
    puts "TRY #{retries}/n ERROR: timed out while trying to connect #{e}"
    raise if retries <= 1

    puts 'Sleeping 3 and retrying'
    sleep 3
    Github.fetch_meta(url, retries - 1)
  end
end
