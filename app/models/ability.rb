class Ability
  include CanCan::Ability
  
  def initialize(user)
    can :read, Card
     
    if user.has_role? "admin"
      can :manage, Card
      can :manage, User
    end
    
    if user.has_role? "card_admin"
      can :manage, Card
    end
    
  end
end
