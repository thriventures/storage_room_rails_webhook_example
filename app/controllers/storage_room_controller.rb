class StorageRoomController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :require_http_basic
  before_filter :get_collections
  before_filter :parse_webhook_call
  
  # This should be configured as the receiver of Webhooks on the "Shops" Collection on StorageRoom.
  # When a Shop is updated it will update the Locations of all Products that belong to the Shop.
  # If updating the Location of Products is the only job the Webhook should do then only the "On Update" option of the Webhook should be set to yes.
  def shops    
    # Set the shop variable to the entry that was updated
    @shop = @webhook_call.entry
      
    # Only update the Locations of the shop's products when the shop has been updated
    # On create: When the shop has just been created then there are no products, so no update necessary
    # On delete: The shop doesn't get changed on a delete request. Optionally add code to remove all products of a shop
    if @webhook_call[:@event] == 'update'
      logger.info "== A shop (#{@shop[:@url]}) has been updated on StorageRoom =="
      
      # Search for all products that belong to the shop and iterate over them, even if they span multiple pages
      Product.search(:'shop.url' => @shop[:@url]).each_page_each_resource do |product|
        # Only update the products when the location is actually different, this saves unnecessary API requests.
        if product.location != @shop.location
          logger.info "   Updating (#{product[:@url]}) to the new Location =="
        
          # Update the location of the product and save it
          product.location = @shop.location
          product.skip_webhooks = true # this must be set to avoid an infinite loop of webhooks
          product.save
        end
      end
    end
    
    # Return an empty ok response so that StorageRoom knows everything went alright
    render :nothing => true, :status => :ok
  end
  
  
  # Set the location of a product to the location of the associated store.
  def products
    @product = @webhook_call.entry
    
    if @webhook_call[:@event] == 'create' || @webhook_call[:@event] == 'update'
      logger.info "== A product (#{@product[:@url]}) has been created/updated on StorageRoom =="
      
      if @product.shop && @product.shop.location != @product.location
        @product.location = @product.shop.location
        
        @product.skip_webhooks = true # this must be set to avoid an infinite loop of webhooks
        @product.save        
      end
    end
    
    # Return an empty ok response so that StorageRoom knows everything went alright
    render :nothing => true, :status => :ok
  end
  
  private
    # Secure this endpoint with a secret username/password so that only the StorageRoom server can POST to it.
    # Enter this username/password in the Webhook Definition in the StorageRoom web interface.
    def require_http_basic
      authenticate_or_request_with_http_basic("StorageRoom") do |username, password|
        username == 'storage_room' && password = 'secret'
      end
    end
    
    def get_collections
      # Load both Collections from StorageRoom to automatically configure the Entry Classes
      @shop_collection    = StorageRoom::Collection.find('4f327afb421aa9867c000042')
      @product_collection = StorageRoom::Collection.find('4f327ab5421aa9867c000028')
    end
    
    def parse_webhook_call
      # Parse the passed WebhookCall of the request body
      @webhook_call = StorageRoom::WebhookCall.new_from_response_data(params[:webhook_call])
    end
end
