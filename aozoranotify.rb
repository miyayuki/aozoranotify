#Kindle版青空文庫で、特定の著者の新作を取ってきて、メール通知する

#!/usr/local/bin/ruby
require 'rubygems'
require 'amazon/ecs'
require "pp"
require "mail"
require 'net/smtp'
require 'tlsmail'
require 'bitly'

# config
keyword = "作家名"
author_flag = true
max_price = 0

#Bitly APIの設定
Bitly.configure do |config|
  config.api_version = 3
  config.login = 'メールアドレス'
  config.api_key = 'api key'
end

Bitly.use_api_version_3
bitly = Bitly.client

# Amazon Product Advertising API へのアクセスに必要なキーを設定
Amazon::Ecs.configure do |options|
  options[:associate_tag] = "xxx-22(Amazonアソシエイトのタグ)"
  options[:AWS_access_key_id] = "アクセスキーID"
  options[:AWS_secret_key] = "シークレットキー"
end

# loop variables
day = Date.today
day = day << 2
opt_power = "pubdate:after %02d-%04d" % [day.month, day.year]
puts opt_power

now_item_page = 1
body = ""


# Amazon の商品を検索
loop do
  opt = Hash.new
  opt[:type] = "author" if author_flag
  opt[:country] = "jp"
  opt[:response_group] = "Large"
  opt[:MaximumPrice] = max_price
  opt[:power] = opt_power
  opt[:item_page] = now_item_page
  #opt[:search_index] = 'KindleStore'  
  resp = Amazon::Ecs.item_search(keyword, opt)
	
  puts "[info] total_page:%d total_results:%d item_page:%d" % [resp.total_pages.to_s,
    resp.total_results.to_s,resp.item_page.to_s]
    resp.items.each do |item| 
      url = item.get("DetailPageURL")  # 詳細ページURLを取得
      title = item.get("ItemAttributes/Title")  # 商品タイトルを取得
      pubdate = item.get("ItemAttributes/PublicationDate") #発売日
      u = bitly.shorten(url)
      surl = u.short_url #=> "http://bit.ly/Ywd1"
      body += title + " " + surl + " " + pubdate+"\n"
    end

  break if resp.item_page >= resp.total_pages
  now_item_page += 1
end

puts body

mail = Mail.new
mail.from = "送信元メールアドレス"
mail.to = "送信先メールアドレス"
mail.subject = "おしらせです"
mail.body = body
mail.charset = 'utf-8'

smtpserver = Net::SMTP.new('smtp.gmail.com',587)
smtpserver.enable_tls(OpenSSL::SSL::VERIFY_NONE)

smtpserver.start('gmail.com','Gmailのアカウント名','Gmailのパスワード', :login) do |smtp|
  smtp.send_message(mail.encoded, mail.from, mail.to)
end