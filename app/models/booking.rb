# == Schema Information
#
# Table name: bookings
#
#  id           :integer          not null, primary key
#  cid          :string(255)
#  begin_date   :datetime
#  end_date     :datetime
#  group        :string(255)
#  description  :text
#  festansvarig :string(255)
#  festnumber   :string(255)
#  room_id      :integer
#  created_at   :datetime
#  updated_at   :datetime
#  title        :string(255)
#

class Booking < ActiveRecord::Base
  belongs_to :room

  validates :title, :cid, :group, :description, :room, :begin_date, :end_date, presence: true
  validate :time_whitelisted
  validate :time_not_too_long


  def fest
    !(self.festansvarig.nil? && self.festnumber.nil?)
  end

  def fest=(fest)
    unless fest
      self.festansvarig = nil
      self.festnumber = nil
    end
  end
  

private

  def time_whitelisted
  	WhitelistItem.all.each do |item|
  		range = item.rule_range

  		# if range in whitelist
      unless range.cover?(self.begin_date)
	     errors.add :begin_date, "ligger inte inom whitelistad period"
      end

      unless range.cover?(self.end_date)
	     errors.add :end_date, "ligger inte inom whitelistad period"
      end

      puts range
    end
  end

  def time_not_too_long
    unless self.begin_date.nil? || self.end_date.nil?
      days = (self.end_date - self.begin_date).to_i / 1.day
      errors[:base] << "Bokningen får ej vara längre än en vecka, (är #{days} dagar)" if days > 7
    end
  end
end
