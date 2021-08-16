class Github
  require 'httparty'
  GITHUB_TOKEN = ENV.fetch('GITHUB_TOKEN')
  GITHUB_URL = ENV.fetch('GITHUB_URL', 'https://api.github.com')


  def self.fetch_all(repo)
    issues = Github.fetch_all_issues(repo)
    issues.each do |issue|
      issue['comments'] = (issue['comments'] >= 1) ? Github.fetch_all_meta(issue['comments_url']) : []
      issue['events'] = Github.fetch_all_meta(issue['events_url'])
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
    response = HTTParty.get(
      "#{Github::GITHUB_URL}/repos/#{repo}/issues?per_page=100&page=#{page}&state=all",
      headers: {
        Accept: 'application/vnd.github.v3+json"',
        Authorization: "token #{GITHUB_TOKEN}"
      }
    )
  end

  def self.fetch_meta(url)
    response = HTTParty.get(
      url,
      headers: {
        Accept: 'application/vnd.github.v3+json"',
        Authorization: "token #{GITHUB_TOKEN}"
      }
    )
  end
end
