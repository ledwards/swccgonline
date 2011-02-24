Swccgonline::Application.routes.draw do
  devise_for :users
  resources :cards

  get "home/index", :as => :home

  root :to => "home#index"
end
