# == Schema Information
#
# Table name: bookings
#
#  id                      :integer          not null, primary key
#  user_id                 :string(255)
#  begin_date              :datetime
#  end_date                :datetime
#  group                   :string(255)
#  description             :text
#  party_responsible       :string(255)
#  party_responsible_phone :string(255)
#  room_id                 :integer
#  created_at              :datetime
#  updated_at              :datetime
#  title                   :string(255)
#  party                   :boolean
#  phone                   :string(255)
#  liquor_license          :boolean
#  accepted                :boolean
#

class Booking < ActiveRecord::Base
  scope :by_group_or_user, -> (name) { where('user_id = ? OR "group" = ?', name, name) }
  scope :in_future, -> { where('end_date >= ?', DateTime.now) }
  scope :within, -> (time = 1.month.from_now) { where('begin_date <= ?', time) }
  scope :accepted_or_waiting, -> { where('accepted IS NULL OR accepted = ?', true) }
  scope :party_reported, -> { where(party: true) }
  scope :in_room, -> (room) { where(room: room) }

  belongs_to :room
  belongs_to :user

  before_validation :format_phone # remove any non-numeric characters
  before_validation :clear_party_options_unless_party

  # essential validations
  validates :title, :description, :user, :room, :begin_date, :end_date, presence: true
  validates :phone, presence: true,length: { minimum: 6 }
  validates_inclusion_of :party, :in => [true, false]

  # validations if party is selected:
  with_options if: :party do |f|
    f.validates :party_responsible_phone, presence: true, length: { minimum: 6 }
    f.validates :party_responsible, presence: true
    f.validates_inclusion_of :liquor_license, :in => [true, false]
    f.validate :must_be_party_room
  end

  validate :must_be_allowed
  validate :must_not_exceed_max_duration, :must_not_collide, :must_be_group_in_room
  # validate :disallow_liquor_license_unless_party

  validates_datetime :begin_date, after: -> { DateTime.now.beginning_of_day }
  validates_datetime :end_date, after: :begin_date

  def group_sym
    group.to_sym
  end

  def status_text
    if accepted
      return 'godkänd'
    elsif accepted.nil?
      return 'ej godkänd ännu'
    else
      return 'avslagen'
    end
  end

  DATE_AND_TIME = '%-d %b %R' # example: 4 apr 12:00

  def booking_range
    ary = [I18n.localize(begin_date, format: DATE_AND_TIME)]
    if same_day?(begin_date, end_date)
      ary << I18n.localize(end_date, format: '%R') # example: 09:00
    else
      ary << I18n.localize(end_date, format: DATE_AND_TIME)
    end
    ary.join ' - '
  end

  def accept
    self.accepted = true
    save
  end

  def reject
    self.accepted = false
    save
  end

  def accepted?
    self.accepted == true
  end

  def rejected?
    self.accepted == false
  end

  private

  def same_day?(d1, d2)
    d1.year == d2.year && d1.month == d2.month && d1.day == d2.day
  end

  def format_phone
    [:phone, :party_responsible_phone].each do |s|
      self[s].gsub!(/[^0-9]/, '') if self[s].present?
    end
  end

  def must_be_party_room # called if party
    errors.add(:room, 'tillåter ej festbokningar') unless room.allow_party
  end

  def must_be_group_in_room
    unless group.present?
      errors.add(:room, 'kan ej bokas som privatperson') if room.only_group
    else
      errors.add(:group, 'är du ej medlem i') unless user.in? group.to_sym
    end
  end

  def must_not_collide
    Booking.accepted_or_waiting.in_room(self.room).in_future.each do |b|
      unless b == self
        # Algorithm source: http://makandracards.com/makandra/984-test-if-two-date-ranges-overlap-in-ruby-or-rails
        if (begin_date - b.end_date) * (b.begin_date - end_date) > 0
          errors[:base] << 'Lokalen är redan bokad under denna perioden'
          return
        end
      end
    end
  end

  def disallow_liquor_license_unless_party
    unless self.party

      # errors.add(:liquor_license, 'kan ej begäras om inte festanmält') if self.liquor_license
      # errors.add(:party_responsible_phone, 'får ej anges om inte festanmält') if self.party_responsible_phone.present?
      # errors.add(:party_responsible, 'får ej anges om inte festanmält') if self.party_responsible.present?
    end
  end

  def clear_party_options_unless_party
    unless self.party
      self.liquor_license = false
      self.party_responsible = ""
      self.party_responsible_phone = ""
    end
  end

  def must_not_exceed_max_duration
    unless begin_date.nil? || end_date.nil?
      days = (end_date - begin_date).to_i / 1.day
      msg = "Bokningen får ej vara längre än en vecka, (är #{days} dagar)"
      errors.add(:end_date, msg) if days > 7
    end
  end

  def must_be_allowed
    rules = Rule.in_range(begin_date, end_date).order(prio: :desc)
    rules.each do |rule|
      (allow, reason) = check_rule(rule)
     
      next if allow.nil? # Rule did not apply for given time span

      if allow # Booking is allowed
        return 
      else
        errors.add(:rule, reason)
      end
    end
  end

  def check_booking_against_rule(rule)

    if rule.start_time.nil? # Rule is always in effect if time = nil
      return rule.allow, rule.reason
    end

   
    # Vi måste veta om bokningen täcker flera dagar för att kolla
    # tiden för regler. Säg bokning fre lör sön, så täcker ju bokninge all tid
    # på lördag, men ska ta hänsyn till boknignstiden olika för fre och sön
    # därav måste första och sista dagen hanteras annorlunda vid flerdagsbokningar
    # då det i första dagen gäller från bokningstart - 24:00
    # och sista dagen gäller från 00:00 - bokningsslut
    multi_day_booking = ((stop_date.to_date - start_date.to_date).to_i) > 0

    unless multi_day_booking
     if(rule.start_time - start_time) * (rule.stop_time - stop_time) > 0
      return rule.allow, rule.reason
    else
      return nil
    end


    ((start_date.to_date)..(stop_date.to_date)).each do |day| 
      if rule.applies? day.wday
        if collides(day, rule) 
          return rule.allow, rule.reason
        end 
      end
    end
    return nil
  end


end

def collides?(day, rule)
  return ((day == start_date.to_date) && first_day_collision(day, rule)) || 
          ((day == stop_date.to_date) && last_day_collision(day, rule)) ||
          middle_day_collision(day, rule)
     
end

def first_day_collision?(day, rule)
  return (rule.start_time - start_time) * (rule.stop_time - day.end_of_day) > 0
end

def last_day_collision?(day, rule)
   return (rule.start_time - day.midnight) * (rule.stop_time - stop_time) > 0
end

def middle_day_collision?(day, rule)
  return (rule.start_time - day.midnight) * (rule.stop_time - day.end_of_day) > 0
end



end
