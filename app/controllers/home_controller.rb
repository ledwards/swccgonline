class HomeController < ApplicationController
  before_filter :authenticate_user!
  
  def index
    @cards = Card.search(params[:search]).expansion(params[:expansion]).side(params[:side]).paginate(:per_page => 20, :page => params[:page])
    @cards.first.try(:id) #this is here because of a very strange bug where the first element of @cards doesn't return its id the first time it's called
  end
end
