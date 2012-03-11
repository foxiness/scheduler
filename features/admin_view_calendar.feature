Feature: View Calendar as Nurse

As an admin, 
I want to be able to see the calendar with the nurses' vacation assignments
So that I can monitor the vacation scheduling

Background:

  Given the following dates have been taken:
  | Jane Doe   | 17-Jan-2012 | 24-Jan-2012 |
  | John Doe   | 24-Feb-2012 | 5-Mar-2012  |
  | Jane Doe   | 4-Mar-2012  | 12-Mar-2012 |

  And I am on the Admin Calendar page

Scenario: Viewing calendar
  When I select "January" from "Months"
  Then I should see "Jane Doe"
  When I select "March" from "Months"
  Then I should see "Jane Doe" 
  Then I should see "John Doe"