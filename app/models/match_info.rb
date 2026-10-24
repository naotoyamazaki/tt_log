class MatchInfo < ApplicationRecord
  belongs_to :user
  belongs_to :player, class_name: "Player", inverse_of: :match_infos_as_player
  belongs_to :opponent, class_name: "Player", inverse_of: :match_infos_as_opponent
  has_many :scores, dependent: :destroy
  accepts_nested_attributes_for :scores, update_only: true
  has_many :games, dependent: :destroy
  has_many :rallies, dependent: :destroy
  has_many :serve_receive_patterns, dependent: :destroy
  accepts_nested_attributes_for :games
  attr_accessor :player_name, :opponent_name

  enum :analysis_type, { technique: 0, serve_receive: 1 }
  enum :opponent_handedness, { right: 0, left: 1 }, prefix: :opponent_handedness
  enum :opponent_racket, { shakehand: 0, penholder: 1 }, prefix: :opponent_racket
  enum :opponent_rubber_forehand, { backside: 0, pips_out: 1, pips_long: 2, anti: 3 }, prefix: :opponent_rubber_forehand
  enum :opponent_rubber_backhand, { backside: 0, pips_out: 1, pips_long: 2, anti: 3, none: 4 },
       prefix: :opponent_rubber_backhand
  enum :opponent_playstyle, { front_drive: 0, mid_drive: 1, front_hit: 2, blocker: 3, cutman: 4, other: 5 },
       prefix: :opponent_playstyle

  scope :completed, -> { where(draft: false) }

  validates :match_date, presence: true
  validates :match_name, presence: true
  validates :memo, length: { maximum: 500, message: I18n.t('errors.messages.memo_too_long') }, allow_blank: true
  validate :validate_player_and_opponent_names

  def validate_player_and_opponent_names
    errors.add(:player_name, I18n.t('errors.messages.blank')) if player_name.blank?

    errors.add(:opponent_name, I18n.t('errors.messages.blank')) if opponent_name.blank?
  end

  def self.ransackable_attributes(_auth_object = nil)
    ["match_name", "player_id", "opponent_id"]
  end

  def self.ransackable_associations(_auth_object = nil)
    ["player"]
  end

  def self.ransackable_scopes(_auth_object = nil)
    [:opponent_player_name_cont]
  end

  def self.human_enum_name(enum_name, key)
    I18n.t("activerecord.attributes.match_info.#{enum_name}.#{key}")
  end

  def self.opponent_player_name_cont(query)
    joins(:opponent).where("players.player_name LIKE ?", "%#{query}%")
  end

  def batting_score_data
    prepare_batting_score_data(scores.where.not(batting_style: :receive))
  end

  def game_count_score
    return nil if games.none?

    player_wins = games.count { |g| g.player_score > g.opponent_score }
    opponent_wins = games.count { |g| g.player_score < g.opponent_score }
    "#{player_wins}-#{opponent_wins}"
  end

  def result
    return nil if games.none?

    player_wins = games.count { |g| g.player_score > g.opponent_score }
    opponent_wins = games.count { |g| g.player_score < g.opponent_score }
    return nil if player_wins == opponent_wins

    player_wins > opponent_wins ? :win : :lose
  end

  def game_by_game_score_data
    return [] if games.none?

    games.order(:game_number).map do |game|
      game_scores = game.scores.where.not(batting_style: :receive)
      techniques = prepare_batting_score_data(game_scores)
      {
        game_number: game.game_number,
        score: "#{game.player_score}-#{game.opponent_score}",
        result: game.player_score > game.opponent_score ? "勝ち" : "負け",
        techniques: techniques
      }
    end
  end

  def update_advice(advice)
    self.advice = advice
    save!(validate: false)
  rescue StandardError => e
    Rails.logger.error("Failed to update advice: #{e.message}")
  end

  private

  def prepare_batting_score_data(score_records)
    grouped_data = group_scores_by_technique(score_records)

    grouped_data.map do |technique, result|
      "#{technique}：得点 #{result[:score]} 失点 #{result[:lost_score]}"
    end
  end

  def group_scores_by_technique(score_records)
    data = {}

    score_records.each do |score|
      name = translated_batting_style_name(score.batting_style)

      data[name] ||= { score: 0, lost_score: 0 }
      data[name][:score] += score.score
      data[name][:lost_score] += score.lost_score
    end

    data
  end

  def translated_batting_style_name(style)
    case style
    when "fore_push" then "フォアツッツキ"
    when "back_push" then "バックツッツキ"
    else
      Score.human_enum_name(:batting_style, style)
    end
  end
end
