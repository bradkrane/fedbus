class Bus < ActiveRecord::Base
  STATUSES = [:open, :locked]
  DIRECTIONS = [:both_directions, :from_waterloo, :to_waterloo]

  symbolize :status, :in => STATUSES
  symbolize :direction, :in => DIRECTIONS

  validates_length_of :name, :minimum => 1

  validates_numericality_of :maximum_seats, :greater_than_or_equal_to => 0
	validates_numericality_of :ticket_price, :greater_than_or_equal_to => 0

  validates_datetime :departure#, :on_or_after => :today
  validates_datetime :arrival#, :on_or_after => :departure
  validates_datetime :return#, :on_or_after => :arrival

	validates_presence_of :destination

  belongs_to :trip
  has_many :tickets
	belongs_to :destination

  def self.new_from_trip trip, dep_date
    b = Bus.new( {
      :status => :open,
      :direction => :both_directions,
      :name => trip.name,
      :maximum_seats => 50,
      :departure => cat_date_time(dep_date, trip.departure),
			:ticket_price => trip.ticket_price,
			:trip => trip,
			:destination => trip.destination
                 }
      )    

    # Make sure that departure < arrival < return
    if trip.departure < trip.arrival 
      b.arrival = cat_date_time(dep_date, trip.arrival)
    else 
      dep_date += 1
      b.arrival = cat_date_time(dep_date, trip.arrival)
    end

    if trip.arrival < trip.return
      b.return = cat_date_time(dep_date, trip.return )
    else
      b.return = cat_date_time(dep_date + 1, trip.return )
    end

    return b

  end

  def date
    Date.civil departure.year, departure.month, departure.day
  end

  def return_date
    return date if self.trip.nil?
    return_datetime = date + trip.return_trip
    Date.civil return_datetime.year, return_datetime.month, return_datetime.day
  end

  def to_s
    "Bus: " + name + " " + status.to_s.humanize + " " + direction.to_s.humanize + " " + maximum_seats.to_s + " " + departure.to_s + " " + arrival.to_s + " " + self.return.to_s
  end

	def available_tickets(direction)
		if self.direction == DIRECTIONS[0] || direction == self.direction
			if self.status == :open
				return 9999
			else
				return self.maximum_seats - (self.tickets.select { |t| t.direction == direction and t.status_valid? }).count
			end
		else
			return 0
		end
	end

	def destination_and_time_from
		destination.name + " at " + direction_start_time(:from_waterloo)
	end

	def destination_and_time_to
		destination.name + " at " + direction_start_time(:to_waterloo)
	end

	def direction_start_time(dir)
		if dir == DIRECTIONS[1]
			departure.strftime("%R")
		else
			arrival.strftime("%R")
		end
	end

	# Returns the first date with a bus on it after the specified date
	def self.earliest_date_after date
		buses = Bus.where ["departure >= ?", date]

		if buses.empty? 
			nil
		else
			if buses.length == 1
				buses[0].departure.to_date
			else
				(buses.inject { |d1, d2| d1.departure.to_date <= d2.departure.to_date ? d1 : d2 }).departure.to_date
			end
		end
	end

	# Date only, not datetime
	def self.on_date_in_direction date, dir
		buses = Bus.where ["departure >= ? and departure <= ?", date, date + 1.days]

		buses.select { |bus| bus.available_tickets dir }
	end

	# Date only, not datetime
	def self.after_date_in_direction date, dir
		buses = Bus.where ["departure > ?", date + 1.days]

		buses.select { |bus| bus.available_tickets dir }
	end

  private

  def self.cat_date_time date, time
    DateTime.strptime(date.to_s + time.strftime("T%H:%M:%S"), "%FT%H:%M:%S")
  end

end
