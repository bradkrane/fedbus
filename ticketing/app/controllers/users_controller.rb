class UsersController < ApplicationController
  # Only authorized users should be able to access anything but their own user
  before_filter permission_required(:manage_access_control), :except => [:login, :logout, :new, :create],
                :unless => lambda { |c| c.logged_in? && c.current_user.to_param == c.params[:id] }

  # GET /users
  # GET /users.xml
  def index
    @users = User.all

    respond_to do |format|
      format.html # index.html.erb
      format.xml  { render :xml => @users }
    end
  end

  # GET /users/1
  # GET /users/1.xml
  def show
    @user = User.find(params[:id])
		@tickets = Ticket.where ["user_id = ?", @user.id]

    respond_to do |format|
      format.html # show.html.erb
      format.xml  { render :xml => @user }
    end
  end

  # GET /users/new
  # GET /users/new.xml
  def new
    unless session[:userid]
      redirect_to :login
    else
      @user = User.new
      @userid = session[:userid]

      respond_to do |format|
        format.html # new.html.erb
        format.xml  { render :xml => @user }
      end
    end
  end

  # GET /users/1/edit
  def edit
    @user = User.find(params[:id])
  end

  # POST /users
  # POST /users.xml
  def create
    @user = User.new(params[:user])
    @user.userid = session[:userid]
    @user.student_number = params[:user][:student_number]
    @user.student_number_confirmation = params[:user][:student_number_confirmation]

    respond_to do |format|
      if @user.save
        flash[:notice] = 'User was successfully created.'
        format.html { redirect_to(@user) }
        format.xml  { render :xml => @user, :status => :created, :location => @user }
      else
        format.html { render :action => "new" }
        format.xml  { render :xml => @user.errors, :status => :unprocessable_entity }
      end
    end
  end

  # PUT /users/1
  # PUT /users/1.xml
  def update
    params[:user][:role_ids] ||= []
    @user = User.find(params[:id])

    respond_to do |format|
      # Update the user's attributes, bypassing protections if the current user has
      # the appropriate permission to manage access control.
      protection_enabled = ! current_user.has_permission?(:manage_access_control)
      @user.send(:attributes=, params[:user], protection_enabled)

      if @user.save
        flash[:notice] = 'User was successfully updated.'
        format.html { redirect_to(@user) }
        format.xml  { head :ok }
      else
        format.html { render :action => "edit" }
        format.xml  { render :xml => @user.errors, :status => :unprocessable_entity }
      end
    end
  end

  # DELETE /users/1
  # DELETE /users/1.xml
  def destroy
    @user = User.find(params[:id])
    @user.destroy

    respond_to do |format|
      format.html { redirect_to(users_url) }
      format.xml  { head :ok }
    end
  end

  def login
    # If a path to return to was set (e.g. by a link leading to the login page),
    # use it. This means that the user is correctly redirected, like login_required.
    store_location params[:return_to] if params[:return_to]

    CASClient::Frameworks::Rails::Filter.filter(self) unless session[:cas_user]

    if session[:cas_user]
      session[:userid] = session[:cas_user]

      if logged_in?
        redirect_back_or_default(:root)
      else
        login_required
      end
    end
  end

  def logout
    #reset_session
    CASClient::Frameworks::Rails::Filter.logout(self)
  end

	def tickets
		@user = User.find params[:user_id]
		@tickets = @user.tickets
		
		if params[:ticket_list] == "old"
			@tickets.select! { |t| t.status != :reserved }
		elsif params[:ticket_list] == "paid"
			@tickets.select! { |t| t.status == :paid }
		else
			@tickets.select! { |t| t.status == :reserved }
		end
	end

end
