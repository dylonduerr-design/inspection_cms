# config/routes.rb
Rails.application.routes.draw do
  devise_for :users
  
  resources :reports do
    resources :checklist_entries, only: [:create, :update] 
    member do
      post :submit_for_qc
      post :approve
      post :request_revision
      get  :export_word  
    end
  end

  # --- MAESTRO CHANGE: Nest Bid Items under Projects ---
  resources :projects do
    resources :bid_items # URL: /projects/1/bid_items/new
    resources :approved_equipments, only: [:create, :destroy]
  end
  
  resources :phases
  
 

  root "reports#index"
end