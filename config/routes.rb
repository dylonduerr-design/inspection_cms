Rails.application.routes.draw do
  devise_for :users
  
  # This creates the standard routes AND our new workflow buttons
  resources :reports do
    member do
      post :submit_for_qc
      post :approve
      post :request_revision
      get  :export_word  # <--- Added this line
    end
  end

  resources :bid_items
  resources :phases
  resources :projects
  
  # Set the homepage to the search screen
  root "reports#index"
end