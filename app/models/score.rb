class Score < ApplicationRecord
  belongs_to :match_info
  belongs_to :game, optional: true

  enum batting_style: {
    serve: 0, receive: 1,
    forehand_drive: 2, backhand_drive: 3,
    forehand_push: 4, backhand_push: 5,
    forehand_stop: 6, backhand_stop: 7,
    forehand_flick: 8, backhand_flick: 9,
    chiquita: 10, forehand_block: 11,
    backhand_block: 12, forehand_counter: 13,
    backhand_counter: 14
  }

  validate :score_or_lost_score_must_be_positive_for_serve_and_receive

  private

  def score_or_lost_score_must_be_positive_for_serve_and_receive
    if (serve? || receive?) && score <= 0 && lost_score <= 0
      errors.add(:base, "サーブとレシーブそれぞれの得点数または失点数を1以上にしてください")
    end
  end

  def self.human_enum_name(enum_name, key)
    I18n.t("activerecord.attributes.score.#{enum_name}.#{key}")
  end
  
end
