class Score < ApplicationRecord
  belongs_to :match_info
  belongs_to :game, optional: true

  enum batting_style: { serve: 0, receive: 1}

end
