class CalendarController < ApplicationController
  
  before_filter :authenticate_any!
  before_filter :authenticate_admin!, :only => [:admin_index]
  
  before_filter :check_nurse_id
  before_filter :check_event_id, :only => [:show, :edit, :update, :destroy]
  before_filter :check_current_nurse, :only => ['new', 'show', 'create', 'edit', 'update']

  def index
    setup_index do
      @nurse = Nurse.find_by_id(params[:nurse_id])
      @unit_id = 0
      @cur_nurse = false
      if @nurse
        @unit_id = @unit_nurse_id = @nurse.unit_id
        @shift = @nurse.shift
        @nurse_baton = NurseBaton.find_by_unit_id_and_shift(@unit_nurse_id,@shift)
        if @nurse_baton and current_nurse == @nurse_baton.nurse
          @cur_nurse = true
        elsif admin_signed_in?
          @cur_nurse = true
        end
      else
        flash[:error] = "An error has occurred."
        redirect_to login_path
        return
      end
      
      @shift = @nurse.shift
    end
    @cur_nurse ? @col_names = Event.all_display_columns : @col_names = Event.read_only_display_columns
  end
  
  def admin_index
    setup_index do
      @shifts = Unit.shifts
      @units = Unit.find(:all)
      @shift = @shifts[0]
      @unit_id = 0
      
      if @units.length > 0
        @unit_id = @units[0].id
      end
      
      if params[:shift]
        if Unit.is_valid_shift(params[:shift])
          session[:shift] = params[:shift]
        else
          flash[:error] = "Received an invalid shift: #{params[:shift]}"
          redirect_to admin_calendar_path
          return
        end
      end
      
      if params[:unit_id]
        if Unit.is_valid_unit_id(params[:unit_id])
          session[:unit_id] = params[:unit_id]
        else
          flash[:error] = "Received an invalid unit_id: #{params[:unit_id]}"
          redirect_to admin_calendar_path
          return
        end
      end
      
      if session[:shift] and session[:unit_id]
        @unit_id = session[:unit_id]
        @shift = session[:shift]
      end
    end
  end
  
  def show
    @event = Event.find_by_id(params[:id])
    if not @event
      flash[:error] = "The vacation you were looking for could not be found."
      redirect_to login_path
      return
    end
  end
  
  def new
    @nurse_id = params[:nurse_id]
  end
  
  def create
    nurse = Nurse.find_by_id(params[:nurse_id])
    if not nurse
      flash[:error] = "The nurse to create this vacation for could not be found."
      redirect_to login_path
      return
    end
    
    begin
      start_date = Date.strptime params[:event][:start_at], '%m/%d/%Y'
      end_at = Date.strptime params[:event][:end_at], '%m/%d/%Y'
    rescue
      flash[:error] = "You entered an date that was not properly formatted."
      redirect_to login_path
      return
    end
    
    event = Event.new(:start_at => start_date, :end_at => end_at, :pto => params[:event][:pto])
    event.all_day = 1
    event.name = nurse.name
    event.nurse_id = nurse.id
    
    if not event.save(:validate => (not admin_signed_in?))
      flash[:error] = "The vacation to schedule was not valid: #{event.errors.full_messages.join(' ')}"
    else
      flash[:notice] = 'You successfully scheduled a vacation segment'
    end
    redirect_to nurse_calendar_index_path(:month => event.start_at.month, :year => event.start_at.year)
  end
  
  def edit
    @nurse = Nurse.find_by_id(params[:nurse_id])
    @cur_nurse = false
    if current_nurse == @nurse
      @cur_nurse = true
    elsif admin_signed_in?
      @cur_nurse = true
    end

    @event = Event.find_by_id(params[:id])
    if not @event
      flash[:error] = "The vacation you are trying to edit could not be found."
      redirect_to login_path
      return
    end
    
    @nurse_id = @nurse.id
    @id = params[:id]
  end
  
  def update
    @event = Event.find_by_id(params[:id])
    if not @event
      flash[:error] = "The vacation you are trying to update could not be found."
      redirect_to login_path
      return
    end
    
    begin
      @event.start_at = Date.strptime params[:event][:start_at], '%m/%d/%Y'
      @event.end_at = Date.strptime params[:event][:end_at], '%m/%d/%Y'
    rescue
      flash[:error] = "You entered an date that was not properly formatted."
      redirect_to login_path
      return
    end
    
    @event.all_day = 1
    @event.pto = params[:event][:pto]

    if not @event.save(:validate => (not admin_signed_in?))
      flash[:error] = "The update failed for the following reasons: #{@event.errors.full_messages.join(' ')}"
      redirect_to nurse_calendar_index_path(:month => @event.start_at.month, :year => @event.start_at.year)
    else
      flash[:error] = 'You successfully updated a vacation segment'
      redirect_to nurse_calendar_index_path(:month => @event.start_at.month, :year => @event.start_at.year)
    end
  end
  
  def destroy
    @event = Event.find_by_id(params[:id])
    if not @event
      flash[:error] = "The vacation you are trying to delete could not be found."
      redirect_to login_path
      return
    end
    
    r_month = @event.start_at.month
    r_year = @event.start_at.year
    if not @event.destroy
      flash[:error] = "The vacation could not be deleted."
      redirect_to nurse_calendar_index_path(:month => r_month, :year => r_year)
    else
      flash[:notice] = "That vacation segment has been deleted."
      redirect_to nurse_calendar_index_path(:month => r_month, :year => r_year)
    end
  end

  def admin_print
    if not session[:unit_id]
      redirect_to admin_calendar_path
      flash[:error] = "Please select a unit and filter calendars."
      return
    end
    if not session[:shift]
      redirect_to admin_calendar_path
      flash[:error] = "Please select a shift and filter calendars."
      return
    end

    @unit_id = session[:unit_id]
    @shift = session[:shift]
    @year_month = Array.new
    m = 3 #vacation scheduling starts in March
    year = CurrentYear.first.year
    12.times do
      @year_month << [year + m.div(13), m%13 + m.div(13)]
      m += 1
    end
    @strips = Array.new
    @year_month.each do |ym|
      cmonth = Date.civil(ym[0], ym[1])
      @strips << Event.event_strips_for_month(cmonth, 
                                              :include => :nurse, 
                                              :conditions => {"nurses.unit_id" => @unit_id, "nurses.shift" => @shift}
                                              )
    end
  end

  def print
    @nurse = Nurse.find_by_id(params[:nurse_id])
    @unit_id = @nurse.unit_id 
    @shift = @nurse.shift

    @year_month = Array.new
    @nurse.events.each do |e|
      edate = e.start_at.to_date
      date_arr = [edate.year, edate.month]
      if not @year_month.include?(date_arr)
        @year_month << date_arr
      end

      edate = e.end_at.to_date
      date_arr = [edate.year, edate.month]
      if not @year_month.include?(date_arr)
        @year_month << date_arr
      end
    end
    
    @strips = Array.new
    @year_month.each do |ym|
      cmonth = Date.civil(ym[0], ym[1])
      @strips << Event.event_strips_for_month(cmonth, 
                                              :include => :nurse, 
                                              :conditions => {"nurses.unit_id" => @unit_id, "nurses.shift" => @shift, "nurses.id" => @nurse.id}
                                              )
    end
  end

  def finalize_schedule
    nurse = Nurse.find_by_id(params[:nurse_id])
    shift = nurse.shift
    unit = nurse.unit
    nurse_baton = NurseBaton.find_by_unit_id_and_shift(unit.id,shift)
    if nurse_baton
      cur_nurse = Nurse.find_by_id(nurse_baton.nurse)
      ranked_nurses = Nurse.where(:unit_id => unit.id, :shift => shift).rank('nurse_order')
      next_nurse = ranked_nurses[ranked_nurses.index(nurse) + 1]
      nurse_baton.nurse = next_nurse
      if nurse_baton.save
        # check to make sure that there is a new next nurse
        if next_nurse and next_nurse.position > cur_nurse.position
          Notifier.notify_nurse(next_nurse).deliver
        else
          unit.admins.each do |admin|
            Notifier.notify_completion(admin,unit.name,shift).deliver
          end
          nurse_baton.destroy
        end
        unit.admins.each do |admin|
          Notifier.notify_admin(admin, cur_nurse).deliver
        end
        flash[:notice] = "Your schedule has been finalized and you can no longer update your vacations for this year."
      else
        flash[:error] = "Unsuccessful finalization."
      end
    else
      flash[:notice] = "The scheduling process has not yet begun."
    end
    redirect_to nurse_calendar_index_path
  end

  private

  def setup_index
    year = nil
    if CurrentYear.first
      year = CurrentYear.first.year
    end
    @month = (params[:month] || 3).to_i
    @year = (params[:year] || year || (Time.zone || Time).now.year).to_i
    
    if @month == 0 or @year == 0
      flash[:error] = "An error has occurred."
      redirect_to login_path
      return
    end

    @shown_month = Date.civil(@year, @month)

    yield

    if Unit.is_valid_shift(@shift) and Unit.is_valid_unit_id(@unit_id)
      @event_strips = Event.event_strips_for_month(@shown_month, 
                                                    :include => :nurse, 
                                                    :conditions => {"nurses.unit_id" => @unit_id, "nurses.shift" => @shift}
                                                    )
    else
      flash[:error] = "An error has happened. It's all your fault."
      redirect_to login_path
      return
    end
  end

  def check_nurse_id
    return if admin_signed_in?
    permission_denied if current_nurse != Nurse.find(params[:nurse_id])
  end

  def check_event_id
    return if admin_signed_in?
    permission_denied if current_nurse != Event.find(params[:id]).nurse
  end

  def check_current_nurse
    return if admin_signed_in?
    nurse = Nurse.find_by_id(params[:nurse_id])
    baton = NurseBaton.find_by_unit_id_and_shift(nurse.unit_id,nurse.shift)
    permission_denied if !baton or current_nurse != baton.nurse
  end


end
