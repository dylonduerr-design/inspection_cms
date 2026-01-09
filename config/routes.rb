# config/routes.rb
Rails.application.routes.draw do
  devise_for :users
  
  resources :reports do
    # --- MOVED HERE ---
    # This creates the URL: /reports/:report_id/checklist_entries
    resources :checklist_entries, only: [:create, :update] 
    # ------------------

    member do
      post :submit_for_qc
      post :approve
      post :request_revision
      get  :export_word  
    end
  end

  resources :bid_items
  resources :phases
  resources :projects
  
  # (Removed the old standalone checklist_entries line from down here)
  
  root "reports#index"
end