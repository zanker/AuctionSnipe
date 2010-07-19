require 'rubygems'
require 'mechanize'
require 'logger'
require 'cgi'
require 'active_support'
require 'nokogiri'
require "base64"
require 'yaml'

module WowArmory
	module AuctionHouse
		class Scanner
			attr_reader :config, :transactions, :total_gold, :next_check, :seen_seeds
			CHECK_INTERVAL = 10.minutes
			REPORT_INTERVAL = 10.minutes
			THROTTLED_SLEEP = 5.seconds
			MAINTENANCE_SLEEP = 10.minutes
			SLEEP_INTERVAL = 0.52
			http_time = 0
			CONFIG_PATH = File.join("./", "auctionsnipe.yml")
			
			def initialize
				load_config()
				
				@agent = Mechanize.new {|agent|
					agent.user_agent = "Mozilla/5.0 (Windows; U; Windows NT 6.1; en-US; rv:1.9.2.4) Gecko/20100513 Firefox/3.6.4"
					agent.gzip_enabled = true
				}
				@agent.pre_connect_hooks << lambda { |params| params[:request]['Connection'] = 'keep-alive' }
			end
			
			def load_config
				begin
					@config = YAML::load(File.open(CONFIG_PATH).read) || {}
					@config[:password] = Base64.decode64(@config[:password]) if !@config[:password].blank?
					
					puts "Auctioning from #{@config[:char_name].capitalize} of #{@config[:region].upcase}-#{@config[:char_realm].camelize}"
				rescue Exception => e
					@config = {}
					
					puts "Initial configuration! You can reset this by deleting auctionsnipe.yml."
					ask_option(:key => "region", :text => "Account region [US]:", :default => "us")
					ask_option(:key => "char_name", :text => "Character name:")
					ask_option(:key => "char_realm", :text => "Character realm:")

					@config[:search] = "http://#{@config[:region].downcase}.wowarmory.com/auctionhouse/search.json?sort=buyout&reverse=false&pageSize=40&rhtml=false&cn=#{CGI::escape(@config[:char_name])}&r=#{@config[:char_realm]}"
					@config[:base] = "http://#{@config[:region].downcase}.wowarmory.com/auctionhouse"
				end
			end
			
			def login!
				@agent.get("#{@config[:base]}/") do |page|
					login_result = page.form_with(:name => "loginForm") do |login|
						login.accountName = ask_option(:key => "login", :text => "Account name:")
						login.password = ask_option(:key => "password", :text => "Account password:")
					end.submit
					
					return true if login_result.code.to_i == 200 && !login_result.body.match(/#{@config[:char_name]}/i).blank?
					return nil
				end
			end
			
			# Pull from configuration, otherwise save
			def ask_option(args)
				return @config[args[:key].to_sym] if !@config[args[:key].to_sym].blank?
				
				print "#{args[:text]} "
				input = gets.chomp
				if args[:boolean]
					input = input.downcase
					input = true if input == "t" || input == "true" || input == "y" || input == "yes"
					input = nil if input == "f" || input == "false" || input == "n" || input == "no"
				else
					input = input.blank? && !args[:default].blank? && args[:default] || !input.blank? && input || nil
				end
				
				@config[args[:key].to_sym] = input
				return input
			end
			
			def flush_config
				@config[:password] = Base64.encode64(@config[:password]) if !@config[:password].nil?
				open(CONFIG_PATH, "w+") do |file|
					file.write(@config.to_yaml)
				end
			end
			
			def process_error(code, message)
				puts colorize("[#{code}] #{message}", "1;31;40")
				
				sleep MAINTENANCE_SLEEP.to_i if code == 114
				sleep THROTTLED_SLEEP.to_i if code == 1013
			end
			
			def check_errors(doc)
				if doc.is_a?(Nokogiri::XML::Document)
					error = doc.css("error")
					if error.length > 0
						process_error(error.attr("code").to_s.to_i, error.attr("message"))
						return true 
					end
				elsif doc.is_a?(Hash) && !doc["error"].blank?
					process_error(doc["error"]["code"].to_i, doc["error"]["message"])
					return true 
				end
				
				return nil
			end

			def search(url)
				begin
					start_time = Time.now.to_f
					response = @agent.get(url)
					@http_time = Time.now.to_f - start_time
				rescue Errno::ECONNRESET, Timeout::Error, SocketError, Errno::ECONNREFUSED, Errno::ETIMEDOUT, Errno::EHOSTUNREACH => e
					puts "#{e.class}: #{e.message}"
				rescue Mechanize::ResponseCodeError => e
					puts "Response code #{e.response_code}"
					return
				end
				
				data = JSON::load(response.body)
				return if check_errors(data)
				
				# Check for maintenance
				if data.match(/maintenancelogo\.gif/) || data.match(/thermaplugg\.jpg/) || data.match(/maintenance/)
					raise ArmoryMaintenanceError
				end
				
				return data
			end
			
			def check_requirements(requires, auction, env_tbl)
				return eval requires, binding
			end
			
			def buy_auction(guid, money)
				begin
					response = @agent.post("#{@config[:base]}/bid.json", {:auc => guid, :money => money})
				rescue Errno::ECONNRESET, Timeout::Error, SocketError, Errno::ECONNREFUSED, Errno::ETIMEDOUT, Errno::EHOSTUNREACH => e
					puts "#{e.class}: #{e.message}"
				rescue Mechanize::ResponseCodeError => e
					puts "Response code #{e.response_code}"
					return
				end
				data = JSON::load(response.body)

				# When the no transactions error is returned, it still gives us transaction data to work with
				if check_errors(data)
					if !data["transactions"].nil?
						@transactions = {:left => data["transactions"]["numLeft"].to_i, :reset_at => data["transactions"]["resetMillis"].to_f / 1000}
					end
					return
				end
				
				if !@transactions.nil? && data["transactions"] && data["transactions"]["numLeft"] != @transactions[:left]
					puts "won!"
				else
					puts "not sure if we won."
				end
				
				if data["transactions"]
					@transactions = {:left => data["transactions"]["numLeft"].to_i, :reset_at => data["transactions"]["resetMillis"].to_f / 1000}
				end
				
				puts colorize("Transactions left: #{@transactions[:left]}", "1;31;40") unless @transactions.nil?
			end
			
			def check_gold
				begin
					response = @agent.get("#{config[:base]}/money.json")
				rescue Errno::ECONNRESET, Timeout::Error, SocketError, Errno::ECONNREFUSED, Errno::ETIMEDOUT, Errno::EHOSTUNREACH => e
					puts "#{e.class}: #{e.message}"
				rescue Mechanize::ResponseCodeError => e
					puts "Response code #{e.response_code}"
					return
				end

				data = JSON::load(response.body)
				return if check_errors(data)
				
				if @total_gold.nil?
					puts "Total gold: #{format_gold(data["money"].to_i)}"
				elsif @total_gold != data["money"].to_i
					gold = data["money"].to_i
					puts "Gold changed, now have #{format_gold(gold)}, #{gold > @total_gold ? "gained" : "lost"} #{format_gold((gold - @total_gold).abs)}"
				end

				@total_gold = data["money"].to_i
			end
			
			def check_mail
				begin
					response = @agent.get("#{config[:base]}/create/?rhtml=no&cn=#{config[:char_name]}&r=#{config[:char_realm]}&f=#{AUCTION_TYPES[:faction]}")
				rescue Errno::ECONNRESET, Timeout::Error, SocketError, Errno::ECONNREFUSED, Errno::ETIMEDOUT, Errno::EHOSTUNREACH => e
					puts "#{e.class}: #{e.message}"
				rescue Mechanize::ResponseCodeError => e
					puts "Response code #{e.response_code}"
					return
				end

				doc = Nokogiri::XML(response.body)
				
				if doc.nil?
					puts colorize("Failed to load mail, invalid response from nokogiri parse", "30;10;10")
					puts response.to_yaml
					return
				else
					return if check_errors(doc)
				end
				
				@seen_seeds ||= {}
				
				doc.css("inventory items invItem").each do |item|
					if item.attr("mail").to_i >= 1 && ( @seen_seeds[item.attr("n")].nil? || @seen_seeds[item.attr("n")] != item.attr("mail").to_i )
						puts colorize("New item in mail: #{item.attr("n")} x #{item.attr("mail")}", "1;32;40")
						@seen_seeds[item.attr("n")] = item.attr("mail").to_i
					end
				end
			end
			
			def snipe(queries)
				check_gold
				check_mail
				@next_check = Time.now + CHECK_INTERVAL
				next_report = Time.now + REPORT_INTERVAL

				print "Sleeping to be safe... "
				sleep 5
				puts "onward!"
				
				previous_totals = {}
				
				while true do
					# Make sure we have enough transactions, otherwise will wait until they reset
					if !@transactions.nil? && @transactions[:left] <= 0
						puts colorize("Ran out of transactions, resets in %.2f minutes" % (@transactions[:reset_at] - Time.now.to_f) / 3600)
						sleep (@transactions[:reset_at] - Time.now.to_f) + 5.minutes
						
						puts "Finished sleeping, let's roll!"
					end
					
					# Every interval, check gold and mail
					if @next_check < Time.now
						check_gold
						check_mail
						@next_check = Time.now + CHECK_INTERVAL

						sleep 5
					end
					
					if next_report < Time.now
						next_report = Time.now + REPORT_INTERVAL
						previous_totals = {}
					end
										
					# Run the queries, then repeat
					queries.each do |name, query|
						args = {"f" => query[:run_at]}
						args = args.merge!(query[:filters]) unless query[:filters].nil?
						url = "#{config[:search]}&#{args.map {|k, v| "#{k}=#{v}"}.join("&")}"
						
						data = search(url)
						if data.nil?
							sleep SLEEP_INTERVAL
							next
						end
						
						if previous_totals[name] != data["auctionSearch"]["end"]
							puts "#{name}: #{data["auctionSearch"]["total"]} auctions found, showing #{data["auctionSearch"]["end"]} (%.3f seconds)" % [@http_time]
							previous_totals[name] = data["auctionSearch"]["end"]
						end
						
						data["auctionSearch"]["auctions"].each do |auction|
							next if auction["seller"].downcase == @config[:char_name].downcase || auction["buy"].blank? || auction["buy"].to_i == 0
							
							# Check blacklist if we have one set
							if query[:blacklist]
								found = nil
								query[:blacklist].each do |item|
									if auction["n"].match(/#{item}/i)
										found = true
										break
									end	
								end
								
								next if !found.nil?
							end
							
							if check_requirements(query[:requires], auction, query[:env_tbl])
								print "Trying to buy #{auction["n"]}x#{auction["quan"]} (#{auction["auc"]}) from #{auction["seller"]} at #{format_gold(auction["buy"])}... "
								buy_auction(auction["auc"], auction["buy"])
							end
						end
						
						sleep SLEEP_INTERVAL
					end
				end
			end
		end
	end
end
