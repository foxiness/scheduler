require 'spec_helper'
require 'date'

describe CalendarController do
  describe 'Nurse owner should be able to' do
    describe 'do CRUD' do
      it 'should create an event' do
        start_at = '13/03/2012'
        end_at = '17/03/2012'
        @nurse.add_event(start_at, end_at)
        @nurse.events.length.should == 1
        event = @nurse.events[0].name
        event.name.should == @nurse.name
        event.start_at.strftime("%d/%m/%y").should == start_at
        event.end_at.strftime("%d/%m/%y").should == end_at
      end
      it 'should delete an event'
      it 'should update an event'
    end
  end
end
