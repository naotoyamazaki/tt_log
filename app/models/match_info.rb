class MatchInfo < ApplicationRecord
  belongs_to :user
  belongs_to :player, class_name: "Player", inverse_of: :match_infos_as_player
  belongs_to :opponent, class_name: "Player", inverse_of: :match_infos_as_opponent
  has_many :scores, dependent: :destroy
  accepts_nested_attributes_for :scores, update_only: true
  has_many :games, dependent: :destroy
  attr_accessor :player_name, :opponent_name
  attr_accessor :post_to_x

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

  def self.opponent_player_name_cont(query)
    joins(:opponent).where("players.player_name LIKE ?", "%#{query}%")
  end

  def batting_score_data
    prepare_batting_score_data(scores.where.not(batting_style: %w[serve receive]))
  end

  def update_advice(advice)
    update(advice: advice)
  rescue StandardError => e
    Rails.logger.error("Failed to update advice: #{e.record.errors.full_messages.join(', ')}")
  end
end
