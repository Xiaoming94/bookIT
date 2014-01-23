class WhitelistItem < ActiveRecord::Base

	validates :title, :begin_time, :end_time, :rule_start, :rule_end, :days_in_week, presence: true

	# declares a method for each day like 'saturday?', returns true if item is defined on this weekday
	%w(mon tues wednes thurs fri satur sun).each_with_index do |day, i|
		define_method "#{day}day?" do 
			! self.days_in_week.nil? && self.days_in_week & (1 << 6 - i) > 0
		end
	end

	def to_s
		"\"#{title.gsub('[AUTO]', '')}\" (#{rule_start.strftime(NAT_DATE)} - #{rule_end.strftime(NAT_DATE)}, on: #{days_in_week.to_s(2)}): #{begin_time.strftime(NAT_TIME)}-#{end_time.strftime(NAT_TIME)}"
	end

	def days=(*array)
		wkdays = [:mon, :tue, :wed, :thu, :fri, :sun, :sat]
		if array.include? :all
			result = [1, 1, 1, 1, 1, 1, 1]
			return self.day_array = result
		elsif array.include? :weekdays
			result = [1, 1, 1, 1, 1, 0, 0]
		elsif array.include? :weekends
			result = [0, 0, 0, 0, 0, 1, 1]
		else
			result = [0, 0, 0, 0, 0, 0, 0]
		end
		array.each do |d|
			result[wkdays.index(d)] = 1 if wkdays.include?(d)
		end
		self.day_array = result
	end

	def day_array
		(self.days_in_week || 0).to_s(2).rjust(7, '0').split("").map(&:to_i)
	end

	def day_array=(array)
		array = array.values if array.is_a? Hash
		self.days_in_week = array.join.to_i(2) if array.present?
	end

	NAT_DATE = '%-d/%-m'
	NAT_TIME = '%R'
end
