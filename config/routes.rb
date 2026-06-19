Rails.application.routes.draw do
  get "up" => "rails/health#show", as: :rails_health_check

  root "analyses#new"
  get  "analyses/new", to: "analyses#new", as: :new_analysis
  post "analyses",            to: "analyses#create", as: :analyses
  get  "analyses/:id",        to: "analyses#show",   as: :analysis
  get  "analyses/:id/status", to: "analyses#status", as: :analysis_status

  # JSON API consumed by the browser extension (CORS-enabled, see cors.rb).
  namespace :api do
    namespace :v1 do
      get "analysis", to: "analyses#show"
    end
  end
end
