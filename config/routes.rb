Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "analyses#new"
  get  "analyses/new", to: "analyses#new", as: :new_analysis
  post "analyses",     to: "analyses#create", as: :analyses
  get  "analyses/:id", to: "analyses#show",  as: :analysis
end
