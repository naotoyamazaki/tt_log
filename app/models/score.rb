class Score < ApplicationRecord
  belongs_to :match_info
  belongs_to :batting_style
  belongs_to :game
end
