require 'google_places'
require 'net/http'

class RestaurantsController < ApplicationController

  before_action :set_restaurant, only: [:show, :edit, :update, :destroy]
  before_action :load_restaurants_from_google_api
  before_action :load_existing_restaurants_to_user_distance

  # GET /restaurants
  # GET /restaurants.json
  def index
    @restaurants = Restaurant.all
  end

  # GET /restaurants/1
  # GET /restaurants/1.json
  def show
  end

  # GET /restaurants/new
  def new
    @restaurant = Restaurant.new
  end

  # GET /restaurants/1/edit
  def edit

  end

  # POST /restaurants
  # POST /restaurants.json
  def create(params = {})

    if params.length == 0

      @restaurant = Restaurant.new(restaurant_params)
      respond_to do |format|
        if @restaurant.save
          user_distance_data = calculate_distance_using_google_api({"formatted_address" => current_user.address},{"formatted_address" => @restaurant.address})
          UserDistance.create(user_id: current_user[:id], restaurant_id: @restaurant[:id], distance_from_user: user_distance_data[:distance_from_user], drive_time_for_user: user_distance_data[:drive_time_for_user])

          AttendedRestaurant.create(user_id: current_user[:id], restaurant_id: @restaurant[:id], date_attended: @restaurant.last_attended) unless @restaurant.last_attended.nil?
          UserRating.create(user_id: current_user[:id], restaurant_id: @restaurant[:id], default?: false, rating: @restaurant.rating) unless @restaurant.rating.nil?

          format.html { redirect_to @restaurant, notice: 'Restaurant was successfully created.' }
          format.json { render :show, status: :created, location: @restaurant }
        else
          format.html { render :new }
          format.json { render json: @restaurant.errors, status: :unprocessable_entity }
        end

      end
    else
      #Preloading Database With Data from Google API
      @restaurant = Restaurant.new(name: params[:name], address: params[:address], cost: params[:cost], rating: params[:rating] , cuisine: params[:cuisine], website: params[:website], phone_number: params[:phone_number])
      @restaurant.save

      logger.info "INFO: Logging User Distance to Database... user_id: #{current_user[:id]}, restaurant_id: #{@restaurant[:id]}, distance_from_user: #{params[:distance_from_user]} Meters, drive_time_for_user: #{params[:drive_time_for_user]} Seconds"
      UserDistance.create(user_id: current_user[:id], restaurant_id: @restaurant.id, distance_from_user: params[:distance_from_user], drive_time_for_user: params[:drive_time_for_user])
      UserRating.create(user_id: current_user[:id], restaurant_id: @restaurant.id, default?: true, rating: @restaurant.rating) unless @restaurant.rating.nil?

    end
  end

  # PATCH/PUT /restaurants/1
  # PATCH/PUT /restaurants/1.json
  def update
    respond_to do |format|
      if @restaurant.update(restaurant_params)

        AttendedRestaurant.create(user_id: current_user[:id], restaurant_id: @restaurant.id, date_attended: @restaurant.last_attended) unless @restaurant.last_attended.nil?
        UserRating.create(user_id: current_user[:id], restaurant_id: @restaurant[:id], default?: false, rating: @restaurant.rating) unless @restaurant.rating.nil?

        updated_rating_array = UserRating.where(restaurant_id: @restaurant.id)

        updated_rating_average = (updated_rating_array.map{|x| x.rating.to_f}.reduce(:+)/updated_rating_array.size).round(2) #Average all ratings
        logger.info "INFO: updated_rating_average = #{updated_rating_average}"
        @restaurant.update({rating: updated_rating_average})

        format.html { redirect_to @restaurant, notice: 'Restaurant was successfully updated.' }
        format.json { render :show, status: :ok, location: @restaurant }
      else
        format.html { render :edit }
        format.json { render json: @restaurant.errors, status: :unprocessable_entity }
      end
    end
  end

  # DELETE /restaurants/1
  # DELETE /restaurants/1.json
  def destroy
    @restaurant.destroy
    respond_to do |format|
      format.html { redirect_to restaurants_url, notice: 'Restaurant was successfully destroyed.' }
      format.json { head :no_content }
    end
  end

  def load_restaurants_from_google_api
    logger.info "Querying Google API for Places near #{current_user.address}..."

    #Get Nearby Places
    @places = RestaurantsHelper.query_nearby_places(current_user.address)

    preferred_places = RestaurantsHelper.retry_with_preferred_cuisine(current_user.address, current_user.preferred_cuisine)[:results]
    preferred_places.each {|place| @places << place}

    @places.each do |place|

      creation_params = {
        name: place["name"].capitalize,
        address: place["formatted_address"],
        rating: place["rating"].to_f,
        cuisine: place["types"].first.gsub("_"," ").split()[0].capitalize,
        cost: place["price_level"].nil? ? 3 : place["price_level"].next,
        phone_number: place["formatted_phone_number"].nil? ? "" : place["formatted_phone_number"],
        website: place["website"].nil? ? "" : place["website"],
      }

      if Restaurant.where(name: creation_params[:name]).first.nil? && Restaurant.where(address: creation_params[:address]).first.nil?

        distance = RestaurantsHelper.calculate_distance_using_google_api({"formatted_address" => current_user.address}, place)

        creation_params[:distance_from_user] = distance[:distance_from_user].nil? ? 1000 : distance[:distance_from_user]
        creation_params[:drive_time_for_user] = distance[:drive_time_for_user].nil? ? 600 : distance[:drive_time_for_user]

        create(creation_params)
      end
    end
  end

  private
  # Use callbacks to share common setup or constraints between actions.
  def set_restaurant
    @restaurant = Restaurant.find(params[:id])
  end

  def load_existing_restaurants_to_user_distance  
      Restaurant.all.each do |place|
          creation_params = {
              user_id: current_user.id,
              restaurant_id: place[:id]
            }

        if UserDistance.where("user_id = ? AND  restaurant_id = ?", creation_params[:user_id], creation_params[:restaurant_id]).first.nil?

          logger.info "Calcuating Distance for all restaurants in database for #{current_user.username}..."
          

            distance = RestaurantsHelper.calculate_distance_using_google_api({"formatted_address" => current_user.address}, {"formatted_address" => place.address})

            creation_params[:distance_from_user] = distance[:distance_from_user]
            creation_params[:drive_time_for_user] = distance[:drive_time_for_user]
            
            user_distance = UserDistance.new(creation_params)
            user_distance.save
          end
        end
     end


  # Never trust parameters from the scary internet, only allow the white list through.
  def restaurant_params
    params.require(:restaurant).permit(:id, :name, :address, :cuisine, :cost, :rating, :last_attended, :phone_number, :website)
  end
end
