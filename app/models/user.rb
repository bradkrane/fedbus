class User < ActiveRecord::Base
	has_and_belongs_to_many :roles
	has_many :tickets
	has_many :buses
	has_many :invoices

	validates_presence_of :first_name, :last_name, :userid, :email
	validates_presence_of :student_number, :student_number_confirmation, :if => :student_number_changed?
	validates_confirmation_of :student_number, :if => :student_number_changed?
	
	attr_accessor :student_number, :student_number_confirmation
	attr_accessible :first_name, :last_name, :email, :student_number, :student_number_confirmation
	 
	# Assigns a new student number by updating the <tt>student_number_hash</tt> attribute.
	# TODO: Consider using an HMAC with a secret that is defined in the code, and not published on GitHub.  Deploy it in a similar way to the database.yml
	def student_number=(new_student_number)
		unless new_student_number.blank?
			@student_number = new_student_number
			self.student_number_hash = Digest::SHA256.hexdigest(new_student_number)
		end
	end
	
	# Determines whether or not the student number has been modified or needs to exist
	def student_number_changed?
		!@student_number.blank? || !@student_number_confirmation.blank? || self.student_number_hash.blank?
	end

  # Determined whether the user has the permission given.
  # Accepts any of the following:
  #
  # Symbol::     Humanizes the symbol name and looks up a permission by that name (e.g. :eat_cake)
  # String::     Looks up a permission by the name given (e.g. "Eat cake")
  # Integer::    Looks up a permission by that ID (e.g. 4)
  # Permission:: Uses the Permission model instance given.
  #
  # Anything else returns false. A user "has" a permission if any of the
  # user's roles has that permission.
	def has_permission? permission
		case permission
		when Symbol
			permission = Permission.where(:name => permission.to_s.humanize).first
		when String
			permission = Permission.where(:name => permission).first
		when Integer
			permission = Permission.find(permission)
		end
		
		return false unless permission.is_a? Permission
		
		hasroles = roles.select { |role| role.permissions.include? permission }
		return false unless hasroles.count > 0
		true
	end

	def users_permission
		current_user.has_permission?(:users) || authorization_denied
	end
	
	def self.find_by_student_number num
		User.find_by_student_number_hash Digest::SHA256.hexdigest(num)
	end
	
	# Gets all of the valid tickets the user has for a given date
	def tickets_for_date date
		tickets.select { |t| t.status_valid? && t.bus.date == date }
	end

	# Gets the current reserved tickets of the user
	def reserved_tickets
		tickets.select {|t| t.status == 'reserved'}
	end

	# Sets the current costs of all of the user's reserved tickets
	def set_prices
		tickets = reserved_tickets
		tickets.each do |tick|
			# If the ticket is not set as a return ticket but it is one then its prices must be set correctly
	        if tick.return_ticket == nil && tick.return_of == nil
	            (tickets - [tick]).each do |other|
		            if other.bus.find_returns.include? tick.bus
			            other.return_ticket = tick
			            other.ticket_price = other.bus.ticket_price - 1.00
			            other.save
			            tick.ticket_price = tick.bus.ticket_price - 1.00
			            tick.save
			            break
		            end
		        end
		          
		    # If the ticket has a return (or is a return) but the other ticket doesn't exist then the price must be reset
		    elsif (tick.return_ticket != nil && !tickets.include?(tick.return_ticket)) || (tick.return_of != nil && !tickets.include?(tick.return_of))
		        tick.return_ticket = nil
		        tick.return_of = nil
		        tick.ticket_price = tick.bus.ticket_price
		        tick.save
		        
		    # Finally, if the existing returns are valid make sure that the discounted prices are correct
		    else
		        [tick, (tick.return_ticket ? tick.return_ticket : tick.return_of)].each do |t|
		            t.ticket_price = t.bus.ticket_price - 1.00
		            t.save
		        end
		    end
		end
	end

	# Gets the current total cart cost for the user
	def cart_total
		total = 0.0
		reserved_tickets.each do |tick|
			total = total + tick.ticket_price
		end
		total
	end
end
