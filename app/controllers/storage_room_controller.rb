class StorageRoomController < ApplicationController
  skip_before_filter :verify_authenticity_token
  before_filter :require_http_basic
  
  def article
    # Create a WebhookCall Object from the parsed response
    @webhook_call = StorageRoom::WebhookCall.new_from_response_data(params[:webhook_call])
    
    # The Entry which was created/updated/deleted on the server
    @article = @webhook_call.entry
    
    # The type of event (create/update/delete)
    @event_type = @webhook_call[:@event]
    
    # Log that we received a Webhook Call
    logger.info "== Received new Webhook Call from StorageRoom (Article - #{@event_type}) =="
    logger.info "  Article: #{@article.inspect}"
    
    # Do something in response to the Webhook Call (e.g. save some information to a local database, update the Entry on StorageRoom)
    if @event_type == 'create' || @event_type == 'update'
      @article.skip_webhooks = true # otherwise we create an infinite webhook loop
      @article.text += "- UPDATED BY WEBHOOK - #{Time.now}"
      @article.save
    end
    
    # Let StorageRoom know that the call succeeded with a HTTP 200 status code
    # If you don't return a 200/201 status code StorageRoom will try to post
    # to your service again after some time.
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
end
