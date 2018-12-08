Bundler.require
require "date"

def headline(string)
  puts
  puts "=" * 50
  puts string
  puts "=" * 50
  puts
end

hatena_username = ENV["HATENA_USERNAME"]
slack_webhook_url = ENV["SLACK_WEBHOOK_URL"]
slack_channel = ENV["SLACK_CHANNEL"]
target_date = ENV["TARGET_DATE"]

date = target_date.nil? ? Date.today : Date.parse(target_date)
page = 1
finished = false

bookmarks = []

headline("Fetch bookmarks")

loop do
  url = "http://b.hatena.ne.jp/#{hatena_username}/bookmark.rss?page=#{page}"

  puts url
  puts

  xml = Nokogiri::XML(HTTP.get(url))

  xml.css("item").each do |item|
    time = Time.parse(item.children.find { |child| child.name == "date" }.text).localtime

    if time < date.to_time
      finished = true
      break
    end

    title = item.css("title").text
    link = item.css("link").text

    puts [title, link].join("\t")

    bookmarks.push({ title: title, link: link, time: time })
  end

  break if finished

  page += 1
end

headline("Generate template")

bookmarks_text =
  if bookmarks.empty?
    "今日のブックマークはありません。"
  else
    bookmarks.reverse.map { |b| " #{b[:title]}\n  #{b[:link]}" }.join("\n")
  end

template = <<~TEMPLATE
```
#{date} のウェブログ
##{date} #weblog

[*** ブックマーク]

#{bookmarks_text}

[*** 思ったこと・感じたこと]


[#{date - 1} のウェブログ] ←前日 | 今月 ##{date.strftime("%Y-%m")} | 翌日→ [#{date + 1} のウェブログ]
```
TEMPLATE

puts template

HTTP.post(
  slack_webhook_url,
  form: { payload: { channel: slack_channel, text: template }.to_json }
)
