class HomeController < ActionController::API
  def index
    render json: { time: Time.now.utc, rails_env: Rails.env }
  end
end
