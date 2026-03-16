class Score < ApplicationRecord
  belongs_to :match_info
  belongs_to :game, optional: true

  enum :batting_style, {
    serve: 0, receive: 1,
    fore_drive: 2, back_drive: 3,
    fore_push: 4, back_push: 5,
    fore_stop: 6, back_stop: 7,
    fore_flick: 8, back_flick: 9,
    chiquita: 10, fore_block: 11,
    back_block: 12, fore_counter: 13,
    back_counter: 14
  }

  def self.allowed_batting_styles
    batting_styles.keys - ['receive']
  end

  def self.human_enum_name(enum_name, key)
    I18n.t("activerecord.attributes.score.#{enum_name}.#{key}")
  end
end
