class Score < ApplicationRecord
  belongs_to :match_info
  belongs_to :game, optional: true

  enum batting_style: { serve: 0, receive: 1}

  validate :score_or_lost_score_must_be_positive_for_serve_and_receive

  private

  def score_or_lost_score_must_be_positive_for_serve_and_receive
    if (serve? || receive?) && score <= 0 && lost_score <= 0
      errors.add(:base, "サーブとレシーブそれぞれの得点数または失点数を1以上にしてください")
    end
  end
end
