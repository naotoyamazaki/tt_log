class Game < ApplicationRecord
  has_many :scores, dependent: :destroy
  belongs_to :match_info
end
