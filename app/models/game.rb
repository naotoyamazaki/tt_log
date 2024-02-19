class Game < ApplicationRecord
  has_many :scores
  belongs_to :match_info
end
