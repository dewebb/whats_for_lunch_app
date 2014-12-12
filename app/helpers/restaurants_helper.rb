require 'logger'

module RestaurantsHelper

	def self.calculate_distance_using_google_api(origin_address_gps, destination_address_gps)
       Rails.logger.info "Using Google Maps API to Calculate Distance between #{origin_address_gps["formatted_address"]} and #{destination_address_gps["formatted_address"]}"
       uri = URI('https://maps.googleapis.com/maps/api/distancematrix/json')

       params = { 
            origins: "#{origin_address_gps["formatted_address"]}",
            destinations: "#{destination_address_gps["formatted_address"]}",  
            key: "AIzaSyDNMJwNQiqU1-0KHZXz6omHpzCaqY5gKCs",
            mode: "driving"
          }

          uri.query = URI.encode_www_form(params)

         res = Net::HTTP.get_response(uri)
         Rails.logger.info "Response from Google Maps API: #{res.body}"

         distance_from = JSON.parse(res.body)["rows"].first.nil? ? "1000" : JSON.parse(res.body)["rows"].first["elements"].first["distance"]["value"]
         drive_time = JSON.parse(res.body)["rows"].first.nil? ? "1000" : JSON.parse(res.body)["rows"].first["elements"].first["duration"]["value"]

         @distance_result = {
          distance_from_user: distance_from,
          drive_time_for_user: drive_time
        }
         Rails.logger.info "Distance Result: #{@distance_result} Meters | Seconds"
         @distance_result
       end

      def self.query_nearby_places
        uri = URI('https://maps.googleapis.com/maps/api/place/textsearch/json')
          params = { 
              key: ["AIzaSyA0zgbkEn__stJJwtR7f9JDxCYrQZC__QY","AIzaSyAw-ItKGrTc6KTfnXwNa2s9KixqrKHVl1c"].sample, 
              query: "Places near #{current_user.address}",
              types: "restaurant|food",
              radius: 16093 #10 mile radius
            }
          uri.query = URI.encode_www_form(params)

          res = Net::HTTP.get_response(uri)
          logger.info "Response from Querying Places: #{res.body}"

          JSON.parse(res.body)["results"]
        end
end
