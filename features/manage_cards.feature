Feature: Admin manages cards

  As an admin user
  I want to create and edit cards
  So that the list of cards will always be up to date
  
  Scenario: admin creates new cards
    Given a logged in admin
    And a card type named "Interrupt"
    And an expansion named "Death Star III"
    And I go to the new card page
    And I fill in "Title" with "Huge Explosion"
    And I select "Interrupt" from "Card type"
    And I select "Death Star III" from "Expansion"
    And I press "Create"
    Then I should see "Card was successfully created."
  
  Scenario: admin edits cards
    Given a logged in admin
    And a card with title "Huge Explosion"
    When I edit the card with title "Huge Explosion"
    And I fill in "Title" with "It's ok, I'm an admin"
    And I press "Save"
    Then I should see "It's ok, I'm an admin"
    
  Scenario: user fails to edits cards
    Given a logged in user
    And a card with title "Huge Explosion"
    And I edit the card with title "Huge Explosion"
    Then I should see "not authorized"
