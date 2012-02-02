class ApplicationController < ActionController::Base
  protect_from_forgery
  
  before_filter :clear_storage_room_identity_map
  
  # StorageRoom caches Entries by their URL so they are not loaded more than once
  # This cache should be expired for each new request coming in.
  def clear_storage_room_identity_map
    StorageRoom::IdentityMap.clear
  end
end
