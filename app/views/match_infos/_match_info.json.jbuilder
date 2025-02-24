json.extract! match_info,
              :id, :user_id, :player_id, :opponent_id,
              :match_date, :match_name, :memo,
              :created_at, :updated_at
json.url match_info_url(match_info, format: :json)
